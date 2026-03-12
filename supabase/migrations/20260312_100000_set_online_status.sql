-- Migration: 20260312_100000_set_online_status.sql
-- Description: Adds a function to update player's online status.

CREATE OR REPLACE FUNCTION set_online_status(p_is_online BOOLEAN)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET is_online = p_is_online,
      last_active_at = NOW()
  WHERE id = auth.uid();
END;
$$;
