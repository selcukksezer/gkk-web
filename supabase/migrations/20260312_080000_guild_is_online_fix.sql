-- =========================================================================================
-- MIGRATION: Guild is_online Fix
-- =========================================================================================
-- Updates the `get_guild_info` RPC to include the `is_online` field from the users table.

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
      'power',     COALESCE(u.power, 0),
      'is_online', COALESCE(u.is_online, false)
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
