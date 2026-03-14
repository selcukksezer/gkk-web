-- Migration: Add output_item_id and output_quantity to get_craft_queue RPC
-- Fixes: UI displays "res_mushroom_common ×3" instead of readable product name

DROP FUNCTION IF EXISTS public.get_craft_queue();

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
  xp_reward integer,
  output_item_id text,
  output_quantity integer,
  output_name text
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
    cr.name as recipe_name,
    ii.icon as recipe_icon,
    cq.batch_count,
    cq.started_at,
    cq.completes_at,
    (cq.is_completed OR cq.completes_at <= now()) as is_completed,
    cq.claimed,
    cq.failed,
    COALESCE(cr.xp_reward, 0) as xp_reward,
    cr.output_item_id,
    cr.output_quantity,
    COALESCE(output_items.name, cr.output_item_id) as output_name
  FROM public.craft_queue cq
  LEFT JOIN public.crafting_recipes cr ON cq.recipe_id = cr.id
  LEFT JOIN public.items ii ON ii.id = cr.output_item_id
  LEFT JOIN public.items output_items ON output_items.id = cr.output_item_id
  WHERE cq.user_id = v_user_id
  ORDER BY cq.started_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_craft_queue() TO authenticated;
