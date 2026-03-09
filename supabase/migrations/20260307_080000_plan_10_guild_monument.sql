-- =========================================================================================
-- MIGRATION: PLAN_10_GUILD_MONUMENT
-- =========================================================================================

-- 1. Create Guilds Base Table (if not exists) and add monument columns
CREATE TABLE IF NOT EXISTS public.guilds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  leader_id UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  monument_level INT NOT NULL DEFAULT 0,
  monument_structural BIGINT NOT NULL DEFAULT 0,
  monument_mystical BIGINT NOT NULL DEFAULT 0,
  monument_critical BIGINT NOT NULL DEFAULT 0,
  monument_gold_pool BIGINT NOT NULL DEFAULT 0,
  monument_100_first BOOLEAN NOT NULL DEFAULT false,
  monument_100_at TIMESTAMPTZ
);

-- Ensure users have guild relations
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS guild_id UUID REFERENCES public.guilds(id) ON DELETE SET NULL;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS guild_role TEXT DEFAULT 'member'; -- 'leader', 'commander', 'member'

-- 2. Blueprint inventory
CREATE TABLE IF NOT EXISTS public.guild_blueprints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  blueprint_type TEXT NOT NULL CHECK (blueprint_type IN ('phoenix', 'leviathan', 'titan', 'world_eater', 'eternal')),
  fragments INT NOT NULL DEFAULT 0,
  is_complete BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  
  UNIQUE(guild_id, blueprint_type)
);

-- 3. Member contributions
CREATE TABLE IF NOT EXISTS public.guild_contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  structural_donated BIGINT NOT NULL DEFAULT 0,
  mystical_donated BIGINT NOT NULL DEFAULT 0,
  critical_donated BIGINT NOT NULL DEFAULT 0,
  gold_donated BIGINT NOT NULL DEFAULT 0,
  contribution_score BIGINT NOT NULL DEFAULT 0,
  last_donated_at TIMESTAMPTZ,
  
  UNIQUE(guild_id, user_id)
);

-- 4. Daily donation tracking
CREATE TABLE IF NOT EXISTS public.guild_daily_donations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  donation_date DATE NOT NULL DEFAULT CURRENT_DATE,
  structural_today INT NOT NULL DEFAULT 0,
  mystical_today INT NOT NULL DEFAULT 0,
  critical_today INT NOT NULL DEFAULT 0,
  gold_today BIGINT NOT NULL DEFAULT 0,
  
  UNIQUE(guild_id, user_id, donation_date)
);

-- 5. Monument Upgrade History
CREATE TABLE IF NOT EXISTS public.monument_upgrades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  from_level INT NOT NULL,
  to_level INT NOT NULL,
  structural_spent BIGINT NOT NULL,
  mystical_spent BIGINT NOT NULL,
  critical_spent BIGINT NOT NULL,
  gold_spent BIGINT NOT NULL,
  upgraded_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Guild Leaderboard
CREATE TABLE IF NOT EXISTS public.guild_leaderboard (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  week_start DATE NOT NULL,
  monument_level INT NOT NULL,
  member_count INT NOT NULL,
  rank INT,
  
  UNIQUE(guild_id, week_start)
);

-- 7. RLS
ALTER TABLE public.guilds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_blueprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_daily_donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monument_upgrades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_leaderboard ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Guilds are viewable by everyone' AND tablename = 'guilds') THEN
    CREATE POLICY "Guilds are viewable by everyone" ON public.guilds FOR SELECT USING (true);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Guild data viewable by everyone' AND tablename = 'guild_blueprints') THEN
    CREATE POLICY "Guild data viewable by everyone" ON public.guild_blueprints FOR SELECT USING (true);
    CREATE POLICY "Guild data viewable by everyone" ON public.guild_contributions FOR SELECT USING (true);
    CREATE POLICY "Guild data viewable by everyone" ON public.guild_leaderboard FOR SELECT USING (true);
    CREATE POLICY "Guild data viewable by everyone" ON public.monument_upgrades FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own daily donations' AND tablename = 'guild_daily_donations') THEN
    CREATE POLICY "Users can view their own daily donations" ON public.guild_daily_donations FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;

