-- =========================================================================================
-- MIGRATION: Guild Disband RPC
-- =========================================================================================
-- Adds the missing `disband_guild` RPC for guild leaders to disband their guild.

DROP FUNCTION IF EXISTS public.disband_guild();

CREATE OR REPLACE FUNCTION public.disband_guild()
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
  v_guild   RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik doğrulama gerekli');
  END IF;

  SELECT id, guild_id, guild_role FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;

  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Herhangi bir loncada değilsiniz');
  END IF;

  IF COALESCE(v_user.guild_role, '') != 'leader' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lonca lideri loncayı dağıtabilir');       
  END IF;

  SELECT * FROM public.guilds WHERE id = v_user.guild_id INTO v_guild;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca bulunamadı');
  END IF;

  -- 1. Loncadaki tüm üyelerin guild_id ve guild_role değerlerini temizle
  UPDATE public.users
  SET guild_id   = NULL,
      guild_role = 'member'
  WHERE guild_id = v_guild.id;

  -- 2. Loncaya ait verileri sil (veya on delete cascade varsa gerekmez ama biz temizleyelim)
  DELETE FROM public.guild_contributions WHERE guild_id = v_guild.id;
  DELETE FROM public.guild_blueprints WHERE guild_id = v_guild.id;
  DELETE FROM public.guild_daily_donations WHERE guild_id = v_guild.id;
  DELETE FROM public.monument_upgrades WHERE guild_id = v_guild.id;
  DELETE FROM public.guild_leaderboard WHERE guild_id = v_guild.id;

  -- 3. Loncayı sil
  DELETE FROM public.guilds WHERE id = v_guild.id;

  RETURN jsonb_build_object('success', true, 'message', 'Lonca başarıyla dağıtıldı');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.disband_guild() TO authenticated;
