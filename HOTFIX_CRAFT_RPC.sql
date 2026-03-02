-- HOTFIX: craft_item_async dengan material deduction
-- Deploy ini untuk memperbaiki:
-- 1. Function signature conflict (craft_item_async already exists)
-- 2. Material tidak berkurang saat craft

-- ====================================================================
-- STEP 1: DROP semua versi craft_item_async
-- ====================================================================
DROP FUNCTION IF EXISTS public.craft_item_async(uuid, uuid, integer);
DROP FUNCTION IF EXISTS public.craft_item_async(uuid, integer);

-- ====================================================================
-- STEP 2: CREATE craft_item_async dengan material deduction logic
-- ====================================================================
CREATE FUNCTION public.craft_item_async(
  p_recipe_id uuid,
  p_batch_count integer DEFAULT 1
)
RETURNS TABLE (
  success boolean,
  queue_item_id uuid,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_recipe crafting_recipes%ROWTYPE;
  v_queue_item craft_queue%ROWTYPE;
  v_completes_at timestamp with time zone;
  v_ingredient_item RECORD;
  v_required_qty integer;
  v_owned_qty integer;
  v_final_qty integer;
BEGIN
  -- Verify user is authenticated
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Not authenticated'::text;
    RETURN;
  END IF;

  -- Fetch recipe
  SELECT * FROM public.crafting_recipes WHERE id = p_recipe_id INTO v_recipe;
  IF v_recipe.id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Recipe not found'::text;
    RETURN;
  END IF;

  -- Verify materials exist before deducting
  IF v_recipe.ingredients IS NOT NULL AND v_recipe.ingredients != 'null'::jsonb THEN
    FOR v_ingredient_item IN
      SELECT 
        jsonb_array_elements(v_recipe.ingredients) ->> 'item_id' as item_id,
        (jsonb_array_elements(v_recipe.ingredients) ->> 'quantity')::integer as quantity
    LOOP
      v_required_qty := (v_ingredient_item.quantity * p_batch_count);
      
      SELECT COALESCE(SUM(quantity), 0) INTO v_owned_qty
      FROM public.inventory
      WHERE user_id = v_user_id AND item_id = v_ingredient_item.item_id;
      
      IF v_owned_qty < v_required_qty THEN
        RETURN QUERY SELECT false, NULL::uuid, 
          'Insufficient material: ' || v_ingredient_item.item_id || ' (need ' || v_required_qty || ', have ' || v_owned_qty || ')'::text;
        RETURN;
      END IF;
    END LOOP;
  END IF;

  -- Deduct materials from inventory (FIFO: oldest first)
  IF v_recipe.ingredients IS NOT NULL AND v_recipe.ingredients != 'null'::jsonb THEN
    FOR v_ingredient_item IN
      SELECT 
        jsonb_array_elements(v_recipe.ingredients) ->> 'item_id' as item_id,
        (jsonb_array_elements(v_recipe.ingredients) ->> 'quantity')::integer as quantity
    LOOP
      v_required_qty := (v_ingredient_item.quantity * p_batch_count);
      
      -- Deduct quantities from inventory in FIFO order (handle stacks)
      DECLARE
        v_remaining integer := v_required_qty;
        v_row RECORD;
        v_take integer;
      BEGIN
        FOR v_row IN
          SELECT row_id, quantity FROM public.inventory
          WHERE user_id = v_user_id AND item_id = v_ingredient_item.item_id
          ORDER BY created_at ASC
        LOOP
          EXIT WHEN v_remaining <= 0;
          v_take := LEAST(v_row.quantity, v_remaining);
          IF v_row.quantity > v_take THEN
            UPDATE public.inventory
            SET quantity = quantity - v_take, updated_at = now()
            WHERE row_id = v_row.row_id;
          ELSE
            DELETE FROM public.inventory WHERE row_id = v_row.row_id;
          END IF;
          v_remaining := v_remaining - v_take;
        END LOOP;
      END;
    END LOOP;
  END IF;

  -- Calculate completion time
  v_completes_at := now() + (v_recipe.production_time_seconds * p_batch_count) * INTERVAL '1 second';

  -- Insert into craft queue
  INSERT INTO public.craft_queue (user_id, recipe_id, batch_count, completes_at, is_completed, claimed)
  VALUES (v_user_id, p_recipe_id, p_batch_count, v_completes_at, false, false)
  RETURNING * INTO v_queue_item;

  RETURN QUERY SELECT true, v_queue_item.id, 'Craft started'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.craft_item_async(uuid, integer) TO authenticated;

-- ====================================================================
-- STEP 3: DROP ve recreate claim_crafted_item (ensure clean state)
-- ====================================================================
DROP FUNCTION IF EXISTS public.claim_crafted_item(uuid, uuid);
DROP FUNCTION IF EXISTS public.claim_crafted_item(uuid);

CREATE FUNCTION public.claim_crafted_item(
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
  v_recipe crafting_recipes%ROWTYPE;
  v_final_qty integer;
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

  -- Check if already claimed
  IF v_queue.claimed THEN
    RETURN QUERY SELECT false, 'Already claimed'::text;
    RETURN;
  END IF;

  -- Fetch recipe to get output item
  SELECT * FROM public.crafting_recipes WHERE id = v_queue.recipe_id INTO v_recipe;
  -- Ensure the item is completed (either marked or time has passed)
  IF NOT v_queue.is_completed AND v_queue.completes_at > now() THEN
    RETURN QUERY SELECT false, 'Not ready to claim'::text;
    RETURN;
  END IF;

  -- Compute final quantity to add (use batch_count; crafting_recipes may not define output_quantity)
  v_final_qty := COALESCE(v_queue.batch_count, 1) * 1;

  -- Add produced item to inventory via helper (handles stackable / slots / full inventory)
  DECLARE v_add_res jsonb;
  BEGIN
    -- Validate output_item_id exists
    IF v_recipe.output_item_id IS NULL OR length(coalesce(v_recipe.output_item_id::text, '')) = 0 THEN
      RETURN QUERY SELECT false, 'Recipe has no output_item_id'::text;
      RETURN;
    END IF;

    v_add_res := public.add_inventory_item_v2(jsonb_build_object('item_id', v_recipe.output_item_id, 'quantity', v_final_qty, 'allow_stack', true), NULL);
    IF v_add_res IS NULL OR (v_add_res->>'success')::boolean IS NOT TRUE THEN
      RETURN QUERY SELECT false, COALESCE(v_add_res->>'error', 'Failed to add to inventory')::text;
      RETURN;
    END IF;

    -- Remove queue item after successful claim
    DELETE FROM public.craft_queue WHERE id = p_queue_item_id;

    RETURN QUERY SELECT true, 'Item claimed and added to inventory'::text;
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_crafted_item(uuid) TO authenticated;

-- ====================================================================
-- VERIFICATION: Check functions are deployed
-- ====================================================================
-- Run these to verify:
-- SELECT prosname, pronargs FROM pg_proc WHERE prosname LIKE 'craft_item%' OR prosname LIKE 'claim_crafted%';