-- 7.5. Seed monument resource items used by donation RPC
INSERT INTO public.items (
  id, name, name_tr, type, sub_type, description, rarity,
  base_price, is_tradeable, is_market_tradeable, is_direct_tradeable, is_han_only,
  energy_restore, heal_amount, tolerance_increase, overdose_risk
) VALUES
  ('resource_structural', 'Structural Relic', 'Yapisal Kaynak', 'material', 'monument', 'Lonca aniti bagislarinda kullanilan yapisal kaynak.', 'uncommon', 50000, true, false, true, false, 0, 0, 0, 0),
  ('resource_mystical', 'Mystical Relic', 'Mistik Kaynak', 'material', 'monument', 'Lonca aniti bagislarinda kullanilan mistik kaynak.', 'rare', 150000, true, false, true, false, 0, 0, 0, 0),
  ('resource_critical', 'Critical Relic', 'Kritik Kaynak', 'material', 'monument', 'Lonca aniti bagislarinda kullanilan kritik kaynak.', 'epic', 500000, true, false, true, false, 0, 0, 0, 0)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_tr = EXCLUDED.name_tr,
  type = EXCLUDED.type,
  sub_type = EXCLUDED.sub_type,
  description = EXCLUDED.description,
  rarity = EXCLUDED.rarity,
  base_price = EXCLUDED.base_price,
  is_tradeable = EXCLUDED.is_tradeable,
  is_market_tradeable = EXCLUDED.is_market_tradeable,
  is_direct_tradeable = EXCLUDED.is_direct_tradeable,
  is_han_only = EXCLUDED.is_han_only;

-- 8. RPC: donate_to_monument
CREATE OR REPLACE FUNCTION public.donate_to_monument(
  p_user_id UUID,
  p_structural INT DEFAULT 0,
  p_mystical INT DEFAULT 0,
  p_critical INT DEFAULT 0,
  p_gold BIGINT DEFAULT 0
) RETURNS JSONB AS $$
DECLARE
  v_user RECORD;
  v_guild_id UUID;
  v_daily RECORD;
  v_contribution_score BIGINT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  -- Get user and guild
  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz');
  END IF;
  v_guild_id := v_user.guild_id;

  -- Daily limits check
  -- structural max 500, mystical max 200, critical max 50, gold max 10M
  SELECT * INTO v_daily FROM public.guild_daily_donations 
  WHERE guild_id = v_guild_id AND user_id = p_user_id AND donation_date = CURRENT_DATE FOR UPDATE;
  
  IF FOUND THEN
    IF v_daily.structural_today + p_structural > 500 OR
       v_daily.mystical_today + p_mystical > 200 OR
       v_daily.critical_today + p_critical > 50 OR
       v_daily.gold_today + p_gold > 10000000 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Günlük bağış sınırını aştınız');
    END IF;
  ELSE
    IF p_structural > 500 OR p_mystical > 200 OR p_critical > 50 OR p_gold > 10000000 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Günlük bağış sınırını aştınız');
    END IF;
  END IF;

  -- User resources check
  IF v_user.gold < p_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli altınınız yok');
  END IF;
  
  -- Assuming structural=item_structural, mystical=item_mystical, critical=item_critical
  -- We must check and consume inventory items. For simplicity here, we assume there's a helper or direct check
  -- Since we don't have the exact item ids, we use generic ones based on PLAN_10: 'resource_structural', etc.
  IF p_structural > 0 THEN
    UPDATE public.inventory SET quantity = quantity - p_structural 
    WHERE user_id = p_user_id AND item_id = 'resource_structural' AND quantity >= p_structural;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Yeterli yapısal kaynağınız yok'); END IF;
  END IF;

  IF p_mystical > 0 THEN
    UPDATE public.inventory SET quantity = quantity - p_mystical 
    WHERE user_id = p_user_id AND item_id = 'resource_mystical' AND quantity >= p_mystical;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Yeterli mistik kaynağınız yok'); END IF;
  END IF;

  IF p_critical > 0 THEN
    UPDATE public.inventory SET quantity = quantity - p_critical 
    WHERE user_id = p_user_id AND item_id = 'resource_critical' AND quantity >= p_critical;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Yeterli kritik kaynağınız yok'); END IF;
  END IF;

  -- Deduct gold
  IF p_gold > 0 THEN
    UPDATE public.users SET gold = gold - p_gold WHERE auth_id = p_user_id AND gold >= p_gold;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Yeterli altınınız yok'); END IF;
  END IF;

  -- Cleanup zero quantities
  DELETE FROM public.inventory WHERE user_id = p_user_id AND quantity <= 0;

  -- Score calc
  v_contribution_score := p_structural * 10 + p_mystical * 25 + p_critical * 100 + p_gold / 1000;

  -- Add to guild
  UPDATE public.guilds SET 
    monument_structural = monument_structural + p_structural,
    monument_mystical = monument_mystical + p_mystical,
    monument_critical = monument_critical + p_critical,
    monument_gold_pool = monument_gold_pool + p_gold
  WHERE id = v_guild_id;

  -- Update contributions
  INSERT INTO public.guild_contributions (guild_id, user_id, structural_donated, mystical_donated, critical_donated, gold_donated, contribution_score, last_donated_at)
  VALUES (v_guild_id, p_user_id, p_structural, p_mystical, p_critical, p_gold, v_contribution_score, now())
  ON CONFLICT (guild_id, user_id) DO UPDATE SET
    structural_donated = public.guild_contributions.structural_donated + p_structural,
    mystical_donated = public.guild_contributions.mystical_donated + p_mystical,
    critical_donated = public.guild_contributions.critical_donated + p_critical,
    gold_donated = public.guild_contributions.gold_donated + p_gold,
    contribution_score = public.guild_contributions.contribution_score + v_contribution_score,
    last_donated_at = now();

  -- Update daily limits
  INSERT INTO public.guild_daily_donations (guild_id, user_id, donation_date, structural_today, mystical_today, critical_today, gold_today)
  VALUES (v_guild_id, p_user_id, CURRENT_DATE, p_structural, p_mystical, p_critical, p_gold)
  ON CONFLICT (guild_id, user_id, donation_date) DO UPDATE SET
    structural_today = public.guild_daily_donations.structural_today + p_structural,
    mystical_today = public.guild_daily_donations.mystical_today + p_mystical,
    critical_today = public.guild_daily_donations.critical_today + p_critical,
    gold_today = public.guild_daily_donations.gold_today + p_gold;

  RETURN jsonb_build_object('success', true, 'score_added', v_contribution_score);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.donate_to_monument(UUID, INT, INT, INT, BIGINT) TO authenticated;

