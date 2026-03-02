-- HOTFIX: claim_crafted_item RPC — üretimi talep ederken envantere stackleme kurallarına göre ekleme
-- Bu hotfix'i Supabase SQL Editor veya CLI ile çalıştırın

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
  v_add_res jsonb;
  v_is_stackable boolean;
  v_free_slots integer;
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

  -- Validate output_item_id exists before attempting inventory add
  IF v_recipe.output_item_id IS NULL OR trim(v_recipe.output_item_id) = '' THEN
    RETURN QUERY SELECT false, 'Recipe output_item_id is missing'::text;
    RETURN;
  END IF;

  -- Compute final quantity to add (use batch_count)
  v_final_qty := COALESCE(v_queue.batch_count, 1);

  -- Determine if item is stackable from catalog
  SELECT is_stackable INTO v_is_stackable FROM public.items WHERE id = v_recipe.output_item_id;
  IF v_is_stackable IS NULL THEN
    v_is_stackable := false;
  END IF;

  -- Add produced item to inventory: for non-stackable ensure enough free slots first
  IF v_is_stackable THEN
    v_add_res := public.add_inventory_item_v2(
      jsonb_build_object('item_id', v_recipe.output_item_id, 'quantity', v_final_qty, 'allow_stack', true),
      NULL
    );

    IF v_add_res IS NULL OR (v_add_res->>'success')::boolean IS NOT TRUE THEN
      RETURN QUERY SELECT false, COALESCE(v_add_res->>'error', 'Failed to add to inventory')::text;
      RETURN;
    END IF;
  ELSE
    -- Check free slots
    SELECT COUNT(*) INTO v_free_slots
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = v_user_id AND slot_position = s.slot AND is_equipped = false
    );

    IF v_free_slots < GREATEST(1, v_final_qty) THEN
      RETURN QUERY SELECT false, 'Envanter dolu'::text;
      RETURN;
    END IF;

    FOR i IN 1..GREATEST(1, v_final_qty) LOOP
      v_add_res := public.add_inventory_item_v2(
        jsonb_build_object('item_id', v_recipe.output_item_id, 'quantity', 1, 'allow_stack', false),
        NULL
      );
      IF v_add_res IS NULL OR (v_add_res->>'success')::boolean IS NOT TRUE THEN
        RETURN QUERY SELECT false, COALESCE(v_add_res->>'error', 'Failed to add non-stackable item to inventory')::text;
        RETURN;
      END IF;
    END LOOP;
  END IF;

  -- Remove queue item after successful claim
  DELETE FROM public.craft_queue WHERE id = p_queue_item_id;

  RETURN QUERY SELECT true, 'Item claimed and added to inventory'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_crafted_item(uuid) TO authenticated;
