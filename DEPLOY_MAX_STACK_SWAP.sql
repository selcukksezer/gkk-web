-- ====================================================================
-- DEPLOYMENT: Max Stack + Swap System
-- Deploy this SQL to Supabase for:
-- 1. deposit_to_bank with max_stack support
-- 2. withdraw_from_bank with max_stack support
-- 3. NEW: swap_inventory_bank for slot-based drag-drop
-- ====================================================================

-- Clean up ALL old function versions first
DROP FUNCTION IF EXISTS public.deposit_to_bank(uuid[]) CASCADE;
DROP FUNCTION IF EXISTS public.deposit_to_bank(uuid[], integer[]) CASCADE;
DROP FUNCTION IF EXISTS public.withdraw_from_bank(uuid[]) CASCADE;
DROP FUNCTION IF EXISTS public.swap_inventory_bank(text, uuid, text, uuid) CASCADE;

-- Step 1: Update deposit_to_bank

CREATE FUNCTION public.deposit_to_bank(p_item_row_ids uuid[], p_quantities integer[] DEFAULT NULL)
RETURNS TABLE (
  success boolean,
  message text,
  items_deposited integer,
  new_used_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_deposit_count integer := 0;
  v_used_slots integer;
  v_max_slots integer;
  v_item_row uuid;
  v_quantity integer;
  v_idx integer := 1;
  v_inv_quantity integer;
  v_max_stack integer;
  v_existing_bank_qty integer;
  v_can_stack integer;
  v_will_deposit integer;
  v_will_remain integer;
  v_item_id text;
  v_item_category text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Ensure bank account exists
  INSERT INTO public.user_bank_account (user_id) 
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Get current bank status
  SELECT total_slots, used_slots 
  INTO v_max_slots, v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  -- Move each inventory item to bank (respecting max_stack)
  FOREACH v_item_row IN ARRAY p_item_row_ids
  LOOP
    -- Get inventory item details
    SELECT inv.item_id, inv.quantity INTO v_item_id, v_inv_quantity
    FROM public.inventory inv
    WHERE inv.row_id = v_item_row AND inv.user_id = v_user_id;

    IF v_item_id IS NULL THEN
      CONTINUE; -- Skip if not found
    END IF;

    -- Get item max_stack and category
    SELECT max_stack, 
      CASE
        WHEN type = 'equipment' THEN 'equipment'
        WHEN type = 'consumable' THEN 'consumable'
        WHEN type = 'special' THEN 'special'
        ELSE 'material'
      END
    INTO v_max_stack, v_item_category
    FROM public.items
    WHERE id = v_item_id;

    -- Default max_stack to 1 if not set (equipment, non-stackable)
    v_max_stack := COALESCE(v_max_stack, 1);

    -- Get quantity to deposit: use p_quantities[v_idx] if available, else use all
    v_quantity := COALESCE(p_quantities[v_idx], v_inv_quantity);
    v_quantity := LEAST(v_quantity, v_inv_quantity); -- Can't deposit more than we have

    -- Check existing bank quantity for this item
    SELECT COALESCE(SUM(quantity), 0) INTO v_existing_bank_qty
    FROM public.bank_items
    WHERE user_id = v_user_id AND item_id = v_item_id;

    -- Calculate how much we can deposit (respecting max_stack)
    v_can_stack := v_max_stack - v_existing_bank_qty;
    
    IF v_can_stack <= 0 THEN
      -- Bank stack is full, skip this item
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    -- Determine how much to actually deposit
    v_will_deposit := LEAST(v_quantity, v_can_stack);
    v_will_remain := v_inv_quantity - v_will_deposit;

    -- Check bank slot capacity (only count if we're creating a new slot)
    IF v_existing_bank_qty = 0 AND v_used_slots >= v_max_slots THEN
      -- No existing bank item and bank is full
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    -- Deposit: either update existing bank item or insert new one
    IF v_existing_bank_qty > 0 THEN
      -- Item exists in bank, just update quantity
      UPDATE public.bank_items
      SET quantity = quantity + v_will_deposit,
          updated_at = now()
      WHERE user_id = v_user_id AND item_id = v_item_id;
    ELSE
      -- New item in bank
      INSERT INTO public.bank_items (user_id, item_id, category, slot_position, quantity)
      VALUES (v_user_id, v_item_id, v_item_category,
        (SELECT COUNT(*) FROM public.bank_items WHERE user_id = v_user_id),
        v_will_deposit);
      v_deposit_count := v_deposit_count + 1;
    END IF;

    -- Update inventory quantity or delete if none remaining
    UPDATE public.inventory
    SET quantity = v_will_remain
    WHERE row_id = v_item_row;

    -- Delete if quantity now 0
    DELETE FROM public.inventory
    WHERE row_id = v_item_row AND quantity <= 0;

    v_idx := v_idx + 1;
  END LOOP;

  -- Update bank used slots (only count new items, not quantity updates)
  UPDATE public.user_bank_account
  SET used_slots = used_slots + v_deposit_count,
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT true, 
    'Deposited successfully'::text, 
    v_deposit_count::integer, 
    (v_used_slots + v_deposit_count)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deposit_to_bank(uuid[], integer[]) TO authenticated;

-- Step 2: Update withdraw_from_bank
DROP FUNCTION IF EXISTS public.withdraw_from_bank(uuid[]);

CREATE FUNCTION public.withdraw_from_bank(p_bank_item_ids uuid[])
RETURNS TABLE (
  success boolean,
  message text,
  items_withdrawn integer,
  new_used_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_withdraw_count integer := 0;
  v_used_slots integer;
  v_bank_item_id uuid;
  v_item_id text;
  v_bank_quantity integer;
  v_max_stack integer;
  v_existing_inv_qty integer;
  v_can_stack integer;
  v_will_withdraw integer;
  v_will_remain integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Get current bank status
  SELECT used_slots 
  INTO v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  -- Move each bank item to inventory (respecting max_stack)
  FOREACH v_bank_item_id IN ARRAY p_bank_item_ids
  LOOP
    -- Get bank item details
    SELECT item_id, quantity INTO v_item_id, v_bank_quantity
    FROM public.bank_items
    WHERE id = v_bank_item_id AND user_id = v_user_id;

    IF v_item_id IS NULL THEN
      CONTINUE; -- Skip if not found
    END IF;

    -- Get item max_stack
    SELECT max_stack INTO v_max_stack
    FROM public.items
    WHERE id = v_item_id;

    -- Default max_stack to 1 if not set
    v_max_stack := COALESCE(v_max_stack, 1);

    -- Check existing inventory quantity for this item
    SELECT COALESCE(SUM(quantity), 0) INTO v_existing_inv_qty
    FROM public.inventory
    WHERE user_id = v_user_id 
      AND item_id = v_item_id 
      AND is_equipped = FALSE;

    -- Calculate how much we can add (respecting max_stack)
    v_can_stack := v_max_stack - v_existing_inv_qty;
    
    IF v_can_stack <= 0 THEN
      -- Inventory stack is full, skip this item
      CONTINUE;
    END IF;

    -- Determine how much to actually withdraw
    v_will_withdraw := LEAST(v_bank_quantity, v_can_stack);
    v_will_remain := v_bank_quantity - v_will_withdraw;

    -- Withdraw: either update existing inventory item or insert new one
    IF v_existing_inv_qty > 0 THEN
      -- Item exists in inventory, just update quantity
      UPDATE public.inventory
      SET quantity = quantity + v_will_withdraw,
          updated_at = now()
      WHERE user_id = v_user_id 
        AND item_id = v_item_id 
        AND is_equipped = FALSE;
    ELSE
      -- New item in inventory, find next available slot
      INSERT INTO public.inventory (user_id, item_id, quantity, is_equipped, equip_slot, slot_position)
      SELECT v_user_id, v_item_id, v_will_withdraw, false, 'none',
        (SELECT MIN(slot_num)
         FROM generate_series(0, 19) AS t(slot_num)
         WHERE NOT EXISTS (
           SELECT 1 FROM public.inventory
           WHERE user_id = v_user_id AND slot_position = t.slot_num AND is_equipped = FALSE
         ));
    END IF;

    -- Update or delete bank item
    IF v_will_remain > 0 THEN
      UPDATE public.bank_items
      SET quantity = v_will_remain,
          updated_at = now()
      WHERE id = v_bank_item_id;
    ELSE
      DELETE FROM public.bank_items WHERE id = v_bank_item_id;
      v_withdraw_count := v_withdraw_count + 1;
    END IF;
  END LOOP;

  -- Update bank used slots (only count deleted items, not quantity changes)
  UPDATE public.user_bank_account
  SET used_slots = GREATEST(0, used_slots - v_withdraw_count),
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT true,
    'Withdrawn successfully'::text,
    v_withdraw_count::integer,
    GREATEST(0, v_used_slots - v_withdraw_count)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.withdraw_from_bank(uuid[]) TO authenticated;

-- Step 3: NEW RPC - swap_inventory_bank (for slot-based drag-drop)
DROP FUNCTION IF EXISTS public.swap_inventory_bank(text, uuid, text, uuid);
DROP FUNCTION IF EXISTS public.swap_inventory_bank(text, uuid, text, uuid, integer);
DROP FUNCTION IF EXISTS public.swap_inventory_bank(text, uuid, text, uuid, integer, integer);

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
