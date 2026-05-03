-- =========================================================================================
-- MIGRATION: Apply PLAN_11 PvP Class Bonuses
-- =========================================================================================
-- Restores and completes PvP class mechanics in public.pvp_attack:
-- - Warrior: +20% PvP damage, +10% crit chance
-- - Shadow: +15% dodge chance
-- - Luck: crit and dodge scaling in PvP
-- - Warrior Bloodlust: 30m window, +10% damage, +20% at 3-win streak
-- =========================================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS warrior_bloodlust_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS warrior_bloodlust_streak SMALLINT NOT NULL DEFAULT 0;

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

  v_attacker_is_warrior BOOLEAN;
  v_defender_is_warrior BOOLEAN;
  v_attacker_is_shadow BOOLEAN;
  v_defender_is_shadow BOOLEAN;

  v_attacker_bloodlust_active BOOLEAN := false;
  v_defender_bloodlust_active BOOLEAN := false;
  v_attacker_bloodlust_mult NUMERIC := 1.0;
  v_defender_bloodlust_mult NUMERIC := 1.0;
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
    RETURN jsonb_build_object('success', false, 'error', 'Rating farki cok yuksek (max +-300)');
  END IF;

  v_attacker_is_warrior := COALESCE(v_attacker.character_class, '') = 'warrior';
  v_defender_is_warrior := COALESCE(v_defender.character_class, '') = 'warrior';
  v_attacker_is_shadow := COALESCE(v_attacker.character_class, '') = 'shadow';
  v_defender_is_shadow := COALESCE(v_defender.character_class, '') = 'shadow';

  v_attacker_bloodlust_active := v_attacker_is_warrior
    AND v_attacker.warrior_bloodlust_until IS NOT NULL
    AND v_attacker.warrior_bloodlust_until > now();

  v_defender_bloodlust_active := v_defender_is_warrior
    AND v_defender.warrior_bloodlust_until IS NOT NULL
    AND v_defender.warrior_bloodlust_until > now();

  IF v_attacker_bloodlust_active THEN
    v_attacker_bloodlust_mult := CASE
      WHEN COALESCE(v_attacker.warrior_bloodlust_streak, 0) >= 3 THEN 1.20
      ELSE 1.10
    END;
  END IF;

  IF v_defender_bloodlust_active THEN
    v_defender_bloodlust_mult := CASE
      WHEN COALESCE(v_defender.warrior_bloodlust_streak, 0) >= 3 THEN 1.20
      ELSE 1.10
    END;
  END IF;

  v_attacker_hp := COALESCE(v_attacker.health, 100);
  v_defender_hp := COALESCE(v_defender.health, 100);

  FOR i IN 1..3 LOOP
    DECLARE
      v_atk_dmg NUMERIC;
      v_def_dmg NUMERIC;
      v_atk_crit BOOLEAN;
      v_def_crit BOOLEAN;
      v_atk_dodge BOOLEAN;
      v_def_dodge BOOLEAN;
      v_atk_crit_chance NUMERIC;
      v_def_crit_chance NUMERIC;
      v_atk_dodge_chance NUMERIC;
      v_def_dodge_chance NUMERIC;
      v_atk_class_damage_mult NUMERIC;
      v_def_class_damage_mult NUMERIC;
    BEGIN
      v_atk_crit_chance := LEAST(0.95, GREATEST(0.0,
        COALESCE(v_attacker.luck, 0) * 0.002
        + CASE WHEN v_attacker_is_warrior THEN 0.10 ELSE 0.0 END
      ));

      v_def_crit_chance := LEAST(0.95, GREATEST(0.0,
        COALESCE(v_defender.luck, 0) * 0.002
        + CASE WHEN v_defender_is_warrior THEN 0.10 ELSE 0.0 END
      ));

      v_atk_dodge_chance := LEAST(0.80, GREATEST(0.0,
        COALESCE(v_attacker.luck, 0) * 0.001
        + CASE WHEN v_attacker_is_shadow THEN 0.15 ELSE 0.0 END
      ));

      v_def_dodge_chance := LEAST(0.80, GREATEST(0.0,
        COALESCE(v_defender.luck, 0) * 0.001
        + CASE WHEN v_defender_is_shadow THEN 0.15 ELSE 0.0 END
      ));

      v_atk_crit := random() < v_atk_crit_chance;
      v_def_crit := random() < v_def_crit_chance;
      v_atk_dodge := random() < v_atk_dodge_chance;
      v_def_dodge := random() < v_def_dodge_chance;

      v_atk_class_damage_mult := CASE WHEN v_attacker_is_warrior THEN 1.20 ELSE 1.0 END;
      v_def_class_damage_mult := CASE WHEN v_defender_is_warrior THEN 1.20 ELSE 1.0 END;

      IF v_def_dodge THEN
        v_atk_dmg := 0;
      ELSE
        v_atk_dmg := COALESCE(v_attacker.attack, 10) * (0.8 + random() * 0.4)
                     * CASE WHEN v_atk_crit THEN 1.5 ELSE 1.0 END
                     * v_atk_class_damage_mult
                     * v_attacker_bloodlust_mult
                     - COALESCE(v_defender.defense, 10) * 0.3;
        v_atk_dmg := GREATEST(v_atk_dmg, 1);
      END IF;

      IF v_atk_dodge THEN
        v_def_dmg := 0;
      ELSE
        v_def_dmg := COALESCE(v_defender.attack, 10) * (0.8 + random() * 0.4)
                     * CASE WHEN v_def_crit THEN 1.5 ELSE 1.0 END
                     * v_def_class_damage_mult
                     * v_defender_bloodlust_mult
                     - COALESCE(v_attacker.defense, 10) * 0.3;
        v_def_dmg := GREATEST(v_def_dmg, 1);
      END IF;

      v_defender_hp := v_defender_hp - v_atk_dmg::INT;
      v_attacker_hp := v_attacker_hp - v_def_dmg::INT;
    END;
  END LOOP;

  IF v_attacker_hp > v_defender_hp THEN
    v_winner_id := p_attacker_id;
  ELSIF v_defender_hp > v_attacker_hp THEN
    v_winner_id := p_defender_id;
  ELSE
    v_winner_id := CASE
      WHEN COALESCE(v_attacker.power, 0) >= COALESCE(v_defender.power, 0) THEN p_attacker_id
      ELSE p_defender_id
    END;
  END IF;

  UPDATE public.users SET energy = energy - 15 WHERE auth_id = p_attacker_id AND energy >= 15;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda enerji yetersiz kaldi');
  END IF;

  v_rating_diff := COALESCE(v_defender.pvp_rating, 1000) - COALESCE(v_attacker.pvp_rating, 1000);
  v_expected_a := 1.0 / (1.0 + power(10.0, v_rating_diff::NUMERIC / 400.0));

  IF v_winner_id = p_attacker_id THEN
    v_new_rating_a := COALESCE(v_attacker.pvp_rating, 1000) + (32 * (1.0 - v_expected_a))::INT;
    v_new_rating_d := COALESCE(v_defender.pvp_rating, 1000) + (32 * (0.0 - (1.0 - v_expected_a)))::INT;
  ELSE
    v_new_rating_a := COALESCE(v_attacker.pvp_rating, 1000) + (32 * (0.0 - v_expected_a))::INT;
    v_new_rating_d := COALESCE(v_defender.pvp_rating, 1000) + (32 * (1.0 - (1.0 - v_expected_a)))::INT;
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
    v_gold_stolen := GREATEST(
      LEAST((v_defender.gold * v_steal_rate)::BIGINT, 5000000::BIGINT),
      10000::BIGINT
    );
  ELSE
    v_gold_stolen := 0;
  END IF;

  UPDATE public.users
  SET gold = gold + CASE WHEN v_winner_id = p_attacker_id THEN v_gold_stolen ELSE 0 END,
      pvp_rating = v_new_rating_a,
      pvp_wins = pvp_wins + CASE WHEN v_winner_id = p_attacker_id THEN 1 ELSE 0 END,
      pvp_losses = pvp_losses + CASE WHEN v_winner_id = p_defender_id THEN 1 ELSE 0 END,
      warrior_bloodlust_streak = CASE
        WHEN COALESCE(character_class, '') <> 'warrior' THEN 0
        WHEN v_winner_id = p_attacker_id THEN LEAST(COALESCE(warrior_bloodlust_streak, 0) + 1, 3)
        ELSE 0
      END,
      warrior_bloodlust_until = CASE
        WHEN COALESCE(character_class, '') <> 'warrior' THEN NULL
        WHEN v_winner_id = p_attacker_id THEN now() + interval '30 minutes'
        ELSE NULL
      END
  WHERE auth_id = p_attacker_id;

  UPDATE public.users
  SET gold = gold - CASE WHEN v_winner_id = p_attacker_id THEN v_gold_stolen ELSE 0 END,
      pvp_rating = v_new_rating_d,
      pvp_wins = pvp_wins + CASE WHEN v_winner_id = p_defender_id THEN 1 ELSE 0 END,
      pvp_losses = pvp_losses + CASE WHEN v_winner_id = p_attacker_id THEN 1 ELSE 0 END,
      warrior_bloodlust_streak = CASE
        WHEN COALESCE(character_class, '') <> 'warrior' THEN 0
        WHEN v_winner_id = p_defender_id THEN LEAST(COALESCE(warrior_bloodlust_streak, 0) + 1, 3)
        ELSE 0
      END,
      warrior_bloodlust_until = CASE
        WHEN COALESCE(character_class, '') <> 'warrior' THEN NULL
        WHEN v_winner_id = p_defender_id THEN now() + interval '30 minutes'
        ELSE NULL
      END
  WHERE auth_id = p_defender_id;

  v_rep_change_winner := CASE WHEN v_winner_id = p_attacker_id THEN 3 ELSE 2 END;
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
    v_hospital_minutes := floor(30 + random() * 120)::INT;

    IF v_winner_id = p_attacker_id THEN
      UPDATE public.users
      SET hospital_until = now() + (v_hospital_minutes || ' minutes')::INTERVAL
      WHERE auth_id = p_defender_id;
    ELSE
      UPDATE public.users
      SET hospital_until = now() + (v_hospital_minutes || ' minutes')::INTERVAL
      WHERE auth_id = p_attacker_id;
    END IF;
  END IF;

  INSERT INTO public.pvp_matches (
    mekan_id, attacker_id, defender_id, winner_id,
    attacker_power, defender_power,
    attacker_hp_remaining, defender_hp_remaining,
    gold_stolen, rep_change_winner, rep_change_loser,
    attacker_rating_before, attacker_rating_after, 
    defender_rating_before, defender_rating_after,
    is_critical_success, hospital_triggered
  ) VALUES (
    p_mekan_id, p_attacker_id, p_defender_id, v_winner_id,
    COALESCE(v_attacker.power, 0), COALESCE(v_defender.power, 0),
    GREATEST(v_attacker_hp, 0), GREATEST(v_defender_hp, 0),
    v_gold_stolen, v_rep_change_winner, v_rep_change_loser,
    COALESCE(v_attacker.pvp_rating, 1000), v_new_rating_a,
    COALESCE(v_defender.pvp_rating, 1000), v_new_rating_d,
    random() < 0.10, v_hospital_triggered
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
    'hospital_triggered', v_hospital_triggered,
    'attacker_bloodlust_active', v_attacker_bloodlust_active,
    'defender_bloodlust_active', v_defender_bloodlust_active,
    'attacker_bloodlust_mult', v_attacker_bloodlust_mult,
    'defender_bloodlust_mult', v_defender_bloodlust_mult
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.pvp_attack(UUID, UUID, UUID) TO authenticated;
