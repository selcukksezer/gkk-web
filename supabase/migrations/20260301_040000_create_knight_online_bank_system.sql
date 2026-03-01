-- Migration: Knight Online style bank system with free/paid slots
-- Generated: 2026-03-01 04:00:00
-- Features: 100 free slots, paid expansion, separate categories, transaction history

-- ====================================================================
-- TABLE: user_bank_account (Main bank account)
-- ====================================================================
DROP TABLE IF EXISTS public.bank_transactions CASCADE;
DROP TABLE IF EXISTS public.bank_items CASCADE;
DROP TABLE IF EXISTS public.user_bank_account CASCADE;

CREATE TABLE public.user_bank_account (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL UNIQUE,
  
  -- Storage capacity (100 free, max 200 total)
  total_slots integer NOT NULL DEFAULT 100,
  used_slots integer NOT NULL DEFAULT 0,
  free_slots_remaining integer NOT NULL DEFAULT 100,
  paid_slots_purchased integer NOT NULL DEFAULT 0,
  
  -- Account status
  last_accessed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT user_bank_account_pkey PRIMARY KEY (id),
  CONSTRAINT user_bank_account_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE,
  CONSTRAINT valid_slot_limits CHECK (total_slots BETWEEN 100 AND 200),
  CONSTRAINT valid_slots CHECK (used_slots <= total_slots)
);

CREATE INDEX idx_bank_account_user_id ON public.user_bank_account (user_id);

-- ====================================================================
-- TABLE: bank_items (Items stored in bank, grouped by category)
-- ====================================================================
CREATE TABLE public.bank_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  item_id text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  
  -- Category: 'equipment' | 'material' | 'consumable' | 'special'
  category text NOT NULL DEFAULT 'material',
  
  -- Rarity for display
  rarity text DEFAULT 'common',
  
  -- Slot position in bank UI (0-199)
  slot_position integer CHECK (slot_position >= 0 AND slot_position < 200),
  
  -- Pinned items stay at top
  is_pinned boolean DEFAULT false,
  pinned_at timestamp with time zone,
  
  stored_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT bank_items_pkey PRIMARY KEY (id),
  CONSTRAINT bank_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE,
  CONSTRAINT bank_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items (id) ON DELETE RESTRICT
);

CREATE INDEX idx_bank_items_user_id ON public.bank_items (user_id);
CREATE INDEX idx_bank_items_category ON public.bank_items (user_id, category);
CREATE INDEX idx_bank_items_is_pinned ON public.bank_items (user_id, is_pinned) WHERE is_pinned = true;

-- ====================================================================
-- TABLE: bank_transactions (History log for auditing)
-- ====================================================================
CREATE TABLE public.bank_transactions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  
  -- Transaction type: 'deposit' | 'withdraw' | 'expand' | 'organize'
  transaction_type text NOT NULL,
  
  -- Details about transaction
  item_id text,
  quantity_moved integer,
  category text,
  
  -- Cost if expansion
  gem_cost integer,
  gems_before integer,
  gems_after integer,
  
  -- Slot info
  slots_before integer,
  slots_after integer,
  
  success boolean DEFAULT true,
  error_message text,
  
  created_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT bank_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT bank_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE
);

CREATE INDEX idx_bank_transactions_user_id ON public.bank_transactions (user_id, created_at DESC);

-- ====================================================================
-- RPC: get_bank_account
-- Get user's bank status with all details
-- ====================================================================
DROP FUNCTION IF EXISTS public.get_bank_account();

CREATE FUNCTION public.get_bank_account()
RETURNS TABLE (
  account_id uuid,
  total_slots integer,
  used_slots integer,
  free_slots_remaining integer,
  paid_slots_purchased integer,
  expansion_cost_next integer,
  can_expand boolean,
  last_accessed_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_bank_id uuid;
  v_total integer;
  v_used integer;
  v_expansion_cost integer;
  v_free_slots_remaining integer;
  v_paid_slots_purchased integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Ensure bank account exists
  INSERT INTO public.user_bank_account (user_id) 
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Get current account status
  SELECT 
    uba.id, uba.total_slots, uba.used_slots, uba.free_slots_remaining, uba.paid_slots_purchased,
    CASE 
      WHEN uba.total_slots >= 200 THEN 0
      WHEN uba.total_slots >= 175 THEN 500
      WHEN uba.total_slots >= 150 THEN 300
      WHEN uba.total_slots >= 125 THEN 200
      ELSE 50
    END
  INTO v_bank_id, v_total, v_used, v_free_slots_remaining, v_paid_slots_purchased, v_expansion_cost
  FROM public.user_bank_account uba
  WHERE uba.user_id = v_user_id;

  -- Update last accessed
  UPDATE public.user_bank_account
  SET last_accessed_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT
    v_bank_id,
    v_total,
    v_used,
    v_free_slots_remaining,
    v_paid_slots_purchased,
    v_expansion_cost,
    (v_total < 200)::boolean,
    now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_bank_account() TO authenticated;

-- ====================================================================
-- RPC: get_bank_items
-- Get user's stored items grouped by category
-- ====================================================================
DROP FUNCTION IF EXISTS public.get_bank_items(text);

CREATE FUNCTION public.get_bank_items(p_category text DEFAULT NULL)
RETURNS TABLE (
  items jsonb,
  categories jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_items jsonb;
  v_categories jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get items (filter by category if provided)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', bi.id::text,
    'item_id', bi.item_id,
    'name', i.name,
    'type', i.type,
    'rarity', bi.rarity,
    'icon', i.icon,
    'quantity', bi.quantity,
    'category', bi.category,
    'is_pinned', bi.is_pinned,
    'slot_position', bi.slot_position
  ) ORDER BY bi.is_pinned DESC, bi.stored_at DESC), '[]'::jsonb)
  INTO v_items
  FROM public.bank_items bi
  LEFT JOIN public.items i ON bi.item_id = i.id
  WHERE bi.user_id = v_user_id
    AND (p_category IS NULL OR bi.category = p_category);

  -- Get category summary
  SELECT jsonb_object_agg(category, cnt)
  INTO v_categories
  FROM (
    SELECT category, COUNT(*) as cnt
    FROM public.bank_items
    WHERE user_id = v_user_id
    GROUP BY category
  ) cat_counts;

  IF v_categories IS NULL THEN
    v_categories := '{"equipment": 0, "material": 0, "consumable": 0, "special": 0}'::jsonb;
  END IF;

  RETURN QUERY SELECT v_items, v_categories;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_bank_items(text) TO authenticated;

