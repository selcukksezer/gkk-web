-- =========================================================================================
-- MIGRATION: Fix Hospital Chance (dng_001 = 0%, dng_002+ = Dynamic)
-- =========================================================================================
-- Kural:
-- PLAN_04 per spec: Hastane riski %0 (SADECE #1/dng_001), başarı oranına ters orantılı (#2+)
-- Bug: Code tüm zindanlara 1.0 - success_rate ile hesaplıyordu
-- Fix: dng_001 (v_zone_number = 1) için hospital_chance = 0%, dng_002+ (v_zone_number >= 2) dynamic
-- =========================================================================================

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
  v_ratio             NUMERIC;
  v_hospital_chance   NUMERIC;
  v_defense_mitigation NUMERIC;
  v_zone_number       INTEGER;
  -- Loot variables
  v_loot_item         RECORD;
  v_loot_rarity       TEXT;
  v_rarity_roll       NUMERIC;
  v_rarity_weights    JSONB;
  v_row_id            UUID;
BEGIN
  -- Auth guard
  IF p_player_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  -- Get dungeon
  SELECT * INTO v_dungeon FROM public.dungeons WHERE id = p_dungeon_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'dungeon_not_found');
  END IF;

  -- Get player
  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;

  -- Hospital check
  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('error', 'in_hospital');
  END IF;

  -- Prison check
  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('error', 'in_prison');
  END IF;

  -- Energy check
  IF v_player.energy < v_dungeon.energy_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_energy');
  END IF;

  -- Daily stats upsert
  INSERT INTO public.player_dungeon_stats (player_id, dungeon_id)
  VALUES (p_player_id, p_dungeon_id)
  ON CONFLICT (player_id, dungeon_id) DO NOTHING;

  -- Reset daily counters if new day
  UPDATE public.player_dungeon_stats
  SET today_attempts = 0, today_boss_attempts = 0, today_date = CURRENT_DATE
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id AND today_date < CURRENT_DATE;

  SELECT today_boss_attempts INTO v_today_boss
  FROM public.player_dungeon_stats
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  -- Boss daily limit check
  IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN
    RETURN jsonb_build_object('error', 'boss_daily_limit');
  END IF;

  -- ── Dungeon Zone Belirle (Hospital Risk Hesabı İçin) ────────────────────────────
  -- dng_001: zone_number = 1 (dng_001 = %0 hospital)
  -- dng_002-dng_009: zone_number = 2-9 (dynamic hospital)
  -- dng_010-dng_019: zone_number = 10-19 (dynamic hospital)
  -- dng_020+: zone_number = 20+ (dynamic hospital)
  v_zone_number := CAST(SUBSTRING(p_dungeon_id FROM 5) AS INTEGER);

  -- ── Güç Hesabı (FIX #1) ────────────────────────────────────────────────────────────
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

  -- ── Başarı Oranı Hesabı (FIX #2 & #3) ────────────────────────────────────────────
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

    -- Luck bonusu: max +5%
    v_success_rate := v_success_rate + LEAST(0.05, COALESCE(v_player.luck, 0) * 0.001);

    -- Reputation bonusu: max +2.5%
    v_success_rate := v_success_rate + LEAST(0.025, COALESCE(v_player.reputation, 0) * 0.0005);

    -- Savaşçı sınıfı zindan bonusu: +5%
    IF COALESCE(v_player.character_class, '') = 'warrior' THEN
      v_success_rate := v_success_rate + 0.05;
    END IF;

    -- Clamp: min %5, max %95
    v_success_rate := LEAST(0.95, GREATEST(0.05, v_success_rate));
  END IF;

  -- Zar at
  v_success     := random() <= v_success_rate;
  v_is_critical := v_success AND random() <= 0.10;

  -- ── Ödüller ──────────────────────────────────────────────────────────────────────
  IF v_success THEN
    v_gold := v_dungeon.gold_min + floor(random() * (v_dungeon.gold_max - v_dungeon.gold_min));
    v_xp   := v_dungeon.xp_reward;

    IF v_is_critical THEN
      v_gold := floor(v_gold * 1.5);
      v_xp   := floor(v_xp   * 1.5);
    END IF;

    -- Luck-based loot bonus (PLAN_11)
    v_luck_for_loot := COALESCE(v_player.luck, 0);
    IF COALESCE(v_player.character_class, '') = 'shadow' THEN
      v_luck_for_loot := v_luck_for_loot * 1.40;
    END IF;
    v_gold := floor(v_gold * (1 + v_luck_for_loot * 0.002));
    v_xp   := floor(v_xp   * (1 + COALESCE(v_player.luck, 0) * 0.001));

    -- Savaşçı boss gold bonusu: +15%
    IF COALESCE(v_player.character_class, '') = 'warrior' AND v_dungeon.is_boss THEN
      v_gold := floor(v_gold * 1.15);
    END IF;

    -- ── LOOT DROP LOGIC ──────────────────────────────────────────────────────────
    v_rarity_weights := v_dungeon.loot_rarity_weights;
    v_rarity_roll    := random();

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
        AND is_visible = true
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_row_id := gen_random_uuid();
        INSERT INTO public.inventory (row_id, player_id, item_id, quantity, is_equipped, enhancement_level)
        VALUES (v_row_id, p_player_id, v_loot_item.id, 1, false, 0)
        ON CONFLICT DO NOTHING;
        v_items := v_items || jsonb_build_object(
          'row_id', v_row_id, 'item_id', v_loot_item.id,
          'name', v_loot_item.name, 'rarity', v_loot_rarity, 'type', v_loot_item.type
        );
      END IF;
    END IF;

    -- Resource drop
    IF random() <= v_dungeon.resource_drop_chance THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE rarity = v_loot_rarity
        AND type IN ('material', 'consumable')
        AND is_visible = true
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_row_id := gen_random_uuid();
        INSERT INTO public.inventory (row_id, player_id, item_id, quantity, is_equipped, enhancement_level)
        VALUES (v_row_id, p_player_id, v_loot_item.id, 1, false, 0)
        ON CONFLICT DO NOTHING;
        v_items := v_items || jsonb_build_object(
          'row_id', v_row_id, 'item_id', v_loot_item.id,
          'name', v_loot_item.name, 'rarity', v_loot_rarity, 'type', v_loot_item.type
        );
      END IF;
    END IF;

    -- Scroll drop
    IF random() <= v_dungeon.scroll_drop_chance THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE type = 'scroll' AND is_visible = true
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_row_id := gen_random_uuid();
        INSERT INTO public.inventory (row_id, player_id, item_id, quantity, is_equipped, enhancement_level)
        VALUES (v_row_id, p_player_id, v_loot_item.id, 1, false, 0)
        ON CONFLICT DO NOTHING;
        v_items := v_items || jsonb_build_object(
          'row_id', v_row_id, 'item_id', v_loot_item.id,
          'name', v_loot_item.name, 'rarity', v_loot_rarity, 'type', 'scroll'
        );
      END IF;
    END IF;
    -- ── END LOOT LOGIC ───────────────────────────────────────────────────────────

  ELSE
    -- Başarısız: teselli ödülleri
    v_gold := floor(v_dungeon.gold_min * 0.3);
    v_xp   := floor(v_dungeon.xp_reward * 0.2);

    -- ════════════════════════════════════════════════════════════════════════════════
    -- HASTANE RİSKİ (PLAN_04'e göre):
    -- dng_001 (v_zone_number = 1): %0 risk (başlangıç koruması)
    -- dng_002+ (v_zone_number >= 2): başarı oranına ters orantılı
    -- ════════════════════════════════════════════════════════════════════════════════
    IF v_zone_number = 1 THEN
      -- dng_001: Hiç hastane riski yok
      v_hospital_chance := 0.0;
    ELSE
      -- dng_002+: başarı oranına ters orantılı, max %90, min %5
      v_hospital_chance := GREATEST(0.05, LEAST(0.90, 1.0 - v_success_rate));
      -- Luck mitigasyonu: max -%30 (luck * 0.003)
      v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);
    END IF;

    IF random() <= v_hospital_chance THEN
      v_hospitalized     := true;
      v_hospital_minutes := v_dungeon.hospital_min_minutes
        + floor(random() * GREATEST(0, v_dungeon.hospital_max_minutes - v_dungeon.hospital_min_minutes));

      -- Defense mitigasyonu: max %30
      v_defense_mitigation := LEAST(0.30, COALESCE(v_player.defense, 0) * 0.001);
      v_hospital_minutes   := floor(v_hospital_minutes * (1 - v_defense_mitigation));

      -- Savaşçı: ek -%20 hastane süresi
      IF COALESCE(v_player.character_class, '') = 'warrior' THEN
        v_hospital_minutes := floor(v_hospital_minutes * 0.80);
      END IF;

      v_hospital_until := now() + (v_hospital_minutes || ' minutes')::INTERVAL;
      UPDATE public.users SET hospital_until = v_hospital_until WHERE auth_id = p_player_id;
    END IF;

    -- Yeni kural: Hastaneye düşen oyuncu hiçbir ödül alamaz
    IF v_hospitalized THEN
      v_gold := 0;
      v_xp := 0;
      v_items := '[]'::JSONB;
    END IF;
  END IF;

  -- First clear bonusu
  IF v_success THEN
    SELECT (first_clear_at IS NULL) INTO v_is_first
    FROM public.player_dungeon_stats
    WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

    IF v_is_first THEN
      v_gold := v_gold + (v_dungeon.gold_max * 5);
      v_xp   := v_xp   + (v_dungeon.xp_reward * 10);
    END IF;
  END IF;

  -- Oyuncu güncelle (enerji, altın, XP)
  UPDATE public.users
  SET energy = energy - v_dungeon.energy_cost,
      gold   = gold   + v_gold,
      xp     = xp     + v_xp
  WHERE auth_id = p_player_id AND energy >= v_dungeon.energy_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Yetersiz enerji veya işlem çakışması');
  END IF;

  -- Zindan istatistikleri güncelle
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

  -- Koşu kaydı ekle
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
    'success',       v_success,
    'is_critical',   v_is_critical,
    'gold_earned',   v_gold,
    'xp_earned',     v_xp,
    'items',         v_items,
    'items_dropped', v_items,
    'hospitalized',  v_hospitalized,
    'hospital_until', v_hospital_until,
    'is_first_clear', v_is_first,
    'success_rate',  round(v_success_rate * 100, 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.enter_dungeon(UUID, TEXT) TO authenticated;
