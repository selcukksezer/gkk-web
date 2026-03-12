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

CREATE OR REPLACE FUNCTION public.create_guild(p_name TEXT, p_description TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
  v_guild   RECORD;
  v_tag     TEXT;
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

  -- Generate a non-null tag for the guild (remove non-alnum, uppercase, max 30 chars).
  v_tag := left(upper(regexp_replace(p_name, '[^A-Z0-9]', '', 'g')), 30);
  IF v_tag = '' THEN
    v_tag := left(md5(random()::text), 8);
  END IF;

  -- Uniqueness is enforced by the UNIQUE constraint on guilds.name
  INSERT INTO public.guilds (name, tag, leader_id, description)
  VALUES (p_name, v_tag, v_auth_id, p_description)
  RETURNING * INTO v_guild;

  -- Deduct creation cost from user's gold
  UPDATE public.users
  SET guild_id   = v_guild.id,
      guild_role = 'leader',
      gold = gold - 10000000
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

GRANT EXECUTE ON FUNCTION public.create_guild(TEXT, TEXT) TO authenticated;


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
      'player_id', u.id,
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
    'description',        v_guild.description,
    'level',              v_guild.level,
    'leader_id',          v_guild.leader_id,
    'monument_level',     v_guild.monument_level,
    'monument_structural',v_guild.monument_structural,
    'monument_mystical',  v_guild.monument_mystical,
    'monument_critical',  v_guild.monument_critical,
    'monument_gold_pool', v_guild.monument_gold_pool,
    'members',            COALESCE(v_members, '[]'::jsonb),
    'member_count',       (SELECT COUNT(*) FROM public.users WHERE guild_id = v_guild.id),
    'max_members',        v_guild.max_members,
    'total_power',        (SELECT COALESCE(SUM(power), 0) FROM public.users WHERE guild_id = v_guild.id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_guild_info() TO authenticated;


-- Compatibility wrapper: allow calls to create_guild(p_name TEXT) for older clients
DROP FUNCTION IF EXISTS public.create_guild(TEXT);

CREATE OR REPLACE FUNCTION public.create_guild(p_name TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN public.create_guild(p_name, NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.create_guild(TEXT) TO authenticated;


-- ── 5. get_my_guild ─────────────────────────────────────────────────────────────────────
-- Returns guild details for the caller's guild (alias for get_guild_info).

DROP FUNCTION IF EXISTS public.get_my_guild();

CREATE OR REPLACE FUNCTION public.get_my_guild()
RETURNS JSONB AS $$
BEGIN
  RETURN public.get_guild_info();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_my_guild() TO authenticated;


-- ── 6. search_guilds ────────────────────────────────────────────────────────────────────
-- Search for guilds by name.

DROP FUNCTION IF EXISTS public.search_guilds(TEXT);

CREATE OR REPLACE FUNCTION public.search_guilds(p_query TEXT)
RETURNS JSONB AS $$
DECLARE
  v_results JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',            g.id,
      'name',          g.name,
      'level',         g.level,
      'description',   g.description,
      'member_count',  (SELECT COUNT(*) FROM public.users WHERE guild_id = g.id),
      'max_members',   g.max_members,
      'total_power',   COALESCE((SELECT SUM(power) FROM public.users WHERE guild_id = g.id), 0)
    )
  )
  INTO v_results
  FROM public.guilds g
  WHERE g.name ILIKE '%' || p_query || '%'
  LIMIT 20;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.search_guilds(TEXT) TO authenticated;


-- ── 7. promote_guild_member ─────────────────────────────────────────────────────────────
-- Promote member to officer (leader only).

DROP FUNCTION IF EXISTS public.promote_guild_member(UUID);

CREATE OR REPLACE FUNCTION public.promote_guild_member(p_member_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_auth_id     UUID;
  v_caller      RECORD;
  v_member      RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id, guild_role FROM public.users WHERE auth_id = v_auth_id INTO v_caller;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF COALESCE(v_caller.guild_role, '') != 'leader' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lider yukseltebilir');
  END IF;

  SELECT id, guild_id, username FROM public.users WHERE id = p_member_id INTO v_member;
  IF NOT FOUND OR v_member.guild_id != v_caller.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Uye bulunamadi');
  END IF;

  UPDATE public.users SET guild_role = 'officer' WHERE id = p_member_id;

  RETURN jsonb_build_object('success', true, 'username', v_member.username);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.promote_guild_member(UUID) TO authenticated;


-- ── 8. demote_guild_member ──────────────────────────────────────────────────────────────
-- Demote officer to member (leader only).

DROP FUNCTION IF EXISTS public.demote_guild_member(UUID);

CREATE OR REPLACE FUNCTION public.demote_guild_member(p_member_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_auth_id     UUID;
  v_caller      RECORD;
  v_member      RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id, guild_role FROM public.users WHERE auth_id = v_auth_id INTO v_caller;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF COALESCE(v_caller.guild_role, '') != 'leader' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lider dusurebilir');
  END IF;

  SELECT id, guild_id, username FROM public.users WHERE id = p_member_id INTO v_member;
  IF NOT FOUND OR v_member.guild_id != v_caller.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Uye bulunamadi');
  END IF;

  UPDATE public.users SET guild_role = 'member' WHERE id = p_member_id;

  RETURN jsonb_build_object('success', true, 'username', v_member.username);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.demote_guild_member(UUID) TO authenticated;


-- ── 9. kick_guild_member ────────────────────────────────────────────────────────────────
-- Remove member from guild (leader only).

DROP FUNCTION IF EXISTS public.kick_guild_member(UUID);

CREATE OR REPLACE FUNCTION public.kick_guild_member(p_member_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_auth_id     UUID;
  v_caller      RECORD;
  v_member      RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id, guild_role FROM public.users WHERE auth_id = v_auth_id INTO v_caller;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF COALESCE(v_caller.guild_role, '') != 'leader' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lider atabilir');
  END IF;

  SELECT id, guild_id, username FROM public.users WHERE id = p_member_id INTO v_member;
  IF NOT FOUND OR v_member.guild_id != v_caller.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Uye bulunamadi');
  END IF;

  UPDATE public.users
  SET guild_id   = NULL,
      guild_role = 'member'
  WHERE id = p_member_id;

  RETURN jsonb_build_object('success', true, 'username', v_member.username);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.kick_guild_member(UUID) TO authenticated;
