
-- =========================================================================================
-- MIGRATION: PLAN_05_ENHANCEMENT_SYSTEM
-- =========================================================================================

-- 0. Extend crafting_recipes with additional columns for enhancement recipes if needed
ALTER TABLE public.crafting_recipes
ADD COLUMN IF NOT EXISTS item_id TEXT,
ADD COLUMN IF NOT EXISTS recipe_type TEXT,
ADD COLUMN IF NOT EXISTS facility_type TEXT,
ADD COLUMN IF NOT EXISTS materials JSONB,
ADD COLUMN IF NOT EXISTS gold_cost BIGINT DEFAULT 0,
ADD COLUMN IF NOT EXISTS duration_minutes INT;

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

-- 2. Ensure rune items exist in public.items
INSERT INTO public.items (
  id, name, type, description, rarity,
  base_price, vendor_sell_price, is_tradeable, is_stackable, max_stack, can_enhance
) VALUES
  ('rune_basic', 'Temel Rune', 'RUNE', 'Geliştirme başarı şansını artırır.', 'common', 1000, 500, true, true, 50, false),
  ('rune_advanced', 'İleri Rune', 'RUNE', 'Güçlü geliştirme yardımcısı.', 'uncommon', 5000, 2500, true, true, 50, false),
  ('rune_superior', 'Üstün Rune', 'RUNE', 'Yüksek başarı oranı ve yok olma azaltması.', 'rare', 20000, 10000, true, true, 50, false),
  ('rune_legendary', 'Efsanevi Rune', 'RUNE', 'İstisna başarı ve hasar azaltma.', 'legendary', 100000, 50000, true, true, 50, false),
  ('rune_protection', 'Koruma Runesi', 'RUNE', 'Başarısızlıkta yok olma riski olmaz.', 'epic', 50000, 25000, true, true, 50, false),
  ('rune_blessed', 'Kutsanmış Rune', 'RUNE', 'Başarısızlıkta seviye değişmez.', 'epic', 50000, 25000, true, true, 50, false)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  type = EXCLUDED.type,
  description = EXCLUDED.description,
  rarity = EXCLUDED.rarity,
  base_price = EXCLUDED.base_price;

-- 3. Insert Rune Crafting Recipes into public.crafting_recipes
-- Note: crafting_recipes schema uses output_item_id, ingredients, production_time_seconds, etc.
INSERT INTO public.crafting_recipes (
  id, output_item_id, required_level, production_time_seconds, 
  success_rate, xp_reward, ingredients, 
  item_id, recipe_type, facility_type, materials, gold_cost, duration_minutes
)
VALUES
  (gen_random_uuid(), 'rune_basic', 10, 180, 1.0, 50, '{"lapis_runicus": 5, "aqua_sacra": 2}', 'rune_basic', 'materials', 'zaman_kuyusu', '{"lapis_runicus": 5, "aqua_sacra": 2}', 50000, 3),
  (gen_random_uuid(), 'rune_advanced', 20, 600, 1.0, 100, '{"crystallum_magicum": 3, "crystallum_manae": 3}', 'rune_advanced', 'materials', 'zaman_kuyusu', '{"crystallum_magicum": 3, "crystallum_manae": 3}', 200000, 10),
  (gen_random_uuid(), 'rune_superior', 30, 1800, 1.0, 150, '{"fragmentum_energiae": 3, "aqua_purificata": 2, "essentia_tenebrarum": 1}', 'rune_superior', 'materials', 'zaman_kuyusu', '{"fragmentum_energiae": 3, "aqua_purificata": 2, "essentia_tenebrarum": 1}', 500000, 30),
  (gen_random_uuid(), 'rune_legendary', 50, 7200, 1.0, 200, '{"nucleus_runicus": 3, "lacrimae_angelorum": 2, "cor_umbrae": 1}', 'rune_legendary', 'materials', 'zaman_kuyusu', '{"nucleus_runicus": 3, "lacrimae_angelorum": 2, "cor_umbrae": 1}', 1500000, 120),
  (gen_random_uuid(), 'rune_protection', 60, 21600, 1.0, 250, '{"cor_arcanum": 5, "fons_vitae": 3, "nucleus_abyssi": 2, "essentia_chronos": 1}', 'rune_protection', 'materials', 'zaman_kuyusu', '{"cor_arcanum": 5, "fons_vitae": 3, "nucleus_abyssi": 2, "essentia_chronos": 1}', 2500000, 360),
  (gen_random_uuid(), 'rune_blessed', 70, 43200, 1.0, 300, '{"fons_vitae": 3, "aqua_aeterna": 3, "essentia_runica": 2, "infinitas_temporis": 1}', 'rune_blessed', 'materials', 'zaman_kuyusu', '{"fons_vitae": 3, "aqua_aeterna": 3, "essentia_runica": 2, "infinitas_temporis": 1}', 5000000, 720)
ON CONFLICT DO NOTHING;

-- 4. The enhance_item RPC
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
  v_debug JSONB := '{}'::jsonb;
  v_catalog_can_enhance BOOLEAN;