-- 9. RPC: upgrade_monument
CREATE OR REPLACE FUNCTION public.upgrade_monument(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user RECORD;
  v_guild RECORD;
  v_next_level INT;
  v_req_structural INT;
  v_req_mystical INT;
  v_req_critical INT;
  v_req_gold BIGINT;
  v_blueprint_needed TEXT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz');
  END IF;

  IF v_user.guild_role NOT IN ('leader', 'commander') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkiniz yok (Lider veya Komutan gerekli)');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id FOR UPDATE;
  v_next_level := v_guild.monument_level + 1;

  IF v_next_level > 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Anıt zaten maksimum seviyede');
  END IF;

  -- Simplified requirements (Level^2 * base)
  v_req_structural := v_next_level * v_next_level * 100;
  v_req_mystical := v_next_level * v_next_level * 50;
  v_req_critical := v_next_level * v_next_level * 5;
  v_req_gold := v_next_level * v_next_level * 5000000::bigint;

  -- Check blueprint at milestones (20, 40, 60, 80, 100)
  IF v_next_level = 20 THEN v_blueprint_needed := 'phoenix';
  ELSIF v_next_level = 40 THEN v_blueprint_needed := 'leviathan';
  ELSIF v_next_level = 60 THEN v_blueprint_needed := 'titan';
  ELSIF v_next_level = 80 THEN v_blueprint_needed := 'world_eater';
  ELSIF v_next_level = 100 THEN v_blueprint_needed := 'eternal';
  END IF;

  IF v_blueprint_needed IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.guild_blueprints
      WHERE guild_id = v_guild.id AND blueprint_type = v_blueprint_needed AND is_complete = true
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', v_blueprint_needed || ' blueprint tamamlanmalı');
    END IF;
  END IF;

  IF v_guild.monument_structural < v_req_structural OR
     v_guild.monument_mystical < v_req_mystical OR
     v_guild.monument_critical < v_req_critical OR
     v_guild.monument_gold_pool < v_req_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli kaynak yok');
  END IF;

  UPDATE public.guilds SET
    monument_level = v_next_level,
    monument_structural = monument_structural - v_req_structural,
    monument_mystical = monument_mystical - v_req_mystical,
    monument_critical = monument_critical - v_req_critical,
    monument_gold_pool = monument_gold_pool - v_req_gold,
    monument_100_first = CASE WHEN v_next_level = 100 AND NOT EXISTS (SELECT 1 FROM public.guilds WHERE monument_level >= 100 AND id != v_guild.id) THEN true ELSE monument_100_first END,
    monument_100_at = CASE WHEN v_next_level = 100 THEN now() ELSE monument_100_at END
  WHERE id = v_guild.id;

  INSERT INTO public.monument_upgrades (guild_id, from_level, to_level, structural_spent, mystical_spent, critical_spent, gold_spent, upgraded_by)
  VALUES (v_guild.id, v_guild.monument_level, v_next_level, v_req_structural, v_req_mystical, v_req_critical, v_req_gold, p_user_id);

  RETURN jsonb_build_object('success', true, 'new_level', v_next_level);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.upgrade_monument(UUID) TO authenticated;
