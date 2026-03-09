-- =========================================================================================
-- MIGRATION: APPLY_MONUMENT_AND_CLASS_BONUSES (FAZ 9.2, 9.3, 10.3)
-- =========================================================================================

-- We will recreate or alter existing RPCs to inject guild monument and character class bonuses

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_overdose_save_at TIMESTAMPTZ;

-- 1. use_potion UPDATE (Monument Lv 20, Lv 80)
CREATE OR REPLACE FUNCTION public.use_potion(p_user_id UUID, p_row_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_guild RECORD;
  v_new_tolerance INT;
  v_overdose BOOLEAN := false;
  v_efficiency NUMERIC;
  v_overdose_chance NUMERIC;
  v_roll NUMERIC;
  v_hospital_minutes INT;
  v_heal_amount INT;
  v_monument_level INT := 0;
  v_saved_from_overdose BOOLEAN := false;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı'); END IF;

  -- Get Monument level
  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_user.guild_id;
  END IF;

  SELECT * INTO v_inv FROM public.inventory WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz'); END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR v_item.type != 'potion' THEN RETURN jsonb_build_object('error', 'Geçersiz iksir'); END IF;

  -- Tolerance artışı (Alchemist: -%25)
  v_new_tolerance := COALESCE(v_user.tolerance, 0) + COALESCE(v_item.tolerance_increase, 0);
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_new_tolerance := COALESCE(v_user.tolerance, 0) + floor(COALESCE(v_item.tolerance_increase, 0) * 0.75);
  END IF;
  v_new_tolerance := GREATEST(0, LEAST(v_new_tolerance, 100));

  -- Etkinlik hesaplama (Alchemist: +%30)
  v_efficiency := CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 20 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.85
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 0.65
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 0.45
    ELSE 0.25
  END;
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN v_efficiency := LEAST(1.0, v_efficiency * 1.30); END IF;

  -- Overdose kontrolü
  v_overdose_chance := COALESCE(v_item.overdose_risk, 0) * CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.0
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 2.0
    WHEN COALESCE(v_user.tolerance, 0) <= 90 THEN 4.0
    ELSE 8.0
  END;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN v_overdose_chance := v_overdose_chance * 0.80; END IF;
  
  -- Monument Lv 20: Overdose Chance -10%
  IF v_monument_level >= 20 THEN
    v_overdose_chance := v_overdose_chance * 0.90;
  END IF;

  v_roll := random();
  IF v_roll <= v_overdose_chance THEN
    v_overdose := true;

    IF v_monument_level >= 80 AND (
      v_user.last_overdose_save_at IS NULL OR
      v_user.last_overdose_save_at::date < CURRENT_DATE
    ) THEN
      v_overdose := false;
      v_saved_from_overdose := true;
    END IF;
  END IF;

  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = p_row_id AND quantity > 0;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz'); END IF;
  DELETE FROM public.inventory WHERE quantity <= 0 AND row_id = p_row_id;

  IF v_overdose THEN
    v_hospital_minutes := 30 + (COALESCE(v_user.tolerance, 0) * 2);
    UPDATE public.users SET 
      addiction_level = LEAST(COALESCE(addiction_level, 0) + 1, 10),
      tolerance = LEAST(v_new_tolerance + 10, 100),
      hospital_until = now() + (v_hospital_minutes || ' minutes')::interval,
      hospital_reason = 'Overdose',
      last_potion_used_at = now()
    WHERE auth_id = p_user_id;

    INSERT INTO public.tolerance_log (user_id, event_type, item_id, tolerance_before, tolerance_after, addiction_before, addiction_after)
    VALUES (p_user_id, 'overdose', v_inv.item_id, COALESCE(v_user.tolerance, 0), LEAST(v_new_tolerance + 10, 100), COALESCE(v_user.addiction_level, 0), LEAST(COALESCE(v_user.addiction_level, 0) + 1, 10));

    RETURN jsonb_build_object('success', true, 'overdose', true, 'hospital_minutes', v_hospital_minutes, 'efficiency', 0);
  END IF;

  v_heal_amount := FLOOR(COALESCE(v_item.heal_amount, 0) * v_efficiency);
  UPDATE public.users SET 
    tolerance = v_new_tolerance,
    last_potion_used_at = now(),
    last_overdose_save_at = CASE WHEN v_saved_from_overdose THEN now() ELSE last_overdose_save_at END,
    energy = LEAST(100, energy + FLOOR(COALESCE(v_item.energy_restore, 0) * v_efficiency)),
    health = LEAST(max_health, health + v_heal_amount)
  WHERE auth_id = p_user_id;

  INSERT INTO public.tolerance_log (user_id, event_type, item_id, tolerance_before, tolerance_after, addiction_before, addiction_after)
  VALUES (p_user_id, 'potion_use', v_inv.item_id, COALESCE(v_user.tolerance, 0), v_new_tolerance, COALESCE(v_user.addiction_level, 0), COALESCE(v_user.addiction_level, 0));

  RETURN jsonb_build_object('success', true, 'overdose', false, 'saved_from_overdose', v_saved_from_overdose, 'efficiency', v_efficiency, 'new_tolerance', v_new_tolerance, 'heal_amount', v_heal_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. enhance_item UPDATE (Monument Lv 90)
CREATE OR REPLACE FUNCTION public.enhance_item(p_player_id UUID, p_row_id UUID, p_rune_type TEXT DEFAULT 'none')
RETURNS JSONB AS $$
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
  v_monument_level INT := 0;
BEGIN
  SELECT inv.*, items.rarity, items.can_enhance INTO v_item FROM public.inventory inv JOIN public.items ON items.id = inv.item_id WHERE inv.row_id = p_row_id AND inv.user_id = p_player_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'item_not_found'); END IF;
  IF NOT v_item.can_enhance THEN RETURN jsonb_build_object('error', 'cannot_enhance'); END IF;
  IF v_item.enhancement_level >= 10 THEN RETURN jsonb_build_object('error', 'max_level'); END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  IF v_player.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_player.guild_id;
  END IF;

  v_rarity_mult := CASE v_item.rarity WHEN 'common' THEN 1.0 WHEN 'uncommon' THEN 1.5 WHEN 'rare' THEN 2.5 WHEN 'epic' THEN 4.0 WHEN 'legendary' THEN 7.0 WHEN 'mythic' THEN 12.0 ELSE 1.0 END;
  v_base_cost := (ARRAY[100000,200000,300000,500000,1500000,3500000,7500000,15000000,50000000,200000000,1000000000])[v_item.enhancement_level + 1];
  v_gold_cost := floor(v_base_cost * v_rarity_mult);
  
  -- Monument Lv 90: enhancement gold -5%
  IF v_monument_level >= 90 THEN v_gold_cost := floor(v_gold_cost * 0.95); END IF;

  IF v_player.gold < v_gold_cost THEN RETURN jsonb_build_object('error', 'insufficient_gold'); END IF;

  v_scroll_id := CASE WHEN v_item.rarity IN ('common', 'uncommon') THEN 'scroll_upgrade_low' WHEN v_item.rarity IN ('rare', 'epic') THEN 'scroll_upgrade_middle' ELSE 'scroll_upgrade_high' END;
  
  SELECT EXISTS(SELECT 1 FROM public.inventory WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity > 0) INTO v_has_scroll;
  IF NOT v_has_scroll THEN RETURN jsonb_build_object('error', 'no_scroll'); END IF;

  IF p_rune_type != 'none' THEN
    SELECT EXISTS(SELECT 1 FROM public.inventory WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity > 0) INTO v_has_rune;
    IF NOT v_has_rune THEN RETURN jsonb_build_object('error', 'no_rune'); END IF;
  END IF;

  v_success_rate := (ARRAY[1.0,1.0,1.0,1.0,0.7,0.6,0.5,0.35,0.2,0.1,0.03])[v_item.enhancement_level + 1];
  v_destroy_rate := (ARRAY[0,0,0,0,0,0,1.0,1.0,1.0,1.0,1.0])[v_item.enhancement_level + 1];

  IF p_rune_type = 'basic' THEN v_success_rate := v_success_rate + 0.05;
  ELSIF p_rune_type = 'advanced' THEN v_success_rate := v_success_rate + 0.10;
  ELSIF p_rune_type = 'superior' THEN v_success_rate := v_success_rate + 0.15; v_destroy_rate := v_destroy_rate * 0.5;
  ELSIF p_rune_type = 'legendary' THEN v_success_rate := v_success_rate + 0.25; v_destroy_rate := v_destroy_rate * 0.25;
  ELSIF p_rune_type = 'protection' THEN v_destroy_rate := 0;
  ELSIF p_rune_type = 'blessed' THEN v_success_rate := v_success_rate + 0.20; v_destroy_rate := v_destroy_rate * 0.5;
  END IF;

  v_success_rate := LEAST(1.0, v_success_rate);
  v_destroy_rate := GREATEST(0, v_destroy_rate);

  v_success := random() <= v_success_rate;
  v_new_level := v_item.enhancement_level;

  IF v_success THEN v_new_level := v_item.enhancement_level + 1;
  ELSE
    IF v_item.enhancement_level >= 6 AND p_rune_type != 'protection' AND p_rune_type != 'blessed' THEN
      IF random() <= v_destroy_rate THEN v_destroyed := true; ELSE v_new_level := GREATEST(0, v_item.enhancement_level - 1); END IF;
    ELSIF p_rune_type = 'blessed' THEN v_new_level := v_item.enhancement_level;
    ELSE v_new_level := GREATEST(0, v_item.enhancement_level - 1); END IF;
  END IF;

  UPDATE public.users SET gold = gold - v_gold_cost WHERE auth_id = p_player_id AND gold >= v_gold_cost;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'İşlem sırasında altın yetersiz kaldı'); END IF;

  WITH target_stack AS (SELECT row_id FROM public.inventory WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity > 0 LIMIT 1)
  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = (SELECT row_id FROM target_stack) AND quantity > 0;
  DELETE FROM public.inventory WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity <= 0;

  IF p_rune_type != 'none' THEN
    WITH target_stack AS (SELECT row_id FROM public.inventory WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity > 0 LIMIT 1)
    UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = (SELECT row_id FROM target_stack) AND quantity > 0;
    DELETE FROM public.inventory WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity <= 0;
  END IF;

  IF v_destroyed THEN DELETE FROM public.inventory WHERE row_id = p_row_id;
  ELSE UPDATE public.inventory SET enhancement_level = v_new_level WHERE row_id = p_row_id; END IF;

  INSERT INTO public.enhancement_history (player_id, item_id, item_row_id, previous_level, attempted_level, new_level, rune_used, scroll_used, gold_spent, success, destroyed, success_rate_at_attempt)
  VALUES (p_player_id, v_item.item_id, p_row_id, v_item.enhancement_level, v_item.enhancement_level + 1, v_new_level, p_rune_type, v_scroll_id, v_gold_cost, v_success, v_destroyed, v_success_rate);

  RETURN jsonb_build_object('success', v_success, 'destroyed', v_destroyed, 'new_level', v_new_level, 'gold_spent', v_gold_cost, 'success_rate', round(v_success_rate * 100, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. start_crafting UPDATE (Monument Lv 35: +3% success)
-- We will assume start_craft_queue or equivalent exists. The original was in 20260301_020000_create_craft_queue_and_rpcs.sql
-- We'll just patch start_crafting directly:
CREATE OR REPLACE FUNCTION public.start_crafting(p_user_id UUID, p_recipe_id UUID, p_quantity INT)
RETURNS JSONB AS $$
DECLARE
  v_recipe RECORD;
  v_user RECORD;
  v_facility RECORD;
  v_total_gold BIGINT;
  v_total_duration INT;
  v_materials JSONB;
  v_key TEXT;
  v_val INT;
  v_inv_qty INT;
  v_monument_level INT := 0;
  v_success_rate NUMERIC;
BEGIN
  SELECT * INTO v_recipe FROM public.craft_recipes WHERE id = p_recipe_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Tarif bulunamadı'); END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF v_user.level < v_recipe.required_player_level THEN RETURN jsonb_build_object('success', false, 'error', 'Seviyeniz yetersiz'); END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_user.guild_id;
  END IF;

  v_total_gold := (v_recipe.gold_cost * p_quantity)::BIGINT;
  IF v_user.gold < v_total_gold THEN RETURN jsonb_build_object('success', false, 'error', 'Altınınız yetersiz'); END IF;

  IF v_recipe.facility_type != 'none' THEN
    SELECT * INTO v_facility FROM public.player_facilities WHERE user_id = p_user_id AND facility_type = v_recipe.facility_type;
    IF NOT FOUND OR v_facility.level < v_recipe.required_facility_level THEN
      RETURN jsonb_build_object('success', false, 'error', 'Gerekli tesis seviyesi yetersiz');
    END IF;
  END IF;

  v_materials := v_recipe.materials;
  FOR v_key, v_val IN SELECT * FROM jsonb_each_text(v_materials) LOOP
    SELECT COALESCE(SUM(quantity), 0) INTO v_inv_qty FROM public.inventory WHERE user_id = p_user_id AND item_id = v_key;
    IF v_inv_qty < (v_val::INT * p_quantity) THEN RETURN jsonb_build_object('success', false, 'error', 'Gerekli materyaller eksik'); END IF;
  END LOOP;

  UPDATE public.users SET gold = gold - v_total_gold WHERE auth_id = p_user_id AND gold >= v_total_gold;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'İşlem sırasında altın yetersiz kaldı'); END IF;

  FOR v_key, v_val IN SELECT * FROM jsonb_each_text(v_materials) LOOP
    DECLARE
      v_needed INT := v_val::INT * p_quantity;
      v_row RECORD;
    BEGIN
      FOR v_row IN SELECT row_id, quantity FROM public.inventory WHERE user_id = p_user_id AND item_id = v_key AND quantity > 0 ORDER BY quantity ASC LOOP
        IF v_needed <= 0 THEN EXIT; END IF;
        IF v_row.quantity <= v_needed THEN
          DELETE FROM public.inventory WHERE row_id = v_row.row_id;
          v_needed := v_needed - v_row.quantity;
        ELSE
          UPDATE public.inventory SET quantity = quantity - v_needed WHERE row_id = v_row.row_id;
          v_needed := 0;
        END IF;
      END LOOP;
    END;
  END LOOP;

  v_total_duration := v_recipe.duration_minutes * p_quantity;
  -- Alchemist: %20 süre azaltma, %15 success rate artışı
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_total_duration := floor(v_total_duration * 0.80);
  END IF;

  v_success_rate := v_recipe.success_rate;
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_success_rate := v_success_rate + 0.15;
  END IF;

  -- Monument Lv 35: +%3 success
  IF v_monument_level >= 35 THEN
    v_success_rate := v_success_rate + 0.03;
  END IF;

  v_success_rate := LEAST(v_success_rate, 1.0);

  INSERT INTO public.craft_queue (user_id, recipe_id, quantity, expected_success_rate, status, started_at, completes_at)
  VALUES (p_user_id, p_recipe_id, p_quantity, v_success_rate, 'crafting', now(), now() + (v_total_duration || ' minutes')::INTERVAL);

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. enter_dungeon UPDATE (Monument Lv 30, 55, 60, Boss Blueprint Drop)
CREATE OR REPLACE FUNCTION public.enter_dungeon(p_player_id UUID, p_dungeon_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_dungeon RECORD;
  v_player RECORD;
  v_power INTEGER;
  v_success_rate NUMERIC;
  v_success BOOLEAN;
  v_is_critical BOOLEAN;
  v_gold INTEGER;
  v_xp INTEGER;
  v_hospitalized BOOLEAN := false;
  v_hospital_until TIMESTAMPTZ;
  v_hospital_minutes INTEGER;
  v_is_first BOOLEAN := false;
  v_items JSONB := '[]'::JSONB;
  v_today_attempts INTEGER;
  v_today_boss INTEGER;
  v_luck_for_loot NUMERIC;
  v_ratio NUMERIC;
  v_hospital_chance NUMERIC;
  v_defense_mitigation NUMERIC;
  v_monument_level INT := 0;
  v_blueprint_chance NUMERIC;
  v_bp_type TEXT;
BEGIN
  SELECT * INTO v_dungeon FROM public.dungeons WHERE id = p_dungeon_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'dungeon_not_found'); END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'player_not_found'); END IF;

  IF v_player.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_player.guild_id;
  END IF;

  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN RETURN jsonb_build_object('error', 'in_hospital'); END IF;
  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN RETURN jsonb_build_object('error', 'in_prison'); END IF;
  IF v_player.energy < v_dungeon.energy_cost THEN RETURN jsonb_build_object('error', 'insufficient_energy'); END IF;

  INSERT INTO public.player_dungeon_stats (player_id, dungeon_id) VALUES (p_player_id, p_dungeon_id) ON CONFLICT (player_id, dungeon_id) DO NOTHING;
  UPDATE public.player_dungeon_stats SET today_attempts = 0, today_boss_attempts = 0, today_date = CURRENT_DATE WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id AND today_date < CURRENT_DATE;
  
  SELECT today_boss_attempts INTO v_today_boss FROM public.player_dungeon_stats WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;
  IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN RETURN jsonb_build_object('error', 'boss_daily_limit'); END IF;

  v_power := COALESCE(v_player.power, 0);
  IF v_power = 0 THEN v_power := v_player.level * 500 + floor(COALESCE(v_player.reputation, 0) * 0.1) + floor(COALESCE(v_player.luck, 0) * 50); END IF;

  IF v_dungeon.power_requirement = 0 THEN v_success_rate := 1.0;
  ELSE
    v_ratio := v_power::NUMERIC / v_dungeon.power_requirement;
    IF v_ratio >= 1.5 THEN v_success_rate := 0.95;
    ELSIF v_ratio >= 1.0 THEN v_success_rate := 0.70 + (v_ratio - 1.0) * 0.50;
    ELSIF v_ratio >= 0.5 THEN v_success_rate := 0.25 + (v_ratio - 0.5) * 0.90;
    ELSIF v_ratio >= 0.25 THEN v_success_rate := 0.10 + (v_ratio - 0.25) * 0.60;
    ELSE v_success_rate := GREATEST(0.05, v_ratio * 0.40); END IF;
  END IF;

  v_success_rate := v_success_rate + COALESCE(v_player.luck, 0) * 0.001;
  IF COALESCE(v_player.character_class, '') = 'warrior' THEN v_success_rate := v_success_rate + 0.05; END IF;
  
  -- Monument Lv 55: Boss damage +5% (adds directly to success rate for simplicity)
  IF v_dungeon.is_boss AND v_monument_level >= 55 THEN v_success_rate := v_success_rate + 0.05; END IF;

  v_success_rate := LEAST(0.95, v_success_rate);
  v_success := random() <= v_success_rate;
  v_is_critical := v_success AND random() <= 0.10;

  IF v_success THEN
    v_gold := v_dungeon.gold_min + floor(random() * (v_dungeon.gold_max - v_dungeon.gold_min));
    v_xp := v_dungeon.xp_reward;
    IF v_is_critical THEN v_gold := floor(v_gold * 1.5); v_xp := floor(v_xp * 1.5); END IF;

    v_luck_for_loot := COALESCE(v_player.luck, 0);
    IF COALESCE(v_player.character_class, '') = 'shadow' THEN v_luck_for_loot := v_luck_for_loot * 1.40; END IF;
    
    -- Monument Lv 30: Loot luck +10
    IF v_monument_level >= 30 THEN v_luck_for_loot := v_luck_for_loot + 10; END IF;

    v_gold := floor(v_gold * (1 + v_luck_for_loot * 0.002));
    v_xp   := floor(v_xp   * (1 + COALESCE(v_player.luck, 0) * 0.001));

    IF COALESCE(v_player.character_class, '') = 'warrior' AND v_dungeon.is_boss THEN v_gold := floor(v_gold * 1.15); END IF;
    
    -- Boss blueprint drop (Zone 5-7)
    IF v_dungeon.is_boss AND v_dungeon.zone >= 5 AND v_player.guild_id IS NOT NULL THEN
      -- Chance ranges from 0.5% to 5%
      v_blueprint_chance := 0.005 + (v_dungeon.zone - 5) * 0.02;
      IF random() <= v_blueprint_chance THEN
        v_bp_type := CASE WHEN v_dungeon.zone = 5 THEN 'titan' WHEN v_dungeon.zone = 6 THEN 'world_eater' ELSE 'eternal' END;
        INSERT INTO public.guild_blueprints (guild_id, blueprint_type, fragments)
        VALUES (v_player.guild_id, v_bp_type, 1)
        ON CONFLICT (guild_id, blueprint_type) DO UPDATE SET fragments = public.guild_blueprints.fragments + 1;
        -- Can add to v_items or separate log if needed.
      END IF;
    END IF;

  ELSE
    v_gold := floor(v_dungeon.gold_min * 0.3);
    v_xp := floor(v_dungeon.xp_reward * 0.2);

    v_hospital_chance := GREATEST(0.05, LEAST(0.90, 1.0 - v_success_rate));
    v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);
    IF random() <= v_hospital_chance THEN
      v_hospitalized := true;
      v_hospital_minutes := v_dungeon.hospital_min_minutes + floor(random() * GREATEST(0, v_dungeon.hospital_max_minutes - v_dungeon.hospital_min_minutes));
      v_defense_mitigation := LEAST(0.30, COALESCE(v_player.defense, 0) * 0.001);
      v_hospital_minutes := floor(v_hospital_minutes * (1 - v_defense_mitigation));
      
      IF COALESCE(v_player.character_class, '') = 'warrior' THEN v_hospital_minutes := floor(v_hospital_minutes * 0.80); END IF;
      -- Monument Lv 60: Hospital time -10%
      IF v_monument_level >= 60 THEN v_hospital_minutes := floor(v_hospital_minutes * 0.90); END IF;

      v_hospital_until := now() + (v_hospital_minutes || ' minutes')::INTERVAL;
      UPDATE public.users SET hospital_until = v_hospital_until WHERE auth_id = p_player_id;
    END IF;
  END IF;

  IF v_success THEN
    SELECT (first_clear_at IS NULL) INTO v_is_first FROM public.player_dungeon_stats WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;
    IF v_is_first THEN v_gold := v_gold + (v_dungeon.gold_max * 5); v_xp := v_xp + (v_dungeon.xp_reward * 10); END IF;
  END IF;

  UPDATE public.users SET energy = energy - v_dungeon.energy_cost, gold = gold + v_gold, xp = xp + v_xp WHERE auth_id = p_player_id AND energy >= v_dungeon.energy_cost;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'Yetersiz enerji veya işlem çakışması'); END IF;

  UPDATE public.player_dungeon_stats SET
    total_attempts = total_attempts + 1, total_successes = total_successes + CASE WHEN v_success THEN 1 ELSE 0 END, total_failures = total_failures + CASE WHEN v_success THEN 0 ELSE 1 END,
    first_clear_at = CASE WHEN v_success AND first_clear_at IS NULL THEN now() ELSE first_clear_at END, today_attempts = today_attempts + 1, today_boss_attempts = today_boss_attempts + CASE WHEN v_dungeon.is_boss THEN 1 ELSE 0 END,
    today_date = CURRENT_DATE, best_power_at_clear = CASE WHEN v_success AND v_power > best_power_at_clear THEN v_power ELSE best_power_at_clear END
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  INSERT INTO public.dungeon_runs (player_id, dungeon_id, success, is_critical, gold_earned, xp_earned, items_dropped, hospitalized, hospital_until, player_power, success_rate_at_run, is_first_clear)
  VALUES (p_player_id, p_dungeon_id, v_success, v_is_critical, v_gold, v_xp, v_items, v_hospitalized, v_hospital_until, v_power, v_success_rate, v_is_first);

  RETURN jsonb_build_object('success', v_success, 'is_critical', v_is_critical, 'gold_earned', v_gold, 'xp_earned', v_xp, 'items_dropped', v_items, 'hospitalized', v_hospitalized, 'hospital_until', v_hospital_until, 'is_first_clear', v_is_first, 'success_rate', round(v_success_rate * 100, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. pvp_attack UPDATE (Warrior Bloodlust: +10% ATK buff equivalent or status)
-- We'll add a 'bloodlust_until' flag or similar, but since we cannot easily add a buff engine here quickly, 
-- we will update `users` table to have a simple `warrior_bloodlust_until` TIMESTAMPTZ.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS warrior_bloodlust_until TIMESTAMPTZ;

-- Let's update the existing pvp_attack slightly to grant Bloodlust to Warriors on win.
CREATE OR REPLACE FUNCTION public.pvp_attack(p_attacker_id UUID, p_defender_id UUID, p_mekan_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_attacker RECORD;
  v_defender RECORD;
  v_mekan RECORD;
  v_attacker_hp INT;
  v_defender_hp INT;
  v_winner_id UUID;
  v_gold_stolen BIGINT;
  v_rep_win INT;
  v_rep_loss INT;
  v_rating_diff INT;
  v_expected_a NUMERIC;
  v_new_rating_a INT;
  v_new_rating_d INT;
  v_hospital BOOLEAN := false;
  v_critical BOOLEAN := false;
  v_steal_rate NUMERIC;
  v_total_gold BIGINT;
  v_mekan_commission BIGINT;
  v_daily_count INT;
BEGIN
  SELECT * INTO v_attacker FROM public.users WHERE auth_id = p_attacker_id FOR UPDATE;
  SELECT * INTO v_defender FROM public.users WHERE auth_id = p_defender_id FOR UPDATE;

  IF v_attacker IS NULL OR v_defender IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi'); END IF;
  IF v_attacker.level < 10 OR v_defender.level < 10 THEN RETURN jsonb_build_object('success', false, 'error', 'PvP için minimum level 10'); END IF;
  IF v_attacker.energy < 15 THEN RETURN jsonb_build_object('success', false, 'error', 'Enerji yetersiz (15 gerekli)'); END IF;
  IF v_attacker.hospital_until > now() OR v_attacker.prison_until > now() THEN RETURN jsonb_build_object('success', false, 'error', 'Hastanede/hapiste PvP yapilamaz'); END IF;
  IF v_defender.hospital_until > now() OR v_defender.prison_until > now() THEN RETURN jsonb_build_object('success', false, 'error', 'Rakip musait degil'); END IF;
  IF v_attacker.guild_id IS NOT NULL AND v_attacker.guild_id = v_defender.guild_id THEN RETURN jsonb_build_object('success', false, 'error', 'Ayni lonca uyesine saldirilamaz'); END IF;

  SELECT COALESCE(attack_count, 0) INTO v_daily_count FROM public.pvp_daily_attacks WHERE attacker_id = p_attacker_id AND defender_id = p_defender_id AND attack_date = CURRENT_DATE;
  IF v_daily_count >= 3 THEN RETURN jsonb_build_object('success', false, 'error', 'Bu oyuncuya bugun 3 kez saldirdiniz'); END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND OR v_mekan.mekan_type NOT IN ('dovus_kulubu', 'luks_lounge', 'yeralti') THEN RETURN jsonb_build_object('success', false, 'error', 'Bu mekanda PvP yapilamaz'); END IF;

  IF ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > 300 THEN RETURN jsonb_build_object('success', false, 'error', 'Rating farki cok yuksek (max ±300)'); END IF;

  v_attacker_hp := COALESCE(v_attacker.health, 100);
  v_defender_hp := COALESCE(v_defender.health, 100);

  FOR i IN 1..3 LOOP
    DECLARE
      v_atk_dmg NUMERIC;
      v_def_dmg NUMERIC;
      v_atk_crit BOOLEAN;
      v_def_crit BOOLEAN;
    BEGIN
      v_atk_crit := random() < (COALESCE(v_attacker.luck, 0) * 0.002);
      v_def_crit := random() < (COALESCE(v_defender.luck, 0) * 0.002);

      -- Kan Hırsı buff applying to raw ATK is tough without complex state, we just boost dmg directly.
      v_atk_dmg := COALESCE(v_attacker.attack, 10) * (0.8 + random() * 0.4) * CASE WHEN v_atk_crit THEN 1.5 ELSE 1.0 END;
      IF COALESCE(v_attacker.character_class, '') = 'warrior' AND COALESCE(v_attacker.warrior_bloodlust_until, '1970-01-01'::timestamptz) > now() THEN v_atk_dmg := v_atk_dmg * 1.10; END IF;
      v_atk_dmg := v_atk_dmg - COALESCE(v_defender.defense, 10) * 0.3;

      v_def_dmg := COALESCE(v_defender.attack, 10) * (0.8 + random() * 0.4) * CASE WHEN v_def_crit THEN 1.5 ELSE 1.0 END;
      IF COALESCE(v_defender.character_class, '') = 'warrior' AND COALESCE(v_defender.warrior_bloodlust_until, '1970-01-01'::timestamptz) > now() THEN v_def_dmg := v_def_dmg * 1.10; END IF;
      v_def_dmg := v_def_dmg - COALESCE(v_attacker.defense, 10) * 0.3;

      v_atk_dmg := GREATEST(v_atk_dmg, 1);
      v_def_dmg := GREATEST(v_def_dmg, 1);

      v_defender_hp := v_defender_hp - v_atk_dmg::int;
      v_attacker_hp := v_attacker_hp - v_def_dmg::int;
    END;
  END LOOP;

  IF v_attacker_hp > v_defender_hp THEN v_winner_id := p_attacker_id; ELSIF v_defender_hp > v_attacker_hp THEN v_winner_id := p_defender_id; ELSE v_winner_id := CASE WHEN COALESCE(v_attacker.power, 0) >= COALESCE(v_defender.power, 0) THEN p_attacker_id ELSE p_defender_id END; END IF;

  UPDATE public.users SET energy = energy - 15 WHERE auth_id = p_attacker_id AND energy >= 15;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda enerji yetersiz kaldi'); END IF;

  v_rating_diff := COALESCE(v_defender.pvp_rating, 1000) - COALESCE(v_attacker.pvp_rating, 1000);
  v_expected_a := 1.0 / (1.0 + power(10.0, v_rating_diff::numeric / 400.0));
  IF v_winner_id = p_attacker_id THEN v_new_rating_a := COALESCE(v_attacker.pvp_rating, 1000) + (32 * (1.0 - v_expected_a))::int; v_new_rating_d := COALESCE(v_defender.pvp_rating, 1000) + (32 * (0.0 - (1.0 - v_expected_a)))::int; ELSE v_new_rating_a := COALESCE(v_attacker.pvp_rating, 1000) + (32 * (0.0 - v_expected_a))::int; v_new_rating_d := COALESCE(v_defender.pvp_rating, 1000) + (32 * (1.0 - (1.0 - v_expected_a)))::int; END IF;
  v_new_rating_a := GREATEST(v_new_rating_a, 0); v_new_rating_d := GREATEST(v_new_rating_d, 0);

  v_rating_diff := COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000);
  IF v_winner_id = p_attacker_id THEN
    v_steal_rate := CASE WHEN v_rating_diff > 200 THEN 0.01 WHEN v_rating_diff > 0 THEN 0.02 WHEN v_rating_diff > -200 THEN 0.03 ELSE 0.05 END;
    v_gold_stolen := GREATEST(LEAST((v_defender.gold * v_steal_rate)::bigint, 5000000::bigint), 10000::bigint);
    v_mekan_commission := (v_gold_stolen * 0.05)::bigint; v_total_gold := v_gold_stolen - v_mekan_commission;
  ELSE
    v_steal_rate := CASE WHEN v_rating_diff < -200 THEN 0.01 WHEN v_rating_diff < 0 THEN 0.02 WHEN v_rating_diff < 200 THEN 0.03 ELSE 0.05 END;
    v_gold_stolen := GREATEST(LEAST((v_attacker.gold * v_steal_rate)::bigint, 5000000::bigint), 10000::bigint);
    v_mekan_commission := (v_gold_stolen * 0.05)::bigint; v_total_gold := v_gold_stolen - v_mekan_commission;
  END IF;

  v_rep_win := (100 * CASE WHEN ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > 200 THEN 0.5 WHEN ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > 0 THEN 1.0 WHEN ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > -200 THEN 1.5 ELSE 2.5 END)::int;
  v_rep_loss := (50 * 1.0)::int;

  IF v_winner_id IS NOT NULL THEN
    DECLARE
      v_hp_diff NUMERIC;
      v_winner_hp INT := CASE WHEN v_winner_id = p_attacker_id THEN v_attacker_hp ELSE v_defender_hp END;
      v_loser_hp INT := CASE WHEN v_winner_id = p_attacker_id THEN v_defender_hp ELSE v_attacker_hp END;
      v_winner_rating INT := CASE WHEN v_winner_id = p_attacker_id THEN COALESCE(v_attacker.pvp_rating, 1000) ELSE COALESCE(v_defender.pvp_rating, 1000) END;
      v_loser_rating INT := CASE WHEN v_winner_id = p_attacker_id THEN COALESCE(v_defender.pvp_rating, 1000) ELSE COALESCE(v_attacker.pvp_rating, 1000) END;
    BEGIN
      v_hp_diff := (v_winner_hp - v_loser_hp)::numeric / GREATEST(v_winner_hp, 1);
      IF v_hp_diff > 0.5 AND (v_loser_rating - v_winner_rating) > 100 THEN v_critical := true; v_rep_win := v_rep_win * 3; v_total_gold := v_total_gold * 2; END IF;
    END;
  END IF;

  IF v_winner_id = p_attacker_id THEN
    UPDATE public.users SET pvp_wins = COALESCE(pvp_wins, 0) + 1, pvp_rating = v_new_rating_a, gold = gold + v_total_gold, reputation = COALESCE(reputation, 0) + v_rep_win,
           warrior_bloodlust_until = CASE WHEN character_class = 'warrior' THEN now() + '30 minutes'::interval ELSE warrior_bloodlust_until END
    WHERE auth_id = p_attacker_id;

    v_hospital := random() < 0.10;
    UPDATE public.users SET pvp_losses = COALESCE(pvp_losses, 0) + 1, pvp_rating = v_new_rating_d, gold = GREATEST(gold - v_gold_stolen, 0::bigint), reputation = GREATEST(COALESCE(reputation, 0) - v_rep_loss, 0), hospital_until = CASE WHEN v_hospital THEN now() + '30 minutes'::interval ELSE hospital_until END, hospital_reason = CASE WHEN v_hospital THEN 'PvP Defeat' ELSE hospital_reason END
    WHERE auth_id = p_defender_id;
  ELSE
    v_hospital := random() < 0.10;
    UPDATE public.users SET pvp_losses = COALESCE(pvp_losses, 0) + 1, pvp_rating = v_new_rating_a, gold = GREATEST(gold - v_gold_stolen, 0::bigint), reputation = GREATEST(COALESCE(reputation, 0) - v_rep_loss, 0), hospital_until = CASE WHEN v_hospital THEN now() + '30 minutes'::interval ELSE hospital_until END, hospital_reason = CASE WHEN v_hospital THEN 'PvP Defeat' ELSE hospital_reason END
    WHERE auth_id = p_attacker_id;

    UPDATE public.users SET pvp_wins = COALESCE(pvp_wins, 0) + 1, pvp_rating = v_new_rating_d, gold = gold + v_total_gold, reputation = COALESCE(reputation, 0) + v_rep_win,
           warrior_bloodlust_until = CASE WHEN character_class = 'warrior' THEN now() + '30 minutes'::interval ELSE warrior_bloodlust_until END
    WHERE auth_id = p_defender_id;
  END IF;

  UPDATE public.users SET gold = gold + v_mekan_commission WHERE auth_id = v_mekan.owner_id;
  INSERT INTO public.pvp_daily_attacks (attacker_id, defender_id, attack_date, attack_count) VALUES (p_attacker_id, p_defender_id, CURRENT_DATE, 1) ON CONFLICT (attacker_id, defender_id, attack_date) DO UPDATE SET attack_count = public.pvp_daily_attacks.attack_count + 1;
  INSERT INTO public.pvp_matches (mekan_id, attacker_id, defender_id, winner_id, attacker_power, defender_power, attacker_hp_remaining, defender_hp_remaining, gold_stolen, rep_change_winner, rep_change_loser, attacker_rating_before, attacker_rating_after, defender_rating_before, defender_rating_after, is_critical_success, hospital_triggered)
  VALUES (p_mekan_id, p_attacker_id, p_defender_id, v_winner_id, COALESCE(v_attacker.power, 0), COALESCE(v_defender.power, 0), GREATEST(v_attacker_hp, 0), GREATEST(v_defender_hp, 0), v_gold_stolen, v_rep_win, v_rep_loss, COALESCE(v_attacker.pvp_rating, 1000), v_new_rating_a, COALESCE(v_defender.pvp_rating, 1000), v_new_rating_d, v_critical, v_hospital);

  RETURN jsonb_build_object('success', true, 'winner', v_winner_id, 'attacker_hp', GREATEST(v_attacker_hp, 0), 'defender_hp', GREATEST(v_defender_hp, 0), 'gold_stolen', v_gold_stolen, 'rep_change', CASE WHEN v_winner_id = p_attacker_id THEN v_rep_win ELSE -v_rep_loss END, 'new_rating', v_new_rating_a, 'critical_success', v_critical, 'hospital', v_hospital);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
