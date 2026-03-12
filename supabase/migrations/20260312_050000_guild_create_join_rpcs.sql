-- =========================================================================================
-- MIGRATION: Guild Create / Join / Leave RPCs
-- =========================================================================================
-- Context: PLAN_10 guild tables (guilds, guild_blueprints, guild_contributions, etc.)
-- were created by 20260307_080000_plan_10_guild_monument.sql.
-- However create_guild, join_guild, and leave_guild RPCs were never written.
-- Players cannot form guilds, which means donate_to_monument and upgrade_monument
-- always operate with NULL guild_id and have no effect.
-- This migration adds the missing foundational guild management RPCs.
-- =========================================================================================

-- ── 1. create_guild ──────────────────────────────────────────────────────────────────────
-- Creates a new guild with the caller as leader.
-- Enforces: caller must not already belong to a guild.

DROP FUNCTION IF EXISTS public.create_guild(TEXT);

CREATE OR REPLACE FUNCTION public.create_guild(p_name TEXT)
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
  v_guild   RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir lonca uyesisiniz. Oncelikle loncayi terk edin');
  END IF;

  p_name := trim(p_name);
  IF p_name IS NULL OR length(p_name) < 3 OR length(p_name) > 30 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca adi 3-30 karakter arasinda olmali');
  END IF;

  -- Uniqueness is enforced by the UNIQUE constraint on guilds.name
  INSERT INTO public.guilds (name, leader_id)
  VALUES (p_name, v_auth_id)
  RETURNING * INTO v_guild;

  UPDATE public.users
  SET guild_id   = v_guild.id,
      guild_role = 'leader'
  WHERE auth_id = v_auth_id;

  -- Initialise empty contribution row for the leader
  INSERT INTO public.guild_contributions (guild_id, user_id)
  VALUES (v_guild.id, v_auth_id)
  ON CONFLICT (guild_id, user_id) DO NOTHING;

  RETURN jsonb_build_object(
    'success',   true,
    'guild_id',  v_guild.id,
    'name',      v_guild.name,
    'role',      'leader'
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu lonca adi zaten alinmis');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.create_guild(TEXT) TO authenticated;


-- ── 2. join_guild ────────────────────────────────────────────────────────────────────────
-- Joins an existing guild by guild ID.
-- Enforces: caller must not already belong to a guild; target guild must exist.

DROP FUNCTION IF EXISTS public.join_guild(UUID);

CREATE OR REPLACE FUNCTION public.join_guild(p_guild_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
  v_guild   RECORD;
  v_members BIGINT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir lonca uyesisiniz. Oncelikle loncayi terk edin');
  END IF;

  SELECT * FROM public.guilds WHERE id = p_guild_id INTO v_guild;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca bulunamadi');
  END IF;

  -- Enforce 50-member cap (PLAN_10 §3.0 lonca buyukluk tablosu)
  SELECT COUNT(*) INTO v_members FROM public.users WHERE guild_id = p_guild_id;
  IF v_members >= 50 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca dolu (maks. 50 uye)');
  END IF;

  UPDATE public.users
  SET guild_id   = p_guild_id,
      guild_role = 'member'
  WHERE auth_id = v_auth_id;

  INSERT INTO public.guild_contributions (guild_id, user_id)
  VALUES (p_guild_id, v_auth_id)
  ON CONFLICT (guild_id, user_id) DO NOTHING;

  RETURN jsonb_build_object(
    'success',  true,
    'guild_id', p_guild_id,
    'name',     v_guild.name,
    'role',     'member'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.join_guild(UUID) TO authenticated;


-- ── 3. leave_guild ───────────────────────────────────────────────────────────────────────
-- Leaves the caller's current guild.
-- Leaders may not leave; they must transfer leadership or disband first.

DROP FUNCTION IF EXISTS public.leave_guild();

CREATE OR REPLACE FUNCTION public.leave_guild()
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id, guild_role FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Herhangi bir loncada degilsiniz');
  END IF;

  IF COALESCE(v_user.guild_role, '') = 'leader' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',   'Lonca lideri olarak ayrilamazsiniz. Once loncayi dagitmaniz veya liderlik devretmeniz gerekir'
    );
  END IF;

  UPDATE public.users
  SET guild_id   = NULL,
      guild_role = 'member'  -- reset to default; will be overwritten on next join
  WHERE auth_id = v_auth_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.leave_guild() TO authenticated;


-- ── 4. get_guild_info ────────────────────────────────────────────────────────────────────
-- Returns guild details + member list + monument level for the caller's guild.

DROP FUNCTION IF EXISTS public.get_guild_info();

CREATE OR REPLACE FUNCTION public.get_guild_info()
RETURNS JSONB AS $$
DECLARE
  v_auth_id  UUID;
  v_user     RECORD;
  v_guild    RECORD;
  v_members  JSONB;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT guild_id FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND OR v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Herhangi bir loncada degilsiniz');
  END IF;

  SELECT * FROM public.guilds WHERE id = v_user.guild_id INTO v_guild;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca bulunamadi');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'user_id',   u.auth_id,
      'username',  u.username,
      'level',     u.level,
      'role',      u.guild_role,
      'power',     COALESCE(u.power, 0)
    ) ORDER BY u.guild_role, u.level DESC
  )
  INTO v_members
  FROM public.users u
  WHERE u.guild_id = v_guild.id;

  RETURN jsonb_build_object(
    'success',            true,
    'guild_id',           v_guild.id,
    'name',               v_guild.name,
    'leader_id',          v_guild.leader_id,
    'monument_level',     v_guild.monument_level,
    'monument_structural',v_guild.monument_structural,
    'monument_mystical',  v_guild.monument_mystical,
    'monument_critical',  v_guild.monument_critical,
    'monument_gold_pool', v_guild.monument_gold_pool,
    'members',            COALESCE(v_members, '[]'::jsonb),
    'member_count',       (SELECT COUNT(*) FROM public.users WHERE guild_id = v_guild.id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_guild_info() TO authenticated;
