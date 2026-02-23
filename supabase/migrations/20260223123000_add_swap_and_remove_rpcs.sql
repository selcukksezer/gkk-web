-- Migration: Add swap_slots and remove_inventory_item_by_row RPCs
-- Creates: public.swap_slots(p_from_slot int, p_to_slot int)
--          public.remove_inventory_item_by_row(p_row_id uuid)

-- Swap two slot positions for the authenticated user.
-- Uses a temporary placeholder to avoid unique-index collisions.
CREATE OR REPLACE FUNCTION public.swap_slots(p_from_slot int, p_to_slot int)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_a_row uuid;
  v_b_row uuid;
  v_tmp int := -999999999; -- placeholder outside normal slot range
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_from_slot IS NULL OR p_to_slot IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid slot args');
  END IF;

  IF p_from_slot = p_to_slot THEN
    RETURN jsonb_build_object('success', true, 'note', 'no-op');
  END IF;

  -- Lock involved rows for this user
  SELECT row_id INTO v_a_row FROM public.inventory
    WHERE user_id = v_user_id AND slot_position = p_from_slot
    LIMIT 1 FOR UPDATE;

  SELECT row_id INTO v_b_row FROM public.inventory
    WHERE user_id = v_user_id AND slot_position = p_to_slot
    LIMIT 1 FOR UPDATE;

  -- Both rows exist: swap via temporary placeholder
  IF v_a_row IS NOT NULL AND v_b_row IS NOT NULL THEN
    UPDATE public.inventory SET slot_position = v_tmp WHERE row_id = v_a_row;
    UPDATE public.inventory SET slot_position = p_from_slot WHERE row_id = v_b_row;
    UPDATE public.inventory SET slot_position = p_to_slot WHERE slot_position = v_tmp AND user_id = v_user_id;
    RETURN jsonb_build_object('success', true);
  END IF;

  -- Only A exists
  IF v_a_row IS NOT NULL AND v_b_row IS NULL THEN
    UPDATE public.inventory SET slot_position = p_to_slot, updated_at = NOW()
      WHERE row_id = v_a_row;
    RETURN jsonb_build_object('success', true);
  END IF;

  -- Only B exists
  IF v_a_row IS NULL AND v_b_row IS NOT NULL THEN
    UPDATE public.inventory SET slot_position = p_from_slot, updated_at = NOW()
      WHERE row_id = v_b_row;
    RETURN jsonb_build_object('success', true);
  END IF;

  -- Neither exists
  RETURN jsonb_build_object('success', false, 'error', 'No items at given slots');
EXCEPTION WHEN others THEN
  -- Bubble up the error so deployment logs capture it
  RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.swap_slots(int,int) TO authenticated, anon, service_role;

-- Remove an inventory row by row_id with ownership check (alias/wrapper used by the client)
CREATE OR REPLACE FUNCTION public.remove_inventory_item_by_row(p_row_id uuid, p_quantity int DEFAULT 1)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_current_qty int;
  v_deleted int := 0;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Get current quantity
  SELECT quantity INTO v_current_qty
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user;

  IF v_current_qty IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned');
  END IF;

  -- If quantity to delete >= current quantity, delete the entire row
  IF p_quantity >= v_current_qty THEN
    DELETE FROM public.inventory
    WHERE row_id = p_row_id AND user_id = v_user;
    RETURN jsonb_build_object('success', true);
  END IF;

  -- Otherwise, reduce the quantity
  UPDATE public.inventory
  SET quantity = quantity - p_quantity, updated_at = NOW()
  WHERE row_id = p_row_id AND user_id = v_user;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_inventory_item_by_row(uuid) TO authenticated, anon, service_role;
