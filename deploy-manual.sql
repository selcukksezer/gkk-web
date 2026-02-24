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
DROP FUNCTION IF EXISTS public.update_item_positions(JSONB) CASCADE;
DROP FUNCTION IF EXISTS public.get_inventory() CASCADE;

-- Step 1: Clean up equipped items' slot_position (should be NULL for equipped items)
UPDATE public.inventory
SET slot_position = NULL, updated_at = NOW()
WHERE is_equipped = TRUE AND equip_slot IS NOT NULL AND slot_position IS NOT NULL;

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
GRANT EXECUTE ON FUNCTION public.update_item_positions(JSONB) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_inventory() TO anon, authenticated, service_role;

-- ============================================================
-- RPC: Update Item Positions (fallback for slot swaps)
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_item_positions(
    p_updates jsonb  -- Array of {row_id, slot_position}
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_update record;
    v_updated_count int := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    IF p_updates IS NULL OR p_updates::text = '[]' THEN
        RETURN jsonb_build_object('success', true, 'updated', 0);
    END IF;

    -- Iterate through updates and apply each one
    FOR v_update IN SELECT * FROM jsonb_to_recordset(p_updates) AS x(row_id uuid, slot_position int)
    LOOP
        -- Only allow updates to items owned by the authenticated user
        UPDATE public.inventory
        SET slot_position = v_update.slot_position, updated_at = NOW()
        WHERE row_id = v_update.row_id AND user_id = v_user_id;

        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'updated', v_updated_count);
EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- RPC: Get Inventory (with auto-assign slot_position for NULL slots)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_inventory()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_items JSONB;
    v_unassigned_rows UUID[];
    v_slot_num INT;
    v_row UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Auto-assign NULL slot_position'ı olan unequipped items'e boş slot ata
    v_unassigned_rows := ARRAY(
        SELECT row_id FROM public.inventory
        WHERE user_id = v_user_id AND is_equipped = FALSE AND slot_position IS NULL
        ORDER BY created_at
    );

    -- Her unassigned row için ilk boş slot (0-19) ara ve ata
    FOREACH v_row IN ARRAY v_unassigned_rows LOOP
        FOR v_slot_num IN 0..19 LOOP
            IF NOT EXISTS (
                SELECT 1 FROM public.inventory 
                WHERE user_id = v_user_id 
                AND slot_position = v_slot_num 
                AND is_equipped = FALSE
            ) THEN
                UPDATE public.inventory 
                SET slot_position = v_slot_num, updated_at = NOW()
                WHERE row_id = v_row AND user_id = v_user_id;
                EXIT;
            END IF;
        END LOOP;
    END LOOP;

    -- Güncellenmiş unequipped inventory'i getir (is_equipped = FALSE)
    SELECT jsonb_agg(
        jsonb_build_object(
            'row_id', inv.row_id,
            'user_id', inv.user_id,
            'item_id', inv.item_id,
            'quantity', inv.quantity,
            'slot_position', inv.slot_position,
            'is_equipped', COALESCE(inv.is_equipped, false),
            'equip_slot', inv.equip_slot,
            'created_at', inv.created_at,
            'updated_at', inv.updated_at,
            'enhancement_level', COALESCE(inv.enhancement_level, 0),
            'obtained_at', inv.obtained_at,
            'is_favorite', COALESCE(inv.is_favorite, false),
            'description', inv.description,
            'icon', inv.icon,
            'weapon_type', inv.weapon_type,
            'armor_type', inv.armor_type,
            'material_type', inv.material_type,
            'potion_type', inv.potion_type,
            'base_price', inv.base_price,
            'vendor_sell_price', inv.vendor_sell_price,
            'is_tradeable', inv.is_tradeable,
            'is_stackable', inv.is_stackable,
            'max_stack', inv.max_stack,
            'max_enhancement', inv.max_enhancement,
            'can_enhance', inv.can_enhance,
            'heal_amount', inv.heal_amount,
            'tolerance_increase', inv.tolerance_increase,
            'overdose_risk', inv.overdose_risk,
            'required_level', inv.required_level,
            'required_class', inv.required_class,
            'recipe_requirements', inv.recipe_requirements,
            'recipe_result_item_id', inv.recipe_result_item_id,
            'recipe_building_type', inv.recipe_building_type,
            'recipe_production_time', inv.recipe_production_time,
            'recipe_required_level', inv.recipe_required_level,
            'rune_enhancement_type', inv.rune_enhancement_type,
            'rune_success_bonus', inv.rune_success_bonus,
            'rune_destruction_reduction', inv.rune_destruction_reduction,
            'cosmetic_effect', inv.cosmetic_effect,
            'cosmetic_bind_on_pickup', inv.cosmetic_bind_on_pickup,
            'cosmetic_showcase_only', inv.cosmetic_showcase_only,
            'production_building_type', inv.production_building_type,
            'production_rate_per_hour', inv.production_rate_per_hour,
            'production_required_level', inv.production_required_level,
            'bound_to_player', inv.bound_to_player,
            'pending_sync', inv.pending_sync
        )
        ORDER BY COALESCE(inv.slot_position, 999), inv.created_at
    )
    INTO v_items
    FROM public.inventory inv
    WHERE inv.user_id = v_user_id AND inv.is_equipped = FALSE;

    IF v_items IS NULL THEN
        v_items := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object('success', true, 'items', v_items);
END;
$$;