-- ====================================================================
-- RPC: deposit_to_bank
-- Move items from inventory to bank (respects max_stack from items table)
-- ====================================================================
DROP FUNCTION IF EXISTS public.deposit_to_bank(uuid[]) CASCADE;
DROP FUNCTION IF EXISTS public.deposit_to_bank(uuid[], integer[]) CASCADE;

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

-- ====================================================================
-- RPC: withdraw_from_bank
-- Move items from bank to inventory (respects max_stack from items table)
-- ====================================================================
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

-- ====================================================================
-- RPC: expand_bank_slots
-- Purchase additional bank slots with gems
-- ====================================================================
DROP FUNCTION IF EXISTS public.expand_bank_slots(integer);

CREATE FUNCTION public.expand_bank_slots(p_num_expansions integer DEFAULT 1)
RETURNS TABLE (
  success boolean,
  message text,
  total_gems_spent integer,
  new_total_slots integer,
  player_gems_remaining integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_current_slots integer;
  v_total_cost integer := 0;
  v_new_slots integer;
  v_current_gems integer;
  i integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Get current bank and player gem status
  SELECT total_slots INTO v_current_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  SELECT gems INTO v_current_gems
  FROM public.users
  WHERE auth_id = v_user_id;

  -- Check if at max capacity
  IF v_current_slots >= 200 THEN
    RETURN QUERY SELECT false, 'Bank at maximum capacity (200 slots)'::text, 0::integer, 200::integer, v_current_gems;
    RETURN;
  END IF;

  -- Calculate total cost for all expansions
  -- Each 25 slots: 50 gems (125-100), 100 gems (150-125), 200 gems (175-150), 500 gems (200-175)
  FOR i IN 1..p_num_expansions LOOP
    EXIT WHEN v_current_slots + (i * 25) >= 200;
    
    v_total_cost := v_total_cost + CASE 
      WHEN v_current_slots + (i * 25) = 125 THEN 50
      WHEN v_current_slots + (i * 25) = 150 THEN 100
      WHEN v_current_slots + (i * 25) = 175 THEN 200
      WHEN v_current_slots + (i * 25) = 200 THEN 500
      ELSE 50
    END;
  END LOOP;

  -- Check if player has enough gems
  IF v_total_cost > v_current_gems THEN
    RETURN QUERY SELECT false, 
      'Insufficient gems. Need ' || v_total_cost || ', have ' || v_current_gems::text, 
      0::integer, 
      v_current_slots::integer, 
      v_current_gems;
    RETURN;
  END IF;

  -- Deduct gems from player profile
  UPDATE public.users
  SET gems = gems - v_total_cost
  WHERE auth_id = v_user_id;

  -- Update bank slots
  v_new_slots := LEAST(v_current_slots + (p_num_expansions * 25), 200);
  UPDATE public.user_bank_account
  SET total_slots = v_new_slots,
      paid_slots_purchased = paid_slots_purchased + (v_new_slots - v_current_slots),
      updated_at = now()
  WHERE user_id = v_user_id;

  -- Log transaction
  INSERT INTO public.bank_transactions 
    (user_id, transaction_type, gem_cost, gems_before, gems_after, slots_before, slots_after, success)
  VALUES (v_user_id, 'expand', v_total_cost, v_current_gems, v_current_gems - v_total_cost, v_current_slots, v_new_slots, true);

  RETURN QUERY SELECT true,
    'Expanded by ' || (v_new_slots - v_current_slots) || ' slots for ' || v_total_cost || ' gems'::text,
    v_total_cost::integer,
    v_new_slots::integer,
    (v_current_gems - v_total_cost)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.expand_bank_slots(integer) TO authenticated;

-- ====================================================================
-- RPC: organize_bank
-- Pin/unpin or reorganize bank items
-- ====================================================================
DROP FUNCTION IF EXISTS public.organize_bank(uuid, boolean);

CREATE FUNCTION public.organize_bank(p_item_id uuid, p_pin boolean)
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
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text;
    RETURN;
  END IF;

  UPDATE public.bank_items
  SET is_pinned = p_pin,
      pinned_at = CASE WHEN p_pin THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_item_id AND user_id = v_user_id;

  RETURN QUERY SELECT true, 
    CASE WHEN p_pin THEN 'Item pinned' ELSE 'Item unpinned' END::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.organize_bank(uuid, boolean) TO authenticated;

-- ====================================================================
-- RPC: swap_inventory_bank
-- Swap or merge items between inventory and bank slots
-- Respects max_stack: if same item, partial merge; if different, swap positions
-- ====================================================================
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

  -- Get source item details
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

  -- Determine actual transfer quantity (limited by p_quantity if provided)
  v_actual_transfer := COALESCE(p_quantity, v_source_qty);
  v_actual_transfer := LEAST(v_actual_transfer, v_source_qty); -- Can't transfer more than we have
  IF v_actual_transfer <= 0 THEN
    RETURN QUERY SELECT false, 'Invalid transfer quantity'::text;
    RETURN;
  END IF;

  IF p_target_id IS NOT NULL AND p_source_type = p_target_type AND p_source_id = p_target_id THEN
    RETURN QUERY SELECT true, 'Source and target are the same slot'::text;
    RETURN;
  END IF;

  -- Get target item details (if exists)
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

  -- Get max_stack for both items
  SELECT max_stack INTO v_max_stack
  FROM public.items WHERE id = v_source_item_id;
  v_max_stack := COALESCE(v_max_stack, 1);

  -- Same item: merge (respecting partial quantity)
  IF v_target_item_id IS NOT NULL AND v_target_item_id = v_source_item_id THEN
    -- Same item: try to merge (limited by p_quantity if provided)
    v_transfer_qty := LEAST(v_actual_transfer, v_max_stack - v_target_qty);
    IF v_transfer_qty <= 0 THEN
      RETURN QUERY SELECT false, 'Target stack is full'::text;
      RETURN;
    END IF;

    v_remaining_qty := v_source_qty - v_transfer_qty;

    -- Update target: add quantity
    IF p_target_type = 'inventory' THEN
      UPDATE public.inventory SET quantity = quantity + v_transfer_qty, updated_at = now()
      WHERE row_id = p_target_id;
    ELSIF p_target_type = 'bank' THEN
      UPDATE public.bank_items SET quantity = quantity + v_transfer_qty, updated_at = now()
      WHERE id = p_target_id;
    END IF;

    -- Update source: reduce or delete
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

  -- Empty target slot
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

      -- Update or delete from inventory
      IF v_source_qty - v_actual_transfer > 0 THEN
        UPDATE public.inventory SET quantity = v_source_qty - v_actual_transfer, updated_at = now()
        WHERE row_id = p_source_id;
      ELSE
        DELETE FROM public.inventory WHERE row_id = p_source_id;
      END IF;
      
      -- New bank slot always created
      UPDATE public.user_bank_account SET used_slots = used_slots + 1, updated_at = now()
      WHERE user_id = v_user_id;

    ELSIF p_source_type = 'bank' AND p_target_type = 'inventory' THEN
      INSERT INTO public.inventory (user_id, item_id, quantity, slot_position)
      SELECT v_user_id, b.item_id, v_actual_transfer, v_target_slot
      FROM public.bank_items b
      WHERE b.id = p_source_id;

      -- Update or delete from bank
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

  -- Different items: partial swap is not allowed
  IF v_actual_transfer < v_source_qty THEN
    RETURN QUERY SELECT false, 'Partial swap is not allowed on different items'::text;
    RETURN;
  END IF;

  -- Different items: full swap
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

-- ====================================================================
-- RLS Policies
-- ====================================================================
ALTER TABLE public.user_bank_account ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_can_read_own_bank_account" ON public.user_bank_account;
CREATE POLICY "users_can_read_own_bank_account"
  ON public.user_bank_account FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_can_update_own_bank_account" ON public.user_bank_account;
CREATE POLICY "users_can_update_own_bank_account"
  ON public.user_bank_account FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_can_read_own_bank_items" ON public.bank_items;
CREATE POLICY "users_can_read_own_bank_items"
  ON public.bank_items FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_can_insert_own_bank_items" ON public.bank_items;
CREATE POLICY "users_can_insert_own_bank_items"
  ON public.bank_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_can_delete_own_bank_items" ON public.bank_items;
CREATE POLICY "users_can_delete_own_bank_items"
  ON public.bank_items FOR DELETE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_can_read_own_transactions" ON public.bank_transactions;
CREATE POLICY "users_can_read_own_transactions"
  ON public.bank_transactions FOR SELECT
  USING (auth.uid() = user_id);

GRANT SELECT, UPDATE ON public.user_bank_account TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.bank_items TO authenticated;
GRANT SELECT ON public.bank_transactions TO authenticated;
