const fs = require('fs');

const sql = `
-- =========================================================================================
-- MIGRATION: PLAN_05_ENHANCEMENT_SYSTEM
-- =========================================================================================

-- 1. Create Enhancement History Table
CREATE TABLE IF NOT EXISTS public.enhancement_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL REFERENCES public.items(id),
  item_row_id UUID NOT NULL,
  
  previous_level INTEGER NOT NULL,
  attempted_level INTEGER NOT NULL,
  new_level INTEGER NOT NULL,
  
  rune_used TEXT DEFAULT 'none',
  scroll_used TEXT NOT NULL,
  gold_spent INTEGER NOT NULL,
  
  success BOOLEAN NOT NULL,
  destroyed BOOLEAN DEFAULT false,
  success_rate_at_attempt NUMERIC NOT NULL,
  
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_enhancement_history_player ON public.enhancement_history(player_id);

ALTER TABLE public.enhancement_history ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own enhancement history' AND tablename = 'enhancement_history') THEN
    CREATE POLICY "Users can view their own enhancement history" ON public.enhancement_history FOR SELECT USING (auth.uid() = player_id);
  END IF;
END $$;

-- 2. Insert Rune Crafting Recipes into public.craft_recipes
INSERT INTO public.craft_recipes (id, item_id, recipe_type, facility_type, materials, gold_cost, duration_minutes, required_facility_level, required_player_level, success_rate)
VALUES
  (gen_random_uuid(), 'rune_basic', 'materials', 'zaman_kuyusu', '{"lapis_runicus": 5, "aqua_sacra": 2}', 50000, 3, 1, 10, 1.0),
  (gen_random_uuid(), 'rune_advanced', 'materials', 'zaman_kuyusu', '{"crystallum_magicum": 3, "crystallum_manae": 3}', 200000, 10, 3, 20, 1.0),
  (gen_random_uuid(), 'rune_superior', 'materials', 'zaman_kuyusu', '{"fragmentum_energiae": 3, "aqua_purificata": 2, "essentia_tenebrarum": 1}', 500000, 30, 5, 30, 1.0),
  (gen_random_uuid(), 'rune_legendary', 'materials', 'zaman_kuyusu', '{"nucleus_runicus": 3, "lacrimae_angelorum": 2, "cor_umbrae": 1}', 1500000, 120, 7, 50, 1.0),
  (gen_random_uuid(), 'rune_protection', 'materials', 'zaman_kuyusu', '{"cor_arcanum": 5, "fons_vitae": 3, "nucleus_abyssi": 2, "essentia_chronos": 1}', 2500000, 360, 9, 60, 1.0),
  (gen_random_uuid(), 'rune_blessed', 'materials', 'zaman_kuyusu', '{"fons_vitae": 3, "aqua_aeterna": 3, "essentia_runica": 2, "infinitas_temporis": 1}', 5000000, 720, 10, 70, 1.0)
ON CONFLICT DO NOTHING;

-- 3. The enhance_item RPC
CREATE OR REPLACE FUNCTION public.enhance_item(
  p_player_id UUID,
  p_row_id UUID,
  p_rune_type TEXT DEFAULT 'none'
) RETURNS JSONB AS $$
DECLARE
  v_item RECORD;
  v_player RECORD;
  v_rarity_mult NUMERIC;
  v_base_cost INTEGER;
  v_gold_cost INTEGER;
  v_success_rate NUMERIC;
  v_destroy_rate NUMERIC;
  v_success BOOLEAN;
  v_destroyed BOOLEAN := false;
  v_new_level INTEGER;
  v_scroll_id TEXT;
  v_has_scroll BOOLEAN;
  v_has_rune BOOLEAN;
BEGIN
  -- Get item with catalog data
  SELECT inv.*, items.rarity, items.can_enhance
  INTO v_item
  FROM public.inventory inv
  JOIN public.items ON items.id = inv.item_id
  WHERE inv.row_id = p_row_id AND inv.user_id = p_player_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'item_not_found');
  END IF;
  
  IF NOT v_item.can_enhance THEN
    RETURN jsonb_build_object('error', 'cannot_enhance');
  END IF;
  
  IF v_item.enhancement_level >= 10 THEN
    RETURN jsonb_build_object('error', 'max_level');
  END IF;
  
  -- Get player
  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  
  -- Calculate costs
  v_rarity_mult := CASE v_item.rarity
    WHEN 'common' THEN 1.0
    WHEN 'uncommon' THEN 1.5
    WHEN 'rare' THEN 2.5
    WHEN 'epic' THEN 4.0
    WHEN 'legendary' THEN 7.0
    WHEN 'mythic' THEN 12.0
    ELSE 1.0
  END;
  
  -- Gold check
  v_base_cost := (ARRAY[100000,200000,300000,500000,1500000,3500000,7500000,15000000,50000000,200000000,1000000000])[v_item.enhancement_level + 1];
  v_gold_cost := floor(v_base_cost * v_rarity_mult);
  
  IF v_player.gold < v_gold_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_gold');
  END IF;
  
  -- Scroll check
  v_scroll_id := CASE 
    WHEN v_item.rarity IN ('common', 'uncommon') THEN 'scroll_upgrade_low'
    WHEN v_item.rarity IN ('rare', 'epic') THEN 'scroll_upgrade_middle'
    ELSE 'scroll_upgrade_high'
  END;
  
  SELECT EXISTS(
    SELECT 1 FROM public.inventory 
    WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity > 0
  ) INTO v_has_scroll;
  
  IF NOT v_has_scroll THEN
    RETURN jsonb_build_object('error', 'no_scroll');
  END IF;

  -- Rune check (if a rune is provided, ensure player has it in inventory)
  IF p_rune_type != 'none' THEN
    SELECT EXISTS(
      SELECT 1 FROM public.inventory 
      WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity > 0
    ) INTO v_has_rune;
    
    IF NOT v_has_rune THEN
      RETURN jsonb_build_object('error', 'no_rune');
    END IF;
  END IF;
  
  -- Calculate rates
  v_success_rate := (ARRAY[1.0,1.0,1.0,1.0,0.7,0.6,0.5,0.35,0.2,0.1,0.03])[v_item.enhancement_level + 1];
  v_destroy_rate := (ARRAY[0,0,0,0,0,0,1.0,1.0,1.0,1.0,1.0])[v_item.enhancement_level + 1];
  
  -- Apply rune bonuses
  IF p_rune_type = 'basic' THEN v_success_rate := v_success_rate + 0.05;
  ELSIF p_rune_type = 'advanced' THEN v_success_rate := v_success_rate + 0.10;
  ELSIF p_rune_type = 'superior' THEN v_success_rate := v_success_rate + 0.15; v_destroy_rate := v_destroy_rate * 0.5;
  ELSIF p_rune_type = 'legendary' THEN v_success_rate := v_success_rate + 0.25; v_destroy_rate := v_destroy_rate * 0.25;
  ELSIF p_rune_type = 'protection' THEN v_destroy_rate := 0;
  ELSIF p_rune_type = 'blessed' THEN v_success_rate := v_success_rate + 0.20; v_destroy_rate := v_destroy_rate * 0.5;
  END IF;
  
  v_success_rate := LEAST(1.0, v_success_rate);
  v_destroy_rate := GREATEST(0, v_destroy_rate);
  
  -- Roll
  v_success := random() <= v_success_rate;
  v_new_level := v_item.enhancement_level;
  
  IF v_success THEN
    v_new_level := v_item.enhancement_level + 1;
  ELSE
    IF v_item.enhancement_level >= 6 AND p_rune_type != 'protection' AND p_rune_type != 'blessed' THEN
      IF random() <= v_destroy_rate THEN
        v_destroyed := true;
      END IF;
    ELSIF p_rune_type = 'blessed' THEN
      v_new_level := v_item.enhancement_level; -- Aynı kalır
    ELSE
      v_new_level := GREATEST(0, v_item.enhancement_level - 1);
    END IF;
  END IF;
  
  -- Consume gold + scroll + rune
  UPDATE public.users SET gold = gold - v_gold_cost WHERE auth_id = p_player_id;
  
  -- Decrease scroll quantity (delete if 0 handled by other mechanisms, or we can explicitly delete)
  UPDATE public.inventory SET quantity = quantity - 1 WHERE user_id = p_player_id AND item_id = v_scroll_id;
  DELETE FROM public.inventory WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity <= 0;

  IF p_rune_type != 'none' THEN
    UPDATE public.inventory SET quantity = quantity - 1 WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type;
    DELETE FROM public.inventory WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity <= 0;
  END IF;
  
  -- Apply result
  IF v_destroyed THEN
    DELETE FROM public.inventory WHERE row_id = p_row_id;
  ELSE
    UPDATE public.inventory SET enhancement_level = v_new_level WHERE row_id = p_row_id;
  END IF;
  
  -- Log history
  INSERT INTO public.enhancement_history (
    player_id, item_id, item_row_id, previous_level, attempted_level, new_level,
    rune_used, scroll_used, gold_spent, success, destroyed, success_rate_at_attempt
  ) VALUES (
    p_player_id, v_item.item_id, p_row_id, v_item.enhancement_level, v_item.enhancement_level + 1, v_new_level,
    p_rune_type, v_scroll_id, v_gold_cost, v_success, v_destroyed, v_success_rate
  );
  
  RETURN jsonb_build_object(
    'success', v_success,
    'destroyed', v_destroyed,
    'new_level', v_new_level,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.enhance_item(UUID, UUID, TEXT) TO authenticated;
`;

fs.writeFileSync('supabase/migrations/20260307_040000_plan_05_enhancement_system.sql', sql, 'utf8');
console.log('Phase 5 Migration generated.');
