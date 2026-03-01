-- Migration: Fix get_craft_recipes RPC (resolve 400 errors)
-- Date: 2026-03-01
-- Purpose: Drop all old get_craft_recipes signatures and create clean version

-- ====================================================================
-- STEP 1: Drop all conflicting signatures
-- ====================================================================
DROP FUNCTION IF EXISTS public.get_craft_recipes();
DROP FUNCTION IF EXISTS public.get_craft_recipes(integer);
DROP FUNCTION IF EXISTS public.get_craft_recipes(text);
DROP FUNCTION IF EXISTS public.get_craft_recipes(text, integer);

-- ====================================================================
-- STEP 2: Create clean get_craft_recipes with proper signature
-- ====================================================================
CREATE FUNCTION public.get_craft_recipes(p_user_level integer DEFAULT 1)
RETURNS table (
  id uuid,
  recipe_id uuid,
  name text,
  output_item_id text,
  output_name text,
  output_quantity integer,
  output_rarity text,
  item_type text,
  recipe_type text,
  required_level integer,
  production_time_seconds integer,
  success_rate double precision,
  xp_reward integer,
  ingredients jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cr.id,
    cr.id as recipe_id,
    COALESCE(ii.name, cr.output_item_id) as name,
    cr.output_item_id,
    COALESCE(ii.name, cr.output_item_id) as output_name,
    1 as output_quantity,
    COALESCE(ii.rarity, 'common') as output_rarity,
    COALESCE(ii.type, 'accessory') as item_type,
    COALESCE(ii.production_building_type, 'workbench') as recipe_type,
    cr.required_level,
    COALESCE(cr.production_time_seconds, 30) as production_time_seconds,
    cr.success_rate,
    cr.xp_reward,
    cr.ingredients
  FROM public.crafting_recipes cr
  LEFT JOIN public.items ii ON ii.id = cr.output_item_id
  WHERE cr.required_level <= p_user_level
  ORDER BY cr.required_level ASC, cr.output_item_id ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_craft_recipes(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.get_craft_recipes(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_craft_recipes(integer) TO service_role;

-- ====================================================================
-- STEP 3: Create cancel_craft_item RPC
-- ====================================================================
DROP FUNCTION IF EXISTS public.cancel_craft_item(uuid);

CREATE FUNCTION public.cancel_craft_item(
  p_queue_item_id uuid
)
RETURNS TABLE (
  success boolean,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_queue craft_queue%ROWTYPE;
BEGIN
  -- Verify user is authenticated
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text;
    RETURN;
  END IF;

  -- Fetch queue item - ensure it belongs to authenticated user
  SELECT * FROM public.craft_queue WHERE id = p_queue_item_id AND user_id = v_user_id INTO v_queue;
  IF v_queue.id IS NULL THEN
    RETURN QUERY SELECT false, 'Queue item not found or unauthorized'::text;
    RETURN;
  END IF;

  -- Check if already completed or claimed
  IF v_queue.is_completed OR v_queue.claimed THEN
    RETURN QUERY SELECT false, 'Cannot cancel completed or claimed item'::text;
    RETURN;
  END IF;

  -- Delete from queue (NO REFUND - as per requirement)
  DELETE FROM public.craft_queue WHERE id = p_queue_item_id;

  RETURN QUERY SELECT true, 'Craft cancelled (items NOT refunded)'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_craft_item(uuid) TO authenticated;

-- ====================================================================
-- Verification
-- ====================================================================
-- SELECT proname, pronargs FROM pg_proc WHERE proname = 'get_craft_recipes' OR proname = 'cancel_craft_item';
