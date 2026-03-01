-- Migration: create bank system RPCs
-- Generated: 2026-03-01 03:00:00
-- Purpose: Bank table and RPCs for item storage, expansion, and transfers

-- ====================================================================
-- TABLE: user_bank (if not exists)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.user_bank (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL UNIQUE,
  max_slots integer NOT NULL DEFAULT 50,
  used_slots integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_bank_pkey PRIMARY KEY (id),
  CONSTRAINT user_bank_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE
);

-- ====================================================================
-- TABLE: bank_items (if not exists)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.bank_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  item_id text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT bank_items_pkey PRIMARY KEY (id),
  CONSTRAINT bank_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE,
  CONSTRAINT bank_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items (id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_bank_items_user_id ON public.bank_items (user_id);

-- ====================================================================
-- RPC: get_bank_items
-- Returns user's bank items with metadata
-- ====================================================================
DROP FUNCTION IF EXISTS public.get_bank_items();

CREATE FUNCTION public.get_bank_items()
RETURNS TABLE (
  items jsonb,
  max_slots integer,
  used_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_max_slots integer;
  v_used_slots integer;
  v_bank jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Ensure user_bank entry exists
  INSERT INTO public.user_bank (user_id) VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;
  -- Get user's bank capacity
  SELECT max_slots INTO v_max_slots
  FROM public.user_bank
  WHERE user_id = v_user_id
  LIMIT 1;

  -- Compute used slots (number of items stored)
  SELECT COALESCE(COUNT(*),0) INTO v_used_slots
  FROM public.bank_items
  WHERE user_id = v_user_id;

  -- Build items JSON array
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', bi.id::text,
      'item_id', bi.item_id,
      'name', i.name,
      'type', i.item_type,
      'rarity', i.rarity,
      'quantity', bi.quantity
    ) ORDER BY bi.created_at DESC), '[]'::jsonb)
  INTO v_bank
  FROM public.bank_items bi
  LEFT JOIN public.items i ON bi.item_id = i.id
  WHERE bi.user_id = v_user_id;

  RETURN QUERY SELECT v_bank, COALESCE(v_max_slots, 0), v_used_slots;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_bank_items() TO authenticated;

-- ====================================================================
-- RPC: expand_bank
-- Expand bank capacity by specified number of slots
-- ====================================================================
DROP FUNCTION IF EXISTS public.expand_bank(integer);

CREATE FUNCTION public.expand_bank(p_slots integer DEFAULT 25)
RETURNS TABLE (
  success boolean,
  message text,
  new_max_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_current_max integer;
  v_expansion_cost integer;
  v_new_max integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer;
    RETURN;
  END IF;

  -- Ensure user_bank entry exists
  INSERT INTO public.user_bank (user_id) VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Get current max slots
  SELECT max_slots INTO v_current_max
  FROM public.user_bank
  WHERE user_id = v_user_id;

  IF v_current_max IS NULL THEN
    RETURN QUERY SELECT false, 'Bank not found'::text, 0::integer;
    RETURN;
  END IF;

  -- Check if already at max (200)
  IF v_current_max >= 200 THEN
    RETURN QUERY SELECT false, 'Maximum capacity reached'::text, v_current_max;
    RETURN;
  END IF;

  -- Calculate cost: 50 gems per 25 slots
  v_expansion_cost := 50;
  v_new_max := v_current_max + p_slots;

  -- TODO: Deduct gems from user profile and verify player has enough gems
  -- For now, just update bank capacity

  UPDATE public.user_bank
  SET max_slots = v_new_max, updated_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT true, 'Bank expanded successfully'::text, v_new_max;
END;
$$;

GRANT EXECUTE ON FUNCTION public.expand_bank(integer) TO authenticated;

-- ====================================================================
-- RPC: deposit_to_bank
-- Move items from inventory to bank
-- ====================================================================
DROP FUNCTION IF EXISTS public.deposit_to_bank(uuid[]);

CREATE FUNCTION public.deposit_to_bank(p_item_row_ids uuid[])
RETURNS TABLE (
  success boolean,
  message text,
  items_deposited integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_deposit_count integer;
  v_item record;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer;
    RETURN;
  END IF;

  -- Ensure user_bank exists
  INSERT INTO public.user_bank (user_id) VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Move inventory items to bank
  FOR v_item IN
    SELECT row_id, item_id FROM public.inventory
    WHERE user_id = v_user_id AND row_id = ANY(p_item_row_ids)
  LOOP
    -- Insert into bank_items
    INSERT INTO public.bank_items (user_id, item_id, quantity)
    VALUES (v_user_id, v_item.item_id, 1)
    ON CONFLICT DO NOTHING;

    -- Remove from inventory
    DELETE FROM public.inventory WHERE row_id = v_item.row_id;

    v_deposit_count := COALESCE(v_deposit_count, 0) + 1;
  END LOOP;

  RETURN QUERY SELECT true, 'Items deposited successfully'::text, v_deposit_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deposit_to_bank(uuid[]) TO authenticated;

-- ====================================================================
-- RPC: withdraw_from_bank
-- Move items from bank to inventory
-- ====================================================================
DROP FUNCTION IF EXISTS public.withdraw_from_bank(uuid[]);

CREATE FUNCTION public.withdraw_from_bank(p_item_ids uuid[])
RETURNS TABLE (
  success boolean,
  message text,
  items_withdrawn integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_withdraw_count integer;
  v_item record;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer;
    RETURN;
  END IF;

  -- Move bank items to inventory
  FOR v_item IN
    SELECT id, item_id FROM public.bank_items
    WHERE user_id = v_user_id AND id = ANY(p_item_ids)
  LOOP
    -- Insert into inventory
    INSERT INTO public.inventory (user_id, item_id, is_equipped, equip_slot, slot_position)
    VALUES (v_user_id, v_item.item_id, false, 'none', -1);

    -- Remove from bank
    DELETE FROM public.bank_items WHERE id = v_item.id;

    v_withdraw_count := COALESCE(v_withdraw_count, 0) + 1;
  END LOOP;

  RETURN QUERY SELECT true, 'Items withdrawn successfully'::text, v_withdraw_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.withdraw_from_bank(uuid[]) TO authenticated;

-- ====================================================================
-- RLS Policies for user_bank
-- ====================================================================
ALTER TABLE public.user_bank ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_can_read_own_bank" ON public.user_bank;
CREATE POLICY "users_can_read_own_bank"
  ON public.user_bank FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_can_update_own_bank" ON public.user_bank;
CREATE POLICY "users_can_update_own_bank"
  ON public.user_bank FOR UPDATE
  USING (auth.uid() = user_id);

-- ====================================================================
-- RLS Policies for bank_items
-- ====================================================================
ALTER TABLE public.bank_items ENABLE ROW LEVEL SECURITY;

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

GRANT SELECT ON public.user_bank TO authenticated;
GRANT SELECT ON public.bank_items TO authenticated;
