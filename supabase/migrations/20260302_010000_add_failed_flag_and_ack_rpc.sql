-- Migration: add failed flag to craft_queue and acknowledge RPC
-- Generated: 2026-03-02 01:00:00

ALTER TABLE public.craft_queue
  ADD COLUMN IF NOT EXISTS failed boolean DEFAULT false;

-- Drop existing function to allow signature change
DROP FUNCTION IF EXISTS public.get_craft_queue();

-- Replace get_craft_queue to include failed flag in returned rows
CREATE FUNCTION public.get_craft_queue()
RETURNS table (
  id uuid,
  recipe_id uuid,
  recipe_name text,
  recipe_icon text,
  batch_count integer,
  started_at timestamp with time zone,
  completes_at timestamp with time zone,
  is_completed boolean,
  claimed boolean,
  failed boolean,
  xp_reward integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  RETURN QUERY
  SELECT
    cq.id,
    cq.recipe_id,
    COALESCE(ii.name, cr.output_item_id) as recipe_name,
    ii.icon as recipe_icon,
    cq.batch_count,
    cq.started_at,
    cq.completes_at,
    (cq.is_completed OR cq.completes_at <= now()) as is_completed,
    cq.claimed,
    cq.failed,
    COALESCE(cr.xp_reward, 0) as xp_reward
  FROM public.craft_queue cq
  LEFT JOIN public.crafting_recipes cr ON cq.recipe_id = cr.id
  LEFT JOIN public.items ii ON ii.id = cr.output_item_id
  WHERE cq.user_id = v_user_id
  ORDER BY cq.started_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_craft_queue() TO authenticated;

-- RPC: acknowledge a failed or completed craft and remove it from queue
DROP FUNCTION IF EXISTS public.acknowledge_crafted_item(uuid);
CREATE FUNCTION public.acknowledge_crafted_item(p_queue_item_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_row_count integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  DELETE FROM public.craft_queue WHERE id = p_queue_item_id AND user_id = v_user_id;
  GET DIAGNOSTICS v_row_count = ROW_COUNT;
  RETURN v_row_count > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.acknowledge_crafted_item(uuid) TO authenticated;
