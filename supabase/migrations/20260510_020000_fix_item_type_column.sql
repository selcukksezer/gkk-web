-- ==================================================================================
-- HOTFIX: enter_dungeon — item_type → type kolon adı düzeltmesi
-- items tablosunda kolon adı 'type' (item_type değil)
-- ==================================================================================

CREATE OR REPLACE FUNCTION public.enter_dungeon(
  p_player_id UUID,
  p_dungeon_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_dungeon           RECORD;
  v_player            RECORD;
  v_power             INTEGER;
  v_success_rate      NUMERIC;
  v_success           BOOLEAN;
  v_is_critical       BOOLEAN;
  v_gold              INTEGER;
  v_xp                INTEGER;
  v_hospitalized      BOOLEAN := false;
  v_hospital_until    TIMESTAMPTZ;
  v_hospital_minutes  INTEGER;
  v_is_first          BOOLEAN := false;
  v_items             JSONB := '[]'::JSONB;
  v_today_boss        INTEGER;
  v_luck_for_loot     NUMERIC;
  v_loot_luck_bonus   NUMERIC;
  v_shadow_loot_bonus NUMERIC := 0;
  v_effective_equipment_drop NUMERIC;
  v_effective_resource_drop  NUMERIC;
  v_effective_scroll_drop    NUMERIC;
  v_rarity_luck_shift NUMERIC;
  v_ratio             NUMERIC;
  v_hospital_chance   NUMERIC;
  v_defense_mitigation NUMERIC;
  v_inventory_full    BOOLEAN := false;
  v_loot_item         RECORD;
  v_loot_rarity       TEXT;
  v_rarity_roll       NUMERIC;
  v_rarity_weights    JSONB;
  v_item_added        BOOLEAN;
BEGIN
  IF p_player_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_dungeon FROM public.dungeons WHERE id = p_dungeon_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'dungeon_not_found');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;

  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('error', 'in_hospital');
  END IF;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('error', 'in_prison');
  END IF;

  IF v_player.energy < v_dungeon.energy_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_energy');
  END IF;

  INSERT INTO public.player_dungeon_stats (player_id, dungeon_id)
  VALUES (p_player_id, p_dungeon_id)
  ON CONFLICT (player_id, dungeon_id) DO NOTHING;

  UPDATE public.player_dungeon_stats
  SET today_attempts = 0, today_boss_attempts = 0, today_date = CURRENT_DATE
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id AND today_date < CURRENT_DATE;

  SELECT today_boss_attempts INTO v_today_boss
  FROM public.player_dungeon_stats
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN
    RETURN jsonb_build_object('error', 'boss_daily_limit');
  END IF;

  v_power := COALESCE(v_player.power, 0);
  IF v_power = 0 THEN
    v_power := public.calculate_user_total_power(p_player_id)::INTEGER;
    IF v_power IS NULL OR v_power = 0 THEN
      v_power := v_player.level * 500
               + floor(COALESCE(v_player.reputation, 0) * 0.1)
               + floor(COALESCE(v_player.luck, 0) * 50);
    END IF;
    UPDATE public.users SET power = v_power WHERE auth_id = p_player_id;
  END IF;

  IF v_dungeon.power_requirement = 0 THEN
    v_success_rate := 1.0;
  ELSE
    v_ratio := v_power::NUMERIC / v_dungeon.power_requirement;
    IF    v_ratio >= 1.5  THEN v_success_rate := 0.95;
    ELSIF v_ratio >= 1.0  THEN v_success_rate := 0.70 + (v_ratio - 1.0) * 0.50;
    ELSIF v_ratio >= 0.5  THEN v_success_rate := 0.25 + (v_ratio - 0.5) * 0.90;
    ELSIF v_ratio >= 0.25 THEN v_success_rate := 0.10 + (v_ratio - 0.25) * 0.60;
    ELSE                       v_success_rate := GREATEST(0.05, v_ratio * 0.40);
    END IF;

    v_success_rate := v_success_rate + LEAST(0.05, COALESCE(v_player.luck, 0) * 0.001);
    v_success_rate := v_success_rate + LEAST(0.025, COALESCE(v_player.reputation, 0) * 0.0005);
    IF COALESCE(v_player.character_class, '') = 'warrior' THEN
      v_success_rate := v_success_rate + 0.05;
    END IF;
    v_success_rate := LEAST(0.95, GREATEST(0.05, v_success_rate));
  END IF;

  v_success     := random() <= v_success_rate;
  v_is_critical := v_success AND random() <= 0.10;

  IF v_success THEN
    v_gold := v_dungeon.gold_min + floor(random() * (v_dungeon.gold_max - v_dungeon.gold_min));
    v_xp   := v_dungeon.xp_reward;

    IF v_is_critical THEN
      v_gold := floor(v_gold * 1.5);
      v_xp   := floor(v_xp   * 1.5);
    END IF;

    v_luck_for_loot := COALESCE(v_player.luck, 0);
    v_gold := floor(v_gold * (1 + v_luck_for_loot * 0.002));
    v_xp   := floor(v_xp   * (1 + COALESCE(v_player.luck, 0) * 0.001));

    -- Loot bonus: luck etkisi sınırlı, shadow için sabit ek bonus.
    -- Shadow bonusunu luck ile tekrar çarpmıyoruz, çift buff oluşmuyor.
    IF COALESCE(v_player.character_class, '') = 'shadow' THEN
      v_shadow_loot_bonus := 0.20;
    END IF;
    v_loot_luck_bonus := LEAST(0.20, v_luck_for_loot * 0.0015);
    v_effective_equipment_drop := LEAST(0.95, GREATEST(0, v_dungeon.equipment_drop_chance * (1 + v_loot_luck_bonus + v_shadow_loot_bonus)));
    v_effective_resource_drop  := LEAST(0.95, GREATEST(0, v_dungeon.resource_drop_chance  * (1 + v_loot_luck_bonus + v_shadow_loot_bonus)));
    v_effective_scroll_drop    := LEAST(0.95, GREATEST(0, v_dungeon.scroll_drop_chance    * (1 + v_loot_luck_bonus + v_shadow_loot_bonus)));

    IF COALESCE(v_player.character_class, '') = 'warrior' AND v_dungeon.is_boss THEN
      v_gold := floor(v_gold * 1.15);
    END IF;

    -- LOOT DROP LOGIC (kolon: type, is_visible kontrolü opsiyonel)
    v_rarity_weights := v_dungeon.loot_rarity_weights;
    v_rarity_luck_shift := LEAST(0.10, v_luck_for_loot * 0.0008 + CASE WHEN COALESCE(v_player.character_class, '') = 'shadow' THEN 0.05 ELSE 0 END);
    v_rarity_roll := GREATEST(0, random() - v_rarity_luck_shift);

    IF v_rarity_weights IS NOT NULL AND v_rarity_weights != '{}'::jsonb THEN
      IF v_rarity_roll < COALESCE((v_rarity_weights->>'legendary')::NUMERIC, 0) THEN
        v_loot_rarity := 'legendary';
      ELSIF v_rarity_roll < COALESCE((v_rarity_weights->>'epic')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'legendary')::NUMERIC, 0) THEN
        v_loot_rarity := 'epic';
      ELSIF v_rarity_roll < COALESCE((v_rarity_weights->>'rare')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'epic')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'legendary')::NUMERIC, 0) THEN
        v_loot_rarity := 'rare';
      ELSIF v_rarity_roll < COALESCE((v_rarity_weights->>'uncommon')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'rare')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'epic')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'legendary')::NUMERIC, 0) THEN
        v_loot_rarity := 'uncommon';
      ELSE
        v_loot_rarity := 'common';
      END IF;
    ELSE
      v_loot_rarity := 'common';
    END IF;

    -- Equipment drop
    IF random() <= v_effective_equipment_drop THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE rarity    = v_loot_rarity
        AND type      IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_item_added := public.dungeon_add_item(p_player_id, v_loot_item.id, 1);
        IF v_item_added THEN
          v_items := v_items || jsonb_build_object(
            'item_id', v_loot_item.id,
            'name',    v_loot_item.name,
            'rarity',  v_loot_rarity,
            'type',    v_loot_item.type
          );
        ELSE
          v_inventory_full := true;
        END IF;
      END IF;
    END IF;

    -- Resource drop
    IF random() <= v_effective_resource_drop THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE rarity = v_loot_rarity
        AND type   IN ('material', 'consumable')
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_item_added := public.dungeon_add_item(p_player_id, v_loot_item.id, 1);
        IF v_item_added THEN
          v_items := v_items || jsonb_build_object(
            'item_id', v_loot_item.id,
            'name',    v_loot_item.name,
            'rarity',  v_loot_rarity,
            'type',    v_loot_item.type
          );
        ELSE
          v_inventory_full := true;
        END IF;
      END IF;
    END IF;

    -- Scroll drop
    IF random() <= v_effective_scroll_drop THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE type = 'scroll'
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_item_added := public.dungeon_add_item(p_player_id, v_loot_item.id, 1);
        IF v_item_added THEN
          v_items := v_items || jsonb_build_object(
            'item_id', v_loot_item.id,
            'name',    v_loot_item.name,
            'rarity',  v_loot_rarity,
            'type',    'scroll'
          );
        ELSE
          v_inventory_full := true;
        END IF;
      END IF;
    END IF;

  ELSE
    v_gold := floor(v_dungeon.gold_min * 0.3);
    v_xp   := floor(v_dungeon.xp_reward * 0.2);

    v_hospital_chance := GREATEST(0.05, LEAST(0.90, 1.0 - v_success_rate));
    v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);
    IF random() <= v_hospital_chance THEN
      v_hospitalized     := true;
      v_hospital_minutes := v_dungeon.hospital_min_minutes
        + floor(random() * GREATEST(0, v_dungeon.hospital_max_minutes - v_dungeon.hospital_min_minutes));

      v_defense_mitigation := LEAST(0.30, COALESCE(v_player.defense, 0) * 0.001);
      v_hospital_minutes   := floor(v_hospital_minutes * (1 - v_defense_mitigation));

      IF COALESCE(v_player.character_class, '') = 'warrior' THEN
        v_hospital_minutes := floor(v_hospital_minutes * 0.80);
      END IF;

      v_hospital_until := now() + (v_hospital_minutes || ' minutes')::INTERVAL;
      UPDATE public.users SET hospital_until = v_hospital_until WHERE auth_id = p_player_id;
    END IF;

    IF v_hospitalized THEN
      v_gold  := 0;
      v_xp    := 0;
      v_items := '[]'::JSONB;
    END IF;
  END IF;

  IF v_success THEN
    SELECT (first_clear_at IS NULL) INTO v_is_first
    FROM public.player_dungeon_stats
    WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

    IF v_is_first THEN
      v_gold := v_gold + (v_dungeon.gold_max * 5);
      v_xp   := v_xp   + (v_dungeon.xp_reward * 10);
    END IF;
  END IF;

  UPDATE public.users
  SET energy = energy - v_dungeon.energy_cost,
      gold   = gold   + v_gold,
      xp     = xp     + v_xp
  WHERE auth_id = p_player_id AND energy >= v_dungeon.energy_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Yetersiz enerji veya işlem çakışması');
  END IF;

  UPDATE public.player_dungeon_stats
  SET total_attempts      = total_attempts  + 1,
      total_successes     = total_successes + CASE WHEN v_success THEN 1 ELSE 0 END,
      total_failures      = total_failures  + CASE WHEN v_success THEN 0 ELSE 1 END,
      first_clear_at      = CASE WHEN v_success AND first_clear_at IS NULL THEN now() ELSE first_clear_at END,
      today_attempts      = today_attempts  + 1,
      today_boss_attempts = today_boss_attempts + CASE WHEN v_dungeon.is_boss THEN 1 ELSE 0 END,
      today_date          = CURRENT_DATE,
      best_power_at_clear = CASE WHEN v_success AND v_power > best_power_at_clear
                                 THEN v_power ELSE best_power_at_clear END
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  INSERT INTO public.dungeon_runs (
    player_id, dungeon_id, success, is_critical,
    gold_earned, xp_earned, items_dropped,
    hospitalized, hospital_until,
    player_power, success_rate_at_run, is_first_clear
  ) VALUES (
    p_player_id, p_dungeon_id, v_success, v_is_critical,
    v_gold, v_xp, v_items,
    v_hospitalized, v_hospital_until,
    v_power, v_success_rate, v_is_first
  );

  RETURN jsonb_build_object(
    'success',         v_success,
    'is_critical',     v_is_critical,
    'gold_earned',     v_gold,
    'xp_earned',       v_xp,
    'items',           v_items,
    'items_dropped',   v_items,
    'hospitalized',    v_hospitalized,
    'hospital_until',  v_hospital_until,
    'is_first_clear',  v_is_first,
    'success_rate',    round(v_success_rate * 100, 1),
    'inventory_full',  v_inventory_full
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
