-- ============================================================
-- Deploy corrected RPC functions manually
-- Copy and paste this into Supabase SQL Editor:
-- https://app.supabase.com/projects/znvsyzstmxhqvdkkmgdt/sql/new
-- ============================================================

-- DROP existing functions first (if they exist)
DROP FUNCTION IF EXISTS public.equip_item(UUID, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.equip_item(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.unequip_item(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.unequip_item(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.remove_inventory_item_by_row(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.remove_inventory_item_by_row(UUID, INT) CASCADE;
DROP FUNCTION IF EXISTS public.swap_slots(INT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.get_equipped_items() CASCADE;

-- ============================================================
-- RPC: Equip Item
-- ============================================================
CREATE OR REPLACE FUNCTION public.equip_item(
    p_row_id UUID,
    p_slot TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_item_record RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Get the item to equip
    SELECT row_id, item_id INTO v_item_record
    FROM public.inventory
    WHERE row_id = p_row_id AND user_id = v_user_id
    LIMIT 1;

    IF v_item_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned by player');
    END IF;

    -- Unequip any item currently in this slot (clear equip_slot and slot_position)
    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, slot_position = NULL, updated_at = NOW()
    WHERE user_id = v_user_id 
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, '')) 
      AND is_equipped = TRUE
      AND row_id != p_row_id;

    -- Equip the new item
    UPDATE public.inventory
    SET is_equipped = TRUE, equip_slot = p_slot, updated_at = NOW()
    WHERE row_id = p_row_id;

    RETURN jsonb_build_object('success', true, 'row_id', p_row_id, 'slot', p_slot);
END;
$$;

-- ============================================================
-- RPC: Unequip Item
-- ============================================================
CREATE OR REPLACE FUNCTION public.unequip_item(
    p_slot TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, slot_position = NULL, updated_at = NOW()
    WHERE user_id = v_user_id
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, ''))
      AND is_equipped = TRUE;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found, not owned, or not equipped');
    END IF;

    RETURN jsonb_build_object('success', true, 'slot', p_slot);
END;
$$;

-- ============================================================
-- RPC: Get Equipped Items
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_equipped_items()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_equipped_items JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'row_id', inv.row_id,
            'item_id', inv.item_id,
            'equip_slot', inv.equip_slot,
            'enhancement_level', COALESCE(inv.enhancement_level, 0),
            'quantity', inv.quantity,
            'obtained_at', inv.obtained_at,
            'name', it.name,
            'description', it.description,
            'icon', it.icon,
            'item_type', it.type,
            'rarity', it.rarity,
            'attack', it.attack,
            'defense', it.defense,
            'health', it.health,
            'power', it.power,
            'required_level', COALESCE(it.required_level, 1),
            'required_class', it.required_class
        )
    )
    INTO v_equipped_items
    FROM public.inventory inv
    LEFT JOIN public.items it ON inv.item_id = it.id
    WHERE inv.user_id = v_user_id AND inv.is_equipped = TRUE;

    IF v_equipped_items IS NULL THEN
        v_equipped_items := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object('success', true, 'items', v_equipped_items);
END;
$$;

-- ============================================================
-- RPC: Remove Inventory Item by Row ID
-- ============================================================
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

-- ============================================================
-- RPC: Swap Slots (already exists, but updating for completeness)
-- ============================================================
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
  RAISE;
END;
$$;

-- ============================================================
-- Grant permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION public.equip_item(UUID, TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.unequip_item(TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_equipped_items() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.remove_inventory_item_by_row(UUID, INT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.swap_slots(INT, INT) TO authenticated, anon, service_role;
