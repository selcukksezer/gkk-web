-- =========================================================================================
-- MIGRATION: Guild Officer Kick
-- =========================================================================================
-- Allow officers to kick members. Officers cannot kick other officers or the leader.

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

  SELECT id, guild_id, username, guild_role FROM public.users WHERE id = p_member_id INTO v_member;
  IF NOT FOUND OR v_member.guild_id != v_caller.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Uye bulunamadi');
  END IF;

  IF COALESCE(v_caller.guild_role, '') = 'leader' THEN
    -- Lider herkesi atabilir (kendisi haric, kendisini leave ile atar)
    IF v_caller.id = p_member_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Kendinizi atamazsiniz');
    END IF;
  ELSIF COALESCE(v_caller.guild_role, '') = 'officer' THEN
    -- Subay sadece normal uyeleri atabilir
    IF COALESCE(v_member.guild_role, '') != 'member' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Subaylar sadece normal uyeleri atabilir');
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Yetkiniz yok');
  END IF;

  UPDATE public.users
  SET guild_id   = NULL,
      guild_role = 'member'
  WHERE id = p_member_id;

  RETURN jsonb_build_object('success', true, 'username', v_member.username);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.kick_guild_member(UUID) TO authenticated;
