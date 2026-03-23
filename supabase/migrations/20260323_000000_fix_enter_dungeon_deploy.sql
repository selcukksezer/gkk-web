-- =============================================================================
-- FIX: enter_dungeon fonksiyonu veritabanında bulunamadığı için 404 hatası veriyor.
-- Bu migration fonksiyonu yeniden oluşturur ve inventory insert kolonunu düzeltir
-- (player_id → user_id).
-- Supabase Dashboard > SQL Editor'dan çalıştırın.
-- =============================================================================

DROP FUNCTION IF EXISTS public.enter_dungeon(UUID, TEXT);
DROP FUNCTION IF EXISTS public.enter_dungeon(TEXT, UUID);
DROP FUNCTION IF EXISTS public.enter_dungeon(TEXT);

CREATE OR REPLACE FUNCTION public.enter_dungeon(
  p_dungeon_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_player_id UUID;
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
  v_today_boss INTEGER;
  v_luck_for_loot NUMERIC;
  v_ratio NUMERIC;
  v_hospital_chance NUMERIC;
  v_defense_mitigation NUMERIC;
  -- Loot variables
  v_loot_item RECORD;
  v_loot_rarity TEXT;
  v_rarity_roll NUMERIC;
  v_rarity_weights JSONB;
  v_row_id UUID;
  v_slot_position INTEGER;
  v_monument_level INT := 0;
  v_blueprint_chance NUMERIC;
  v_bp_type TEXT;
BEGIN
  v_player_id := auth.uid();
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  -- Serialize dungeon runs per user in this transaction to avoid concurrent slot collisions.
  PERFORM pg_advisory_xact_lock(hashtext(v_player_id::text));

  -- Get dungeon
  SELECT * INTO v_dungeon FROM public.dungeons WHERE id = p_dungeon_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'dungeon_not_found');
  END IF;

  -- Get player (use auth_id)
  SELECT * INTO v_player FROM public.users WHERE auth_id = v_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;

  -- Monument level (if in guild)
  IF v_player.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_player.guild_id;
  END IF;

  -- Normalize stale data: equipped items must not occupy bag slot positions.
  UPDATE public.inventory
  SET slot_position = NULL,
      updated_at = now()
  WHERE user_id = v_player_id
    AND is_equipped = true
    AND slot_position IS NOT NULL;

  -- Hospital check (NULL-safe)
  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('error', 'in_hospital');
  END IF;

  -- Prison check (NULL-safe)
  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('error', 'in_prison');
  END IF;

  -- Energy check
  IF v_player.energy < v_dungeon.energy_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_energy');
  END IF;

  -- Get/create daily stats
  INSERT INTO public.player_dungeon_stats (player_id, dungeon_id)
  VALUES (v_player_id, p_dungeon_id)
  ON CONFLICT (player_id, dungeon_id) DO NOTHING;

  -- Reset daily counters if new day
  UPDATE public.player_dungeon_stats
  SET today_attempts = 0, today_boss_attempts = 0, today_date = CURRENT_DATE
  WHERE player_id = v_player_id AND dungeon_id = p_dungeon_id AND today_date < CURRENT_DATE;

  SELECT today_boss_attempts INTO v_today_boss
  FROM public.player_dungeon_stats
  WHERE player_id = v_player_id AND dungeon_id = p_dungeon_id;

  -- Boss daily limit check
  IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN
    RETURN jsonb_build_object('error', 'boss_daily_limit');
  END IF;

  -- Calculate total power
  v_power := COALESCE(v_player.power, 0);
  IF v_power = 0 THEN
    v_power := v_player.level * 500
             + floor(COALESCE(v_player.reputation, 0) * 0.1)
             + floor(COALESCE(v_player.luck, 0) * 50);
  END IF;

  -- Calculate success rate
  IF v_dungeon.power_requirement = 0 THEN
    v_success_rate := 1.0;
  ELSE
    v_ratio := v_power::NUMERIC / v_dungeon.power_requirement;
    IF v_ratio >= 1.5 THEN v_success_rate := 0.95;
    ELSIF v_ratio >= 1.0 THEN v_success_rate := 0.70 + (v_ratio - 1.0) * 0.50;
    ELSIF v_ratio >= 0.5 THEN v_success_rate := 0.25 + (v_ratio - 0.5) * 0.90;
    ELSIF v_ratio >= 0.25 THEN v_success_rate := 0.10 + (v_ratio - 0.25) * 0.60;
    ELSE v_success_rate := GREATEST(0.05, v_ratio * 0.40);
    END IF;
  END IF;

  -- Apply luck bonus
  v_success_rate := v_success_rate + COALESCE(v_player.luck, 0) * 0.001;

  -- Warrior class dungeon success bonus
  IF COALESCE(v_player.character_class, '') = 'warrior' THEN
    v_success_rate := v_success_rate + 0.05;
  END IF;

  -- Monument Lv 55: Boss combat +5%
  IF v_dungeon.is_boss AND v_monument_level >= 55 THEN
    v_success_rate := v_success_rate + 0.05;
  END IF;

  v_success_rate := LEAST(0.95, v_success_rate);

  -- Roll for success
  v_success := random() <= v_success_rate;
  v_is_critical := v_success AND random() <= 0.10;

  -- Calculate rewards
  IF v_success THEN
    v_gold := v_dungeon.gold_min + floor(random() * (v_dungeon.gold_max - v_dungeon.gold_min));
    v_xp := v_dungeon.xp_reward;
    IF v_is_critical THEN
      v_gold := floor(v_gold * 1.5);
      v_xp := floor(v_xp * 1.5);
    END IF;

    -- Loot luck
    v_luck_for_loot := COALESCE(v_player.luck, 0);
    IF COALESCE(v_player.character_class, '') = 'shadow' THEN
      v_luck_for_loot := v_luck_for_loot * 1.40;
    END IF;

    -- Monument Lv 30: +10 loot luck
    IF v_monument_level >= 30 THEN
      v_luck_for_loot := v_luck_for_loot + 10;
    END IF;

    v_gold := floor(v_gold * (1 + v_luck_for_loot * 0.002));
    v_xp   := floor(v_xp   * (1 + COALESCE(v_player.luck, 0) * 0.001));

    -- Warrior boss gold bonus
    IF COALESCE(v_player.character_class, '') = 'warrior' AND v_dungeon.is_boss THEN
      v_gold := floor(v_gold * 1.15);
    END IF;

    -- ── LOOT DROP LOGIC ─────────────────────────────────────────────────────
    v_rarity_weights := v_dungeon.loot_rarity_weights;
    v_rarity_roll := random();

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
    IF random() <= v_dungeon.equipment_drop_chance THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE rarity = v_loot_rarity
        AND type IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        SELECT s.slot INTO v_slot_position
        FROM generate_series(0, 19) AS s(slot)
        WHERE NOT EXISTS (
          SELECT 1
          FROM public.inventory inv
          WHERE inv.user_id = v_player_id
            AND inv.slot_position = s.slot
        )
        ORDER BY s.slot
        LIMIT 1;

        IF v_slot_position IS NOT NULL THEN
          v_row_id := gen_random_uuid();
          -- inventory uses user_id (references auth.users), v_player_id = auth.uid()
          BEGIN
            INSERT INTO public.inventory (
              row_id,
              user_id,
              item_id,
              quantity,
              slot_position,
              is_equipped,
              enhancement_level
            )
            VALUES (v_row_id, v_player_id, v_loot_item.id, 1, v_slot_position, false, 0)
            ON CONFLICT DO NOTHING
            RETURNING row_id INTO v_row_id;
          EXCEPTION
            WHEN unique_violation THEN
              v_row_id := NULL;
          END;

          IF FOUND THEN
            v_items := v_items || jsonb_build_object(
              'row_id', v_row_id,
              'item_id', v_loot_item.id,
              'name', v_loot_item.name,
              'rarity', v_loot_rarity,
              'type', v_loot_item.type
            );
          END IF;
        END IF;
      END IF;
    END IF;

    -- Resource drop
    IF random() <= v_dungeon.resource_drop_chance THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE rarity = v_loot_rarity
        AND type IN ('material', 'consumable', 'resource')
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        SELECT s.slot INTO v_slot_position
        FROM generate_series(0, 19) AS s(slot)
        WHERE NOT EXISTS (
          SELECT 1
          FROM public.inventory inv
          WHERE inv.user_id = v_player_id
            AND inv.slot_position = s.slot
        )
        ORDER BY s.slot
        LIMIT 1;

        IF v_slot_position IS NOT NULL THEN
          v_row_id := gen_random_uuid();
          BEGIN
            INSERT INTO public.inventory (
              row_id,
              user_id,
              item_id,
              quantity,
              slot_position,
              is_equipped,
              enhancement_level
            )
            VALUES (v_row_id, v_player_id, v_loot_item.id, 1, v_slot_position, false, 0)
            ON CONFLICT DO NOTHING
            RETURNING row_id INTO v_row_id;
          EXCEPTION
            WHEN unique_violation THEN
              v_row_id := NULL;
          END;

          IF FOUND THEN
            v_items := v_items || jsonb_build_object(
              'row_id', v_row_id,
              'item_id', v_loot_item.id,
              'name', v_loot_item.name,
              'rarity', v_loot_rarity,
              'type', v_loot_item.type
            );
          END IF;
        END IF;
      END IF;
    END IF;

    -- Scroll drop
    IF random() <= v_dungeon.scroll_drop_chance THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE type = 'scroll'
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        SELECT s.slot INTO v_slot_position
        FROM generate_series(0, 19) AS s(slot)
        WHERE NOT EXISTS (
          SELECT 1
          FROM public.inventory inv
          WHERE inv.user_id = v_player_id
            AND inv.slot_position = s.slot
        )
        ORDER BY s.slot
        LIMIT 1;

        IF v_slot_position IS NOT NULL THEN
          v_row_id := gen_random_uuid();
          BEGIN
            INSERT INTO public.inventory (
              row_id,
              user_id,
              item_id,
              quantity,
              slot_position,
              is_equipped,
              enhancement_level
            )
            VALUES (v_row_id, v_player_id, v_loot_item.id, 1, v_slot_position, false, 0)
            ON CONFLICT DO NOTHING
            RETURNING row_id INTO v_row_id;
          EXCEPTION
            WHEN unique_violation THEN
              v_row_id := NULL;
          END;

          IF FOUND THEN
            v_items := v_items || jsonb_build_object(
              'row_id', v_row_id,
              'item_id', v_loot_item.id,
              'name', v_loot_item.name,
              'rarity', v_loot_rarity,
              'type', 'scroll'
            );
          END IF;
        END IF;
      END IF;
    END IF;

    -- Boss blueprint drop (Zone 5-7, guild members)
    IF v_dungeon.is_boss AND v_dungeon.zone >= 5 AND v_player.guild_id IS NOT NULL THEN
      v_blueprint_chance := 0.005 + (v_dungeon.zone - 5) * 0.02;
      IF random() <= v_blueprint_chance THEN
        v_bp_type := CASE
          WHEN v_dungeon.zone = 5 THEN 'titan'
          WHEN v_dungeon.zone = 6 THEN 'world_eater'
          ELSE 'eternal'
        END;
        INSERT INTO public.guild_blueprints (guild_id, blueprint_type, fragments)
        VALUES (v_player.guild_id, v_bp_type, 1)
        ON CONFLICT (guild_id, blueprint_type) DO UPDATE
          SET fragments = public.guild_blueprints.fragments + 1;
      END IF;
    END IF;
    -- ── END LOOT LOGIC ──────────────────────────────────────────────────────

  ELSE
    v_gold := 0;
    v_xp := 0;

    -- Hospital check on failure
    v_hospital_chance := GREATEST(0.05, LEAST(0.90, 1.0 - v_success_rate));
    v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);
    IF random() <= v_hospital_chance THEN
      v_hospitalized := true;
      v_hospital_minutes := v_dungeon.hospital_min_minutes
        + floor(random() * GREATEST(0, v_dungeon.hospital_max_minutes - v_dungeon.hospital_min_minutes));

      -- Defense-based mitigation: max 30%
      v_defense_mitigation := LEAST(0.30, COALESCE(v_player.defense, 0) * 0.001);
      v_hospital_minutes := floor(v_hospital_minutes * (1 - v_defense_mitigation));

      -- Warrior class: -20% hospital duration
      IF COALESCE(v_player.character_class, '') = 'warrior' THEN
        v_hospital_minutes := floor(v_hospital_minutes * 0.80);
      END IF;

      -- Monument Lv 60: -10% hospital duration
      IF v_monument_level >= 60 THEN
        v_hospital_minutes := floor(v_hospital_minutes * 0.90);
      END IF;

      v_hospital_until := now() + (v_hospital_minutes || ' minutes')::INTERVAL;
      UPDATE public.users
      SET hospital_until = v_hospital_until,
          in_hospital = true
      WHERE auth_id = v_player_id;
    END IF;
  END IF;

  -- First clear check
  IF v_success THEN
    SELECT (first_clear_at IS NULL) INTO v_is_first
    FROM public.player_dungeon_stats
    WHERE player_id = v_player_id AND dungeon_id = p_dungeon_id;

    IF v_is_first THEN
      v_gold := v_gold + (v_dungeon.gold_max * 5);
      v_xp := v_xp + (v_dungeon.xp_reward * 10);
    END IF;
  END IF;

  -- Update player (energy, gold, xp)
  UPDATE public.users SET
    energy = energy - v_dungeon.energy_cost,
    gold = gold + v_gold,
    xp = xp + v_xp
  WHERE auth_id = v_player_id AND energy >= v_dungeon.energy_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Yetersiz enerji veya işlem çakışması');
  END IF;

  -- Update dungeon stats
  UPDATE public.player_dungeon_stats SET
    total_attempts = total_attempts + 1,
    total_successes = total_successes + CASE WHEN v_success THEN 1 ELSE 0 END,
    total_failures = total_failures + CASE WHEN v_success THEN 0 ELSE 1 END,
    first_clear_at = CASE WHEN v_success AND first_clear_at IS NULL THEN now() ELSE first_clear_at END,
    today_attempts = today_attempts + 1,
    today_boss_attempts = today_boss_attempts + CASE WHEN v_dungeon.is_boss THEN 1 ELSE 0 END,
    today_date = CURRENT_DATE,
    best_power_at_clear = CASE WHEN v_success AND v_power > best_power_at_clear THEN v_power ELSE best_power_at_clear END
  WHERE player_id = v_player_id AND dungeon_id = p_dungeon_id;

  -- Insert run record
  INSERT INTO public.dungeon_runs (
    player_id, dungeon_id, success, is_critical,
    gold_earned, xp_earned, items_dropped,
    hospitalized, hospital_until,
    player_power, success_rate_at_run, is_first_clear
  ) VALUES (
    v_player_id, p_dungeon_id, v_success, v_is_critical,
    v_gold, v_xp, v_items,
    v_hospitalized, v_hospital_until,
    v_power, v_success_rate, v_is_first
  );

  RETURN jsonb_build_object(
    'success', v_success,
    'is_critical', v_is_critical,
    'gold_earned', v_gold,
    'xp_earned', v_xp,
    'items', v_items,
    'items_dropped', v_items,
    'hospitalized', v_hospitalized,
    'hospital_until', v_hospital_until,
    'is_first_clear', v_is_first,
    'success_rate', round(v_success_rate * 100, 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Wrapper overload: keep backward compatibility for calls that pass player_id explicitly
CREATE OR REPLACE FUNCTION public.enter_dungeon(
  p_player_id UUID,
  p_dungeon_id TEXT
) RETURNS JSONB AS $$
BEGIN
  IF p_player_id IS NULL OR p_player_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;
  RETURN public.enter_dungeon(p_dungeon_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.enter_dungeon(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enter_dungeon(UUID, TEXT) TO authenticated;