BEGIN
  IF p_player_id != auth.uid() THEN
    v_debug := jsonb_build_object('player_id', p_player_id, 'auth_uid', auth.uid());
    RETURN jsonb_build_object('error', 'Yetkisiz işlem', 'debug', v_debug);
  END IF;

  -- Get item with catalog data
  SELECT inv.*, items.rarity, items.can_enhance AS catalog_can_enhance
  INTO v_item
  FROM public.inventory inv
  JOIN public.items ON items.id = inv.item_id
  WHERE inv.row_id = p_row_id AND inv.user_id = p_player_id;
  -- Resolve whether catalog or inventory flag should be authoritative
  v_catalog_can_enhance := COALESCE(v_item.catalog_can_enhance, v_item.can_enhance, false);
  
  IF NOT FOUND THEN
    v_debug := jsonb_build_object('player_id', p_player_id, 'row_id', p_row_id);
    RETURN jsonb_build_object('error', 'item_not_found', 'debug', v_debug);
  END IF;
  
  IF NOT v_catalog_can_enhance THEN
    v_debug := jsonb_build_object(
      'item_id', v_item.item_id,
      'catalog_id', v_item.item_id,
      'rarity', v_item.rarity,
      'inv_can_enhance', v_item.can_enhance,
      'catalog_can_enhance', v_catalog_can_enhance,
      'enhancement_level', v_item.enhancement_level
    );
    RETURN jsonb_build_object('error', 'cannot_enhance', 'debug', v_debug);
  END IF;
  
  IF v_item.enhancement_level >= 10 THEN
    v_debug := jsonb_build_object('item_id', v_item.item_id, 'enhancement_level', v_item.enhancement_level);
    RETURN jsonb_build_object('error', 'max_level', 'debug', v_debug);
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
    v_debug := jsonb_build_object('player_gold', v_player.gold, 'required_gold', v_gold_cost);
    RETURN jsonb_build_object('error', 'insufficient_gold', 'debug', v_debug);
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
    v_debug := jsonb_build_object('scroll_id', v_scroll_id, 'has_scroll', v_has_scroll);
    RETURN jsonb_build_object('error', 'no_scroll', 'debug', v_debug);
  END IF;

  -- Rune check (if a rune is provided, ensure player has it in inventory)
  IF p_rune_type != 'none' THEN
    SELECT EXISTS(
      SELECT 1 FROM public.inventory 
      WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity > 0
    ) INTO v_has_rune;
    
    IF NOT v_has_rune THEN
      v_debug := jsonb_build_object('requested_rune', p_rune_type, 'has_rune', v_has_rune);
      RETURN jsonb_build_object('error', 'no_rune', 'debug', v_debug);
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
      ELSE
        v_new_level := GREATEST(0, v_item.enhancement_level - 1);
      END IF;
    ELSIF p_rune_type = 'blessed' THEN
      v_new_level := v_item.enhancement_level; -- Aynı kalır
    ELSE
      v_new_level := GREATEST(0, v_item.enhancement_level - 1);
    END IF;
  END IF;
  
  -- Consume gold + scroll + rune
  UPDATE public.users SET gold = gold - v_gold_cost WHERE auth_id = p_player_id AND gold >= v_gold_cost;
  IF NOT FOUND THEN
    v_debug := jsonb_build_object('player_gold_after_check', (SELECT gold FROM public.users WHERE auth_id = p_player_id), 'cost', v_gold_cost);
    RETURN jsonb_build_object('error', 'İşlem sırasında altın yetersiz kaldı', 'debug', v_debug);
  END IF;

  -- Decrease scroll quantity (delete if 0 handled by other mechanisms, or we can explicitly delete)
  WITH target_stack AS (
    SELECT row_id FROM public.inventory
    WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity > 0
    LIMIT 1
  )
  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = (SELECT row_id FROM target_stack) AND quantity > 0;
  IF NOT FOUND THEN
    v_debug := jsonb_build_object('scroll_id', v_scroll_id, 'expected_decrement', 1);
    RETURN jsonb_build_object('error', 'Geliştirme parşömeni yetersiz', 'debug', v_debug);
  END IF;

  DELETE FROM public.inventory WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity <= 0;

  IF p_rune_type != 'none' THEN
    WITH target_stack AS (
      SELECT row_id FROM public.inventory
      WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity > 0
      LIMIT 1
    )
    UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = (SELECT row_id FROM target_stack) AND quantity > 0;
    IF NOT FOUND THEN
      v_debug := jsonb_build_object('requested_rune', p_rune_type, 'expected_decrement', 1);
      RETURN jsonb_build_object('error', 'Seçilen rune yetersiz', 'debug', v_debug);
    END IF;
    
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
  
  v_debug := jsonb_build_object(
    'item_id', v_item.item_id,
    'previous_level', v_item.enhancement_level,
    'attempted_level', v_item.enhancement_level + 1,
    'new_level', v_new_level,
    'rune_used', p_rune_type,
    'scroll_used', v_scroll_id,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1),
    'inv_can_enhance', v_item.can_enhance,
    'catalog_can_enhance', v_catalog_can_enhance
  );

  RETURN jsonb_build_object(
    'success', v_success,
    'destroyed', v_destroyed,
    'new_level', v_new_level,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1),
    'debug', v_debug
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.enhance_item(UUID, UUID, TEXT) TO authenticated;
