-- ====================================================================
-- RPC: swap_inventory_bank
-- Swap or merge items between inventory and bank slots
-- Deploy this to Supabase SQL Editor
-- ====================================================================

DROP FUNCTION IF EXISTS public.swap_inventory_bank(text, uuid, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.swap_inventory_bank(text, uuid, text, uuid, integer) CASCADE;
DROP FUNCTION IF EXISTS public.swap_inventory_bank(text, uuid, text, uuid, integer, integer) CASCADE;

CREATE FUNCTION public.swap_inventory_bank(
  p_source_type text,  -- 'inventory' or 'bank'
  p_source_id uuid,    -- inventory row_id or bank_items id
  p_target_type text,  -- 'inventory' or 'bank'
  p_target_id uuid,    -- inventory row_id or bank_items id (NULL if empty slot)
  p_quantity integer DEFAULT NULL,  -- quantity to transfer (NULL = transfer all)
  p_target_slot integer DEFAULT NULL -- target slot index for empty targets
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
  v_source_item_id text;
  v_source_qty integer;
  v_source_slot integer;
  v_target_item_id text;
  v_target_qty integer;
  v_target_slot integer;
  v_max_stack integer;
  v_transfer_qty integer;
  v_remaining_qty integer;
  v_actual_transfer integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text;
    RETURN;
  END IF;

  IF p_source_type = 'inventory' THEN
    SELECT item_id, quantity, slot_position INTO v_source_item_id, v_source_qty, v_source_slot
    FROM public.inventory
    WHERE row_id = p_source_id AND user_id = v_user_id;
  ELSIF p_source_type = 'bank' THEN
    SELECT item_id, quantity, slot_position INTO v_source_item_id, v_source_qty, v_source_slot
    FROM public.bank_items
    WHERE id = p_source_id AND user_id = v_user_id;
  END IF;

  IF v_source_item_id IS NULL THEN
    RETURN QUERY SELECT false, 'Source item not found'::text;
    RETURN;
  END IF;

  v_actual_transfer := COALESCE(p_quantity, v_source_qty);
  v_actual_transfer := LEAST(v_actual_transfer, v_source_qty);
  IF v_actual_transfer <= 0 THEN
    RETURN QUERY SELECT false, 'Invalid transfer quantity'::text;
    RETURN;
  END IF;

  IF p_target_id IS NOT NULL AND p_source_type = p_target_type AND p_source_id = p_target_id THEN
    RETURN QUERY SELECT true, 'Source and target are the same slot'::text;
    RETURN;
  END IF;

  IF p_target_id IS NOT NULL THEN
    IF p_target_type = 'inventory' THEN
      SELECT item_id, quantity, slot_position INTO v_target_item_id, v_target_qty, v_target_slot
      FROM public.inventory
      WHERE row_id = p_target_id AND user_id = v_user_id;
    ELSIF p_target_type = 'bank' THEN
      SELECT item_id, quantity, slot_position INTO v_target_item_id, v_target_qty, v_target_slot
      FROM public.bank_items
      WHERE id = p_target_id AND user_id = v_user_id;
    END IF;
  END IF;

  v_target_slot := COALESCE(v_target_slot, p_target_slot);
  IF v_target_slot IS NULL THEN
    RETURN QUERY SELECT false, 'Target slot is required'::text;
    RETURN;
  END IF;

  SELECT max_stack INTO v_max_stack
  FROM public.items WHERE id = v_source_item_id;
  v_max_stack := COALESCE(v_max_stack, 1);

  IF v_target_item_id IS NOT NULL AND v_target_item_id = v_source_item_id THEN
    v_transfer_qty := LEAST(v_actual_transfer, v_max_stack - v_target_qty);
    IF v_transfer_qty <= 0 THEN
      RETURN QUERY SELECT false, 'Target stack is full'::text;
      RETURN;
    END IF;

    v_remaining_qty := v_source_qty - v_transfer_qty;

    IF p_target_type = 'inventory' THEN
      UPDATE public.inventory SET quantity = quantity + v_transfer_qty, updated_at = now()
      WHERE row_id = p_target_id;
    ELSIF p_target_type = 'bank' THEN
      UPDATE public.bank_items SET quantity = quantity + v_transfer_qty, updated_at = now()
      WHERE id = p_target_id;
    END IF;

    IF v_remaining_qty > 0 THEN
      IF p_source_type = 'inventory' THEN
        UPDATE public.inventory SET quantity = v_remaining_qty, updated_at = now()
        WHERE row_id = p_source_id;
      ELSIF p_source_type = 'bank' THEN
        UPDATE public.bank_items SET quantity = v_remaining_qty, updated_at = now()
        WHERE id = p_source_id;
      END IF;
    ELSE
      IF p_source_type = 'inventory' THEN
        DELETE FROM public.inventory WHERE row_id = p_source_id;
      ELSIF p_source_type = 'bank' THEN
        DELETE FROM public.bank_items WHERE id = p_source_id;
        UPDATE public.user_bank_account
        SET used_slots = GREATEST(0, used_slots - 1), updated_at = now()
        WHERE user_id = v_user_id;
      END IF;
    END IF;

    RETURN QUERY SELECT true, 'Items merged successfully'::text;
    RETURN;
  END IF;

  IF v_target_item_id IS NULL THEN
    IF p_target_type = 'inventory' THEN
      IF EXISTS (
        SELECT 1 FROM public.inventory
        WHERE user_id = v_user_id
          AND is_equipped = FALSE
          AND slot_position = v_target_slot
          AND row_id <> p_source_id
      ) THEN
        RETURN QUERY SELECT false, 'Target inventory slot is occupied'::text;
        RETURN;
      END IF;
    ELSIF p_target_type = 'bank' THEN
      IF EXISTS (
        SELECT 1 FROM public.bank_items
        WHERE user_id = v_user_id
          AND slot_position = v_target_slot
          AND id <> p_source_id
      ) THEN
        RETURN QUERY SELECT false, 'Target bank slot is occupied'::text;
        RETURN;
      END IF;
    END IF;

    IF p_source_type = 'inventory' AND p_target_type = 'bank' THEN
      INSERT INTO public.bank_items (user_id, item_id, quantity, category, slot_position)
      SELECT v_user_id, inv.item_id, v_actual_transfer,
        CASE
          WHEN it.type = 'equipment' THEN 'equipment'
          WHEN it.type = 'consumable' THEN 'consumable'
          WHEN it.type = 'special' THEN 'special'
          ELSE 'material'
        END,
        v_target_slot
      FROM public.inventory inv
      JOIN public.items it ON inv.item_id = it.id
      WHERE inv.row_id = p_source_id;

      IF v_source_qty - v_actual_transfer > 0 THEN
        UPDATE public.inventory SET quantity = v_source_qty - v_actual_transfer, updated_at = now()
        WHERE row_id = p_source_id;
      ELSE
        DELETE FROM public.inventory WHERE row_id = p_source_id;
      END IF;

      UPDATE public.user_bank_account SET used_slots = used_slots + 1, updated_at = now()
      WHERE user_id = v_user_id;

    ELSIF p_source_type = 'bank' AND p_target_type = 'inventory' THEN
      INSERT INTO public.inventory (user_id, item_id, quantity, slot_position)
      SELECT v_user_id, b.item_id, v_actual_transfer, v_target_slot
      FROM public.bank_items b
      WHERE b.id = p_source_id;

      IF v_source_qty - v_actual_transfer > 0 THEN
        UPDATE public.bank_items SET quantity = v_source_qty - v_actual_transfer, updated_at = now()
        WHERE id = p_source_id;
      ELSE
        DELETE FROM public.bank_items WHERE id = p_source_id;
        UPDATE public.user_bank_account
        SET used_slots = GREATEST(0, used_slots - 1), updated_at = now()
        WHERE user_id = v_user_id;
      END IF;

    ELSIF p_source_type = 'inventory' AND p_target_type = 'inventory' THEN
      IF v_actual_transfer < v_source_qty THEN
        RETURN QUERY SELECT false, 'Partial move is only allowed between inventory and bank'::text;
        RETURN;
      END IF;

      UPDATE public.inventory
      SET slot_position = v_target_slot,
          updated_at = now()
      WHERE row_id = p_source_id;

    ELSIF p_source_type = 'bank' AND p_target_type = 'bank' THEN
      IF v_actual_transfer < v_source_qty THEN
        RETURN QUERY SELECT false, 'Partial move is only allowed between inventory and bank'::text;
        RETURN;
      END IF;

      UPDATE public.bank_items
      SET slot_position = v_target_slot,
          updated_at = now()
      WHERE id = p_source_id;
    END IF;

    RETURN QUERY SELECT true, 'Item moved to empty slot'::text;
    RETURN;
  END IF;

  IF v_actual_transfer < v_source_qty THEN
    RETURN QUERY SELECT false, 'Partial swap is not allowed on different items'::text;
    RETURN;
  END IF;

  IF p_source_type = 'inventory' AND p_target_type = 'bank' THEN
    UPDATE public.inventory SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE row_id = p_source_id;

    UPDATE public.bank_items SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE id = p_target_id;
  ELSIF p_source_type = 'bank' AND p_target_type = 'inventory' THEN
    UPDATE public.bank_items SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE id = p_source_id;

    UPDATE public.inventory SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE row_id = p_target_id;
  ELSIF p_source_type = 'inventory' AND p_target_type = 'inventory' THEN
    UPDATE public.inventory SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE row_id = p_source_id;

    UPDATE public.inventory SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE row_id = p_target_id;
  ELSIF p_source_type = 'bank' AND p_target_type = 'bank' THEN
    UPDATE public.bank_items SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE id = p_source_id;

    UPDATE public.bank_items SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE id = p_target_id;
  END IF;

  RETURN QUERY SELECT true, 'Items swapped successfully'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.swap_inventory_bank(text, uuid, text, uuid, integer, integer) TO authenticated;
