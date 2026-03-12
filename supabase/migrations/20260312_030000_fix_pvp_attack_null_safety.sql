-- =========================================================================================
-- MIGRATION: Fix pvp_attack null-safe hospital/prison checks
-- =========================================================================================

CREATE OR REPLACE FUNCTION public.pvp_attack(
  p_attacker_id UUID,
  p_defender_id UUID,
  p_mekan_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_attacker RECORD;
  v_defender RECORD;
  v_mekan RECORD;
  v_attacker_hp INT;
  v_defender_hp INT;
  v_winner_id UUID;
  v_gold_stolen BIGINT;
  v_steal_rate NUMERIC;
  v_rep_change_winner INT;
  v_rep_change_loser INT;
  v_hospital_chance NUMERIC;
  v_hospital_triggered BOOLEAN := false;
  v_hospital_minutes INT;
  v_new_rating_a INT;
  v_new_rating_d INT;
  v_expected_a NUMERIC;
  v_rating_diff INT;
  v_daily_count INT;
BEGIN
  IF p_attacker_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;

  SELECT * INTO v_attacker FROM public.users WHERE auth_id = p_attacker_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Saldiran bulunamadi');
  END IF;

  SELECT * INTO v_defender FROM public.users WHERE auth_id = p_defender_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef bulunamadi');
  END IF;

  IF p_attacker_id = p_defender_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendine saldiramazsin');
  END IF;

  IF COALESCE(v_attacker.level, 1) < 10 OR COALESCE(v_defender.level, 1) < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'PvP icin minimum level 10');
  END IF;

  IF v_attacker.energy < 15 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Enerji yetersiz (15 gerekli)');
  END IF;

  -- NULL-safe status checks
  IF ((v_attacker.hospital_until IS NOT NULL AND v_attacker.hospital_until > now())
      OR (v_attacker.prison_until IS NOT NULL AND v_attacker.prison_until > now())) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastanede/hapiste PvP yapilamaz');
  END IF;
  IF ((v_defender.hospital_until IS NOT NULL AND v_defender.hospital_until > now())
      OR (v_defender.prison_until IS NOT NULL AND v_defender.prison_until > now())) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakip musait degil');
  END IF;

  IF v_attacker.guild_id IS NOT NULL AND v_attacker.guild_id = v_defender.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ayni lonca uyesine saldirilamaz');
  END IF;

  SELECT COALESCE(attack_count, 0) INTO v_daily_count
  FROM public.pvp_daily_attacks
  WHERE attacker_id = p_attacker_id AND defender_id = p_defender_id AND attack_date = CURRENT_DATE;
  IF v_daily_count >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu oyuncuya bugun 3 kez saldirdiniz');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND OR v_mekan.mekan_type NOT IN ('dovus_kulubu', 'luks_lounge', 'yeralti') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu mekanda PvP yapilamaz');
  END IF;

  IF ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > 300 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rating farki cok yuksek (max ±300)');
  END IF;

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

      v_atk_dmg := COALESCE(v_attacker.attack, 10) * (0.8 + random() * 0.4)
                   * CASE WHEN v_atk_crit THEN 1.5 ELSE 1.0 END
                   - COALESCE(v_defender.defense, 10) * 0.3;
      v_def_dmg := COALESCE(v_defender.attack, 10) * (0.8 + random() * 0.4)
                   * CASE WHEN v_def_crit THEN 1.5 ELSE 1.0 END
                   - COALESCE(v_attacker.defense, 10) * 0.3;

      v_atk_dmg := GREATEST(v_atk_dmg, 1);
      v_def_dmg := GREATEST(v_def_dmg, 1);

      v_defender_hp := v_defender_hp - v_atk_dmg::int;
      v_attacker_hp := v_attacker_hp - v_def_dmg::int;
    END;
  END LOOP;

  IF v_attacker_hp > v_defender_hp THEN
    v_winner_id := p_attacker_id;
  ELSIF v_defender_hp > v_attacker_hp THEN
    v_winner_id := p_defender_id;
  ELSE
    v_winner_id := CASE WHEN COALESCE(v_attacker.power, 0) >= COALESCE(v_defender.power, 0) THEN p_attacker_id ELSE p_defender_id END;
  END IF;

  UPDATE public.users SET energy = energy - 15 WHERE auth_id = p_attacker_id AND energy >= 15;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda enerji yetersiz kaldi');
  END IF;

  v_rating_diff := COALESCE(v_defender.pvp_rating, 1000) - COALESCE(v_attacker.pvp_rating, 1000);
  v_expected_a := 1.0 / (1.0 + power(10.0, v_rating_diff::numeric / 400.0));

  IF v_winner_id = p_attacker_id THEN
    v_new_rating_a := COALESCE(v_attacker.pvp_rating, 1000) + (32 * (1.0 - v_expected_a))::int;
    v_new_rating_d := COALESCE(v_defender.pvp_rating, 1000) + (32 * (0.0 - (1.0 - v_expected_a)))::int;
  ELSE
    v_new_rating_a := COALESCE(v_attacker.pvp_rating, 1000) + (32 * (0.0 - v_expected_a))::int;
    v_new_rating_d := COALESCE(v_defender.pvp_rating, 1000) + (32 * (1.0 - (1.0 - v_expected_a)))::int;
  END IF;

  v_new_rating_a := GREATEST(v_new_rating_a, 0);
  v_new_rating_d := GREATEST(v_new_rating_d, 0);

  v_rating_diff := COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000);

  IF v_winner_id = p_attacker_id THEN
    v_steal_rate := CASE
      WHEN v_rating_diff > 200  THEN 0.01
      WHEN v_rating_diff > 0    THEN 0.02
      WHEN v_rating_diff > -200 THEN 0.03
      ELSE 0.05
    END;
    v_gold_stolen := GREATEST(LEAST((v_defender.gold * v_steal_rate)::bigint, 5000000::bigint), 10000::bigint);
  ELSE
    v_gold_stolen := 0;
  END IF;

  UPDATE public.users
  SET gold = gold + CASE WHEN v_winner_id = p_attacker_id THEN v_gold_stolen ELSE 0 END,
      pvp_rating = v_new_rating_a,
      pvp_wins = pvp_wins + CASE WHEN v_winner_id = p_attacker_id THEN 1 ELSE 0 END,
      pvp_losses = pvp_losses + CASE WHEN v_winner_id = p_defender_id THEN 1 ELSE 0 END
  WHERE auth_id = p_attacker_id;

  UPDATE public.users
  SET gold = gold - CASE WHEN v_winner_id = p_attacker_id THEN v_gold_stolen ELSE 0 END,
      pvp_rating = v_new_rating_d,
      pvp_wins = pvp_wins + CASE WHEN v_winner_id = p_defender_id THEN 1 ELSE 0 END,
      pvp_losses = pvp_losses + CASE WHEN v_winner_id = p_attacker_id THEN 1 ELSE 0 END
  WHERE auth_id = p_defender_id;

  v_rep_change_winner := CASE
    WHEN v_winner_id = p_attacker_id THEN 3
    ELSE 2
  END;
  v_rep_change_loser := -2;

  IF v_winner_id = p_attacker_id THEN
    UPDATE public.users SET reputation = reputation + v_rep_change_winner WHERE auth_id = p_attacker_id;
    UPDATE public.users SET reputation = reputation + v_rep_change_loser WHERE auth_id = p_defender_id;
  ELSE
    UPDATE public.users SET reputation = reputation + 2 WHERE auth_id = p_defender_id;
    UPDATE public.users SET reputation = reputation - 2 WHERE auth_id = p_attacker_id;
  END IF;

  v_hospital_chance := CASE
    WHEN v_winner_id = p_attacker_id THEN 0.05
    ELSE 0.25
  END;

  IF random() < v_hospital_chance THEN
    v_hospital_triggered := true;
    v_hospital_minutes := floor(30 + random() * 120)::int;

    IF v_winner_id = p_attacker_id THEN
      UPDATE public.users SET hospital_until = now() + (v_hospital_minutes || ' minutes')::interval WHERE auth_id = p_defender_id;
    ELSE
      UPDATE public.users SET hospital_until = now() + (v_hospital_minutes || ' minutes')::interval WHERE auth_id = p_attacker_id;
    END IF;
  END IF;

  INSERT INTO public.pvp_matches (
    mekan_id, attacker_id, defender_id, winner_id,
    attacker_hp_remaining, defender_hp_remaining,
    gold_stolen, rep_change_winner, rep_change_loser,
    rating_change_attacker, is_critical_success
  ) VALUES (
    p_mekan_id, p_attacker_id, p_defender_id, v_winner_id,
    GREATEST(v_attacker_hp, 0), GREATEST(v_defender_hp, 0),
    v_gold_stolen, v_rep_change_winner, v_rep_change_loser,
    v_new_rating_a - COALESCE(v_attacker.pvp_rating, 1000),
    random() < 0.10
  );

  INSERT INTO public.pvp_daily_attacks(attacker_id, defender_id, attack_date, attack_count)
  VALUES (p_attacker_id, p_defender_id, CURRENT_DATE, 1)
  ON CONFLICT (attacker_id, defender_id, attack_date)
  DO UPDATE SET attack_count = public.pvp_daily_attacks.attack_count + 1;

  RETURN jsonb_build_object(
    'success', true,
    'winner_id', v_winner_id,
    'gold_stolen', v_gold_stolen,
    'rep_change_winner', v_rep_change_winner,
    'rep_change_loser', v_rep_change_loser,
    'rating_change_attacker', (v_new_rating_a - COALESCE(v_attacker.pvp_rating, 1000)),
    'hospital_triggered', v_hospital_triggered
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.pvp_attack(UUID, UUID, UUID) TO authenticated;
