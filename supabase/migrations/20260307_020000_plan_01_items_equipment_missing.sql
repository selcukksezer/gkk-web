-- =========================================================================================
-- MIGRATION: PLAN_01_ITEMS_EQUIPMENT MISSING COMPONENTS
-- =========================================================================================

-- 1. Ensure all missing columns exist in public.items table.
ALTER TABLE public.items
ADD COLUMN IF NOT EXISTS is_han_only BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_market_tradeable BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS is_direct_tradeable BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS sub_type TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS luck INTEGER DEFAULT 0;

ALTER TABLE public.items 
  ALTER COLUMN max_enhancement SET DEFAULT 10,
  ALTER COLUMN base_price SET DEFAULT 0,
  ALTER COLUMN vendor_sell_price SET DEFAULT 0;

-- 2. Power calculation functions based on PLAN_01_ITEMS_EQUIPMENT
-- Rarity Multipliers:
-- Common x1.0, Uncommon x1.8, Rare x3.2, Epic x5.5, Legendary x9.0, Mythic x15.0
-- Enhancement Bonus: final_stat = base_stat * (1 + enhancement_level * 0.15)
CREATE OR REPLACE FUNCTION public.calculate_item_power(
  p_item_id TEXT,
  p_enhancement_level INT
) RETURNS NUMERIC AS $$
DECLARE
  v_item RECORD;
  v_base_stat_sum NUMERIC;
  v_enhancement_mult NUMERIC;
  v_final_power NUMERIC;
BEGIN
  -- Get item stats
  SELECT * INTO v_item FROM public.items WHERE id = p_item_id;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- Sum of base stats (attack + defense + hp/10 + luck * 2) as defined in PLAN_01
  v_base_stat_sum := COALESCE(v_item.attack, 0) 
                   + COALESCE(v_item.defense, 0) 
                   + (COALESCE(v_item.health, 0) / 10.0) 
                   + (COALESCE(v_item.luck, 0) * 2.0);

  -- Enhancement Multiplier
  v_enhancement_mult := 1.0 + (COALESCE(p_enhancement_level, 0) * 0.15);

  -- Rarity multiplier should be already included in the base stats per PLAN_01, 
  -- so we only apply the enhancement multiplier.
  v_final_power := v_base_stat_sum * v_enhancement_mult;

  RETURN v_final_power;
END;
$$ LANGUAGE plpgsql STABLE;

-- 3. Function to calculate User's Total Power
-- total_power = Î£(tÃ¼m ekipmanlar: attack + defense + hp/10 + luckÃ—2) + level Ã— 500 + reputation Ã— 0.1
CREATE OR REPLACE FUNCTION public.calculate_user_total_power(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_user RECORD;
  v_equipment_power NUMERIC := 0;
  v_total_power NUMERIC := 0;
BEGIN
  -- 1. Calculate Equipment Power (Sum of equipped items)
  SELECT COALESCE(SUM(public.calculate_item_power(i.item_id, COALESCE(i.enhancement_level, 0))), 0)
  INTO v_equipment_power
  FROM public.inventory i
  WHERE i.user_id = p_user_id AND i.is_equipped = true;

  -- 2. Get User Stats
  SELECT level, reputation, attack, defense, health INTO v_user
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- 3. Calculate Total Power
  v_total_power := v_equipment_power 
                   + (COALESCE(v_user.level, 1) * 500) 
                   + (COALESCE(v_user.reputation, 0) * 0.1);

  RETURN v_total_power;
END;
$$ LANGUAGE plpgsql STABLE;

-- 4. Pazar Yeri (Market) Alias for Listing Item
-- The prompt explicitly mentions "pazar yeri market_list_item RPC'si". 
-- We wrap place_sell_order inside market_list_item.
CREATE OR REPLACE FUNCTION public.market_list_item(
  p_item_row_id UUID,
  p_quantity INT,
  p_price INT
) RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Assuming place_sell_order exists and handles market item placement
  SELECT public.place_sell_order(p_item_row_id, p_quantity, p_price) INTO v_result;
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;
