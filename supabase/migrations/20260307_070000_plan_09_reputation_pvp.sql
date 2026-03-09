-- =========================================================================================
-- MIGRATION: PLAN_09_REPUTATION_PVP
-- =========================================================================================

-- 1. Create pvp_matches table (supersedes mekan_pvp_matches for advanced features)
CREATE TABLE IF NOT EXISTS public.pvp_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mekan_id UUID REFERENCES public.mekans(id),
  attacker_id UUID NOT NULL REFERENCES auth.users(id),
  defender_id UUID NOT NULL REFERENCES auth.users(id),
  winner_id UUID REFERENCES auth.users(id),
  
  attacker_power INT NOT NULL,
  defender_power INT NOT NULL,
  attacker_hp_remaining INT NOT NULL DEFAULT 0,
  defender_hp_remaining INT NOT NULL DEFAULT 0,
  
  gold_stolen BIGINT NOT NULL DEFAULT 0,
  rep_change_winner INT NOT NULL DEFAULT 0,
  rep_change_loser INT NOT NULL DEFAULT 0,
  
  attacker_rating_before INT NOT NULL,
  attacker_rating_after INT NOT NULL,
  defender_rating_before INT NOT NULL,
  defender_rating_after INT NOT NULL,
  
  is_critical_success BOOLEAN NOT NULL DEFAULT false,
  hospital_triggered BOOLEAN NOT NULL DEFAULT false,
  
  rounds INT NOT NULL DEFAULT 3,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. PvP siralama tablosu (weekly snapshot)
CREATE TABLE IF NOT EXISTS public.pvp_leaderboard (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  week_start DATE NOT NULL,
  rating INT NOT NULL,
  wins INT NOT NULL DEFAULT 0,
  losses INT NOT NULL DEFAULT 0,
  gold_earned BIGINT NOT NULL DEFAULT 0,
  rep_earned INT NOT NULL DEFAULT 0,
  rank INT,
  
  UNIQUE(user_id, week_start)
);

-- 3. PvP gunluk saldiri tracking
CREATE TABLE IF NOT EXISTS public.pvp_daily_attacks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attacker_id UUID NOT NULL REFERENCES auth.users(id),
  defender_id UUID NOT NULL REFERENCES auth.users(id),
  attack_date DATE NOT NULL DEFAULT CURRENT_DATE,
  attack_count INT NOT NULL DEFAULT 1,
  
  UNIQUE(attacker_id, defender_id, attack_date)
);

