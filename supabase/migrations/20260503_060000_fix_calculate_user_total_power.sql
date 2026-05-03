-- =========================================================================================
-- MIGRATION: Fix calculate_user_total_power Function (column + formula sync)
-- =========================================================================================
-- Bug: calculate_user_total_power ekipman gücünü eksik/yanlış hesaplayabildiği için
-- backend success_rate ile Flutter success_rate ayrışıyordu.
-- Result: Equipment power = 0 hesaplandığından, backend'de success_rate yanlış
-- Effect: UI'de %95 başarı gösteriyor, backend %20 dönüyor
-- =========================================================================================

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
  SELECT level, reputation, attack, defense, health, luck INTO v_user
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- 3. Calculate Total Power (matching Flutter calculation)
  -- totalPower = equipmentPower + (level × 500) + (reputation × 0.1) + (luck × 50)
  v_total_power := v_equipment_power 
                   + (COALESCE(v_user.level, 1) * 500) 
                   + (COALESCE(v_user.reputation, 0) * 0.1)
                   + (COALESCE(v_user.luck, 0) * 50);

  RETURN v_total_power;
END;
$$ LANGUAGE plpgsql STABLE;

-- Note: calculate_item_power expected to exist and handle:
-- base_stat_sum = attack + defense + (health / 10.0) + (luck * 2.0)
-- final_power = base_stat_sum * (1 + enhancement_level * 0.15)
