BEGIN;

DROP FUNCTION IF EXISTS public.unblock_chat_user(UUID);
CREATE OR REPLACE FUNCTION public.unblock_chat_user(p_blocked_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_deleted_count INTEGER;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_blocked_user_id IS NULL OR p_blocked_user_id = v_user.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kullanici');
  END IF;

  DELETE FROM public.chat_blocks
  WHERE blocker_user_id = v_user.id
    AND blocked_user_id = p_blocked_user_id;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', v_deleted_count > 0,
    'deleted_count', v_deleted_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.unblock_chat_user(UUID) TO authenticated;


DROP FUNCTION IF EXISTS public.get_blocked_chat_users();
CREATE OR REPLACE FUNCTION public.get_blocked_chat_users()
RETURNS TABLE (
  blocked_user_id UUID,
  username TEXT,
  display_name TEXT,
  blocked_at TIMESTAMPTZ
) AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  RETURN QUERY
  SELECT
    cb.blocked_user_id,
    u.username,
    u.display_name,
    cb.created_at
  FROM public.chat_blocks cb
  JOIN public.users u ON u.id = cb.blocked_user_id
  WHERE cb.blocker_user_id = v_user.id
  ORDER BY cb.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_blocked_chat_users() TO authenticated;

COMMIT;