-- 3.5. RLS Policies
ALTER TABLE public.pvp_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pvp_leaderboard ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pvp_daily_attacks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own pvp matches' AND tablename = 'pvp_matches') THEN
    CREATE POLICY "Users can view their own pvp matches" ON public.pvp_matches FOR SELECT USING (auth.uid() = attacker_id OR auth.uid() = defender_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Leaderboard is public' AND tablename = 'pvp_leaderboard') THEN
    CREATE POLICY "Leaderboard is public" ON public.pvp_leaderboard FOR SELECT USING (true);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their daily attacks' AND tablename = 'pvp_daily_attacks') THEN
    CREATE POLICY "Users can view their daily attacks" ON public.pvp_daily_attacks FOR SELECT USING (auth.uid() = attacker_id);
  END IF;
END $$;

-- 4. Drop the old pvp_attack_mekan if it exists
DROP FUNCTION IF EXISTS public.pvp_attack_mekan(UUID, UUID, UUID, BIGINT);

-- 5. Create new advanced pvp_attack RPC
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
  IF p_attacker_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  -- Oyuncu kontrolu
  SELECT * INTO v_attacker FROM public.users WHERE auth_id = p_attacker_id FOR UPDATE;
  SELECT * INTO v_defender FROM public.users WHERE auth_id = p_defender_id FOR UPDATE;

  IF v_attacker IS NULL OR v_defender IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi');
  END IF;

  IF v_attacker.level < 10 OR v_defender.level < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'PvP için minimum level 10');
  END IF;

  -- Enerji kontrolu
  IF v_attacker.energy < 15 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Enerji yetersiz (15 gerekli)');
  END IF;

  -- Hastane/hapis kontrolu
  IF v_attacker.hospital_until > now() OR v_attacker.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastanede/hapiste PvP yapilamaz');
  END IF;
  IF v_defender.hospital_until > now() OR v_defender.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakip musait degil');
  END IF;

  -- Ayni lonca kontrolu
  IF v_attacker.guild_id IS NOT NULL AND v_attacker.guild_id = v_defender.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ayni lonca uyesine saldirilamaz');
  END IF;

  -- Gunluk ayni hedefe saldiri limiti
  SELECT COALESCE(attack_count, 0) INTO v_daily_count
  FROM public.pvp_daily_attacks
  WHERE attacker_id = p_attacker_id AND defender_id = p_defender_id AND attack_date = CURRENT_DATE;
  IF v_daily_count >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu oyuncuya bugun 3 kez saldirdiniz');
  END IF;

  -- Mekan kontrolu (PvP destekleyen mekan mi?)
  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND OR v_mekan.mekan_type NOT IN ('dovus_kulubu', 'luks_lounge', 'yeralti') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu mekanda PvP yapilamaz');
  END IF;

  -- Rating matchmaking (±300 kontrol)
  IF ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > 300 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rating farki cok yuksek (max ±300)');
  END IF;

  -- === DOVUS HESAPLAMASI ===
  v_attacker_hp := COALESCE(v_attacker.health, 100);
  v_defender_hp := COALESCE(v_defender.health, 100);

  -- 3 tur simulasyonu
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

  -- Kazanan belirleme
  IF v_attacker_hp > v_defender_hp THEN
    v_winner_id := p_attacker_id;
  ELSIF v_defender_hp > v_attacker_hp THEN
    v_winner_id := p_defender_id;
  ELSE
    v_winner_id := CASE WHEN COALESCE(v_attacker.power, 0) >= COALESCE(v_defender.power, 0) THEN p_attacker_id ELSE p_defender_id END;
  END IF;

  -- Enerji dusur
  UPDATE public.users SET energy = energy - 15 WHERE auth_id = p_attacker_id AND energy >= 15;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda enerji yetersiz kaldi');
  END IF;

  -- === RATING HESAPLAMASI (Elo) ===
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

  -- === GOLD GANIMET ===
  v_rating_diff := COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000);

  IF v_winner_id = p_attacker_id THEN
    v_steal_rate := CASE
      WHEN v_rating_diff > 200  THEN 0.01
      WHEN v_rating_diff > 0    THEN 0.02
      WHEN v_rating_diff > -200 THEN 0.03
      ELSE 0.05
    END;
    v_gold_stolen := GREATEST(LEAST((v_defender.gold * v_steal_rate)::bigint, 5000000::bigint), 10000::bigint);
    v_mekan_commission := (v_gold_stolen * 0.05)::bigint;
    v_total_gold := v_gold_stolen - v_mekan_commission;
  ELSE
    v_steal_rate := CASE
      WHEN v_rating_diff < -200 THEN 0.01
      WHEN v_rating_diff < 0    THEN 0.02
      WHEN v_rating_diff < 200  THEN 0.03
      ELSE 0.05
    END;
    v_gold_stolen := GREATEST(LEAST((v_attacker.gold * v_steal_rate)::bigint, 5000000::bigint), 10000::bigint);
    v_mekan_commission := (v_gold_stolen * 0.05)::bigint;
    v_total_gold := v_gold_stolen - v_mekan_commission;
  END IF;

  -- === REPUTATION ===
  v_rep_win := (100 * CASE
    WHEN ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > 200 THEN 0.5
    WHEN ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > 0   THEN 1.0
    WHEN ABS(COALESCE(v_attacker.pvp_rating, 1000) - COALESCE(v_defender.pvp_rating, 1000)) > -200 THEN 1.5
    ELSE 2.5
  END)::int;
  v_rep_loss := (50 * 1.0)::int;

  -- Critical success kontrolu
  IF v_winner_id IS NOT NULL THEN
    DECLARE
      v_hp_diff NUMERIC;
      v_winner_hp INT := CASE WHEN v_winner_id = p_attacker_id THEN v_attacker_hp ELSE v_defender_hp END;
      v_loser_hp INT := CASE WHEN v_winner_id = p_attacker_id THEN v_defender_hp ELSE v_attacker_hp END;
      v_winner_rating INT := CASE WHEN v_winner_id = p_attacker_id THEN COALESCE(v_attacker.pvp_rating, 1000) ELSE COALESCE(v_defender.pvp_rating, 1000) END;
      v_loser_rating INT := CASE WHEN v_winner_id = p_attacker_id THEN COALESCE(v_defender.pvp_rating, 1000) ELSE COALESCE(v_attacker.pvp_rating, 1000) END;
    BEGIN
      v_hp_diff := (v_winner_hp - v_loser_hp)::numeric / GREATEST(v_winner_hp, 1);
      IF v_hp_diff > 0.5 AND (v_loser_rating - v_winner_rating) > 100 THEN
        v_critical := true;
        v_rep_win := v_rep_win * 3;
        v_total_gold := v_total_gold * 2;
      END IF;
    END;
  END IF;

  -- === GUNCELLEMELER ===
  IF v_winner_id = p_attacker_id THEN
    UPDATE public.users SET
      pvp_wins = COALESCE(pvp_wins, 0) + 1,
      pvp_rating = v_new_rating_a,
      gold = gold + v_total_gold,
      reputation = COALESCE(reputation, 0) + v_rep_win
    WHERE auth_id = p_attacker_id;

    -- Kaybeden: hastane riski %10
    v_hospital := random() < 0.10;
    UPDATE public.users SET
      pvp_losses = COALESCE(pvp_losses, 0) + 1,
      pvp_rating = v_new_rating_d,
      gold = GREATEST(gold - v_gold_stolen, 0::bigint),
      reputation = GREATEST(COALESCE(reputation, 0) - v_rep_loss, 0),
      hospital_until = CASE WHEN v_hospital THEN now() + '30 minutes'::interval ELSE hospital_until END,
      hospital_reason = CASE WHEN v_hospital THEN 'PvP Defeat' ELSE hospital_reason END
    WHERE auth_id = p_defender_id;
  ELSE
    v_hospital := random() < 0.10;
    UPDATE public.users SET
      pvp_losses = COALESCE(pvp_losses, 0) + 1,
      pvp_rating = v_new_rating_a,
      gold = GREATEST(gold - v_gold_stolen, 0::bigint),
      reputation = GREATEST(COALESCE(reputation, 0) - v_rep_loss, 0),
      hospital_until = CASE WHEN v_hospital THEN now() + '30 minutes'::interval ELSE hospital_until END,
      hospital_reason = CASE WHEN v_hospital THEN 'PvP Defeat' ELSE hospital_reason END
    WHERE auth_id = p_attacker_id;

    UPDATE public.users SET
      pvp_wins = COALESCE(pvp_wins, 0) + 1,
      pvp_rating = v_new_rating_d,
      gold = gold + v_total_gold,
      reputation = COALESCE(reputation, 0) + v_rep_win
    WHERE auth_id = p_defender_id;
  END IF;

  -- Mekan komisyon
  UPDATE public.users SET gold = gold + v_mekan_commission WHERE auth_id = v_mekan.owner_id;

  -- Gunluk saldiri sayaci
  INSERT INTO public.pvp_daily_attacks (attacker_id, defender_id, attack_date, attack_count)
  VALUES (p_attacker_id, p_defender_id, CURRENT_DATE, 1)
  ON CONFLICT (attacker_id, defender_id, attack_date) DO UPDATE SET attack_count = public.pvp_daily_attacks.attack_count + 1;

  -- Mac kaydi
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
    v_gold_stolen, v_rep_win, v_rep_loss,
    COALESCE(v_attacker.pvp_rating, 1000), v_new_rating_a,
    COALESCE(v_defender.pvp_rating, 1000), v_new_rating_d,
    v_critical, v_hospital
  );

  RETURN jsonb_build_object(
    'success', true,
    'winner', v_winner_id,
    'attacker_hp', GREATEST(v_attacker_hp, 0),
    'defender_hp', GREATEST(v_defender_hp, 0),
    'gold_stolen', v_gold_stolen,
    'rep_change', CASE WHEN v_winner_id = p_attacker_id THEN v_rep_win ELSE -v_rep_loss END,
    'new_rating', v_new_rating_a,
    'critical_success', v_critical,
    'hospital', v_hospital
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.pvp_attack(UUID, UUID, UUID) TO authenticated;
