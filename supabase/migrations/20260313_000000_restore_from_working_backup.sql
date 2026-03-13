-- =========================================================================================
-- MIGRATION: Restore Working Inventory/Equip System from Backup 2026-03-07
-- =========================================================================================
-- Context: Extracted all working RPC functions and index definitions from 
-- veritabani_komple_yedek_07_03_2026.sql (the backup that worked).
-- This migration restores the exact working behavior.
--
-- Key changes:
-- 1. Exact equip_item(p_row_id uuid, p_slot text) implementation
-- 2. Exact unequip_item(p_slot text) implementation  
-- 3. Exact swap_slots(p_from_slot int, p_to_slot int) implementation
-- 4. Exact update_item_positions(p_updates jsonb) implementation
-- 5. Correct indexes: idx_inventory_user_slot_unique and idx_inventory_user_equip_slot_unique
-- =========================================================================================

-- ── Drop old functions (if they exist in wrong form) ────────────────────────────────────
DROP FUNCTION IF EXISTS public.equip_item(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.unequip_item(text) CASCADE;
DROP FUNCTION IF EXISTS public.swap_slots(integer, integer) CASCADE;
DROP FUNCTION IF EXISTS public.update_item_positions(jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.swap_equip_with_slot(text, integer) CASCADE;

-- ── Drop old indexes ─────────────────────────────────────────────────────────────────────
DROP INDEX IF EXISTS public.idx_inventory_user_slot_unique CASCADE;
DROP INDEX IF EXISTS public.idx_inventory_user_equip_slot_unique CASCADE;

-- ── equip_item: Exact working version from backup ────────────────────────────────────────
CREATE FUNCTION public.equip_item(p_row_id uuid, p_slot text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_item_record RECORD;
  v_target_slot INTEGER;
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

    -- Read the current slot_position of the item being equipped (may be NULL)
    SELECT slot_position INTO v_target_slot FROM public.inventory WHERE row_id = p_row_id LIMIT 1;

    -- Unequip any item currently in this slot
    -- If we're equipping from an inventory slot, move the currently equipped item into that slot
    -- (prevents both items ending up with NULL slot_position)
    UPDATE public.inventory
    SET is_equipped = FALSE,
        equip_slot = NULL,
        slot_position = v_target_slot,
        updated_at = NOW()
    WHERE user_id = v_user_id
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, ''))
      AND is_equipped = TRUE
      AND row_id != p_row_id;

    -- Equip the new item
    UPDATE public.inventory
    SET is_equipped = TRUE, equip_slot = p_slot, slot_position = NULL, updated_at = NOW()
    WHERE row_id = p_row_id;

    RETURN jsonb_build_object('success', true, 'row_id', p_row_id, 'slot', p_slot);
END;
$$;

GRANT EXECUTE ON FUNCTION public.equip_item(uuid, text) TO authenticated, anon, service_role;

-- ── unequip_item: Exact working version from backup ─────────────────────────────────────
CREATE FUNCTION public.unequip_item(p_slot text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
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

GRANT EXECUTE ON FUNCTION public.unequip_item(text) TO authenticated, anon, service_role;

-- ── swap_slots: Exact working version from backup ─────────────────────────────────────────
CREATE FUNCTION public.swap_slots(p_from_slot integer, p_to_slot integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_a_row uuid;
  v_b_row uuid;
  v_tmp int := -999999999;
  v_result jsonb := '{}'::jsonb;
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

  -- Ensure equipped items do not retain grid slot positions (cleanup corrupted rows)
  UPDATE public.inventory
  SET slot_position = NULL, updated_at = NOW()
  WHERE user_id = v_user_id AND is_equipped = TRUE AND slot_position IS NOT NULL;

  -- Lock involved rows
  SELECT row_id INTO v_a_row FROM public.inventory
    WHERE user_id = v_user_id AND slot_position = p_from_slot
    LIMIT 1 FOR UPDATE;

  SELECT row_id INTO v_b_row FROM public.inventory
    WHERE user_id = v_user_id AND slot_position = p_to_slot
    LIMIT 1 FOR UPDATE;

  -- Both rows exist: swap
  IF v_a_row IS NOT NULL AND v_b_row IS NOT NULL THEN
    UPDATE public.inventory SET slot_position = v_tmp WHERE row_id = v_a_row;
    UPDATE public.inventory SET slot_position = p_from_slot WHERE row_id = v_b_row;
    UPDATE public.inventory SET slot_position = p_to_slot WHERE slot_position = v_tmp AND user_id = v_user_id;
    v_result := jsonb_build_object('success', true, 'moved', jsonb_build_array(
      jsonb_build_object('row_id', v_a_row, 'slot', p_to_slot),
      jsonb_build_object('row_id', v_b_row, 'slot', p_from_slot)
    ));
    RETURN v_result;
  END IF;

  -- Only A exists
  IF v_a_row IS NOT NULL AND v_b_row IS NULL THEN
    UPDATE public.inventory SET slot_position = p_to_slot, updated_at = NOW()
      WHERE row_id = v_a_row;
    RETURN jsonb_build_object('success', true, 'moved', jsonb_build_array(jsonb_build_object('row_id', v_a_row, 'slot', p_to_slot)));
  END IF;

  -- Only B exists
  IF v_a_row IS NULL AND v_b_row IS NOT NULL THEN
    UPDATE public.inventory SET slot_position = p_from_slot, updated_at = NOW()
      WHERE row_id = v_b_row;
    RETURN jsonb_build_object('success', true, 'moved', jsonb_build_array(jsonb_build_object('row_id', v_b_row, 'slot', p_from_slot)));
  END IF;

  -- Neither exists
  RETURN jsonb_build_object('success', false, 'error', 'No items at given slots');

EXCEPTION WHEN others THEN
  RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.swap_slots(integer, integer) TO authenticated, anon, service_role;

-- ── swap_equip_with_slot: Atomically swap an equipped item in an equip slot
--     with an item in an inventory slot. Ensures both is_equipped and
--     slot_position are updated in a single transaction to avoid race conditions.
CREATE FUNCTION public.swap_equip_with_slot(p_equip_slot text, p_target_slot integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_equip_row uuid;
  v_inv_row uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_equip_slot IS NULL OR p_target_slot IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid args');
  END IF;

  -- Find currently equipped item in that equipment slot
  SELECT row_id INTO v_equip_row FROM public.inventory
    WHERE user_id = v_user_id AND is_equipped = TRUE AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_equip_slot, ''))
    LIMIT 1 FOR UPDATE;

  -- Find item at target inventory slot
  SELECT row_id INTO v_inv_row FROM public.inventory
    WHERE user_id = v_user_id AND slot_position = p_target_slot
    LIMIT 1 FOR UPDATE;

  -- Both exist: swap atomically
  -- To avoid unique-index conflicts on equip_slot we first move the currently equipped
  -- item out of the equip slot (freeing the slot), then mark the inventory item as equipped.
  IF v_equip_row IS NOT NULL AND v_inv_row IS NOT NULL THEN
    -- Clear the inventory slot on the target row first to avoid idx_inventory_user_slot_unique collisions
    UPDATE public.inventory SET slot_position = NULL, updated_at = NOW()
      WHERE row_id = v_inv_row;

    -- Move currently equipped item into the inventory target slot (now free)
    UPDATE public.inventory SET slot_position = p_target_slot, is_equipped = FALSE, equip_slot = NULL, updated_at = NOW()
      WHERE row_id = v_equip_row;

    -- Now equip the inventory item into the equip slot (equip_slot is free)
    UPDATE public.inventory SET slot_position = NULL, is_equipped = TRUE, equip_slot = p_equip_slot, updated_at = NOW()
      WHERE row_id = v_inv_row;

    RETURN jsonb_build_object('success', true, 'moved', jsonb_build_array(
      jsonb_build_object('row_id', v_inv_row, 'slot', NULL::int),
      jsonb_build_object('row_id', v_equip_row, 'slot', p_target_slot)
    ));
  END IF;

  -- Only equip exists: move it to inventory slot (unequip)
  IF v_equip_row IS NOT NULL AND v_inv_row IS NULL THEN
    UPDATE public.inventory SET slot_position = p_target_slot, is_equipped = FALSE, equip_slot = NULL, updated_at = NOW()
      WHERE row_id = v_equip_row;
    RETURN jsonb_build_object('success', true, 'moved', jsonb_build_array(jsonb_build_object('row_id', v_equip_row, 'slot', p_target_slot)));
  END IF;

  -- Only inventory exists: equip it
  IF v_equip_row IS NULL AND v_inv_row IS NOT NULL THEN
    -- Defensive: ensure any stray equipped row for this equip slot is cleared
    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, slot_position = NULL, updated_at = NOW()
    WHERE user_id = v_user_id
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_equip_slot, ''))
      AND is_equipped = TRUE
      AND row_id != v_inv_row;

    -- Equip the inventory item
    UPDATE public.inventory SET slot_position = NULL, is_equipped = TRUE, equip_slot = p_equip_slot, updated_at = NOW()
      WHERE row_id = v_inv_row;
    RETURN jsonb_build_object('success', true, 'moved', jsonb_build_array(jsonb_build_object('row_id', v_inv_row, 'slot', NULL)));
  END IF;

  RETURN jsonb_build_object('success', false, 'error', 'No items to swap');
END;
$$;

GRANT EXECUTE ON FUNCTION public.swap_equip_with_slot(text, integer) TO authenticated, anon, service_role;

-- ── update_item_positions: Exact working version from backup ────────────────────────────
CREATE FUNCTION public.update_item_positions(p_updates jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_update record;
    v_updated_count int := 0;
  v_results jsonb := '[]'::jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    IF p_updates IS NULL OR p_updates::text = '[]' THEN
        RETURN jsonb_build_object('success', true, 'updated', 0);
    END IF;

    FOR v_update IN SELECT * FROM jsonb_to_recordset(p_updates) AS x(row_id uuid, slot_position int)
    LOOP
      -- If a slot_position is provided, that means the item is being placed into
      -- the inventory grid: ensure it is not marked as equipped.
      IF v_update.slot_position IS NOT NULL THEN
        UPDATE public.inventory
        SET slot_position = v_update.slot_position,
          is_equipped = FALSE,
          equip_slot = NULL,
          updated_at = NOW()
        WHERE row_id = v_update.row_id AND user_id = v_user_id;
      ELSE
        -- Clearing slot_position only
        UPDATE public.inventory
        SET slot_position = NULL, updated_at = NOW()
        WHERE row_id = v_update.row_id AND user_id = v_user_id;
      END IF;

      IF FOUND THEN
        v_updated_count := v_updated_count + 1;
        v_results := v_results || jsonb_build_object('row_id', v_update.row_id, 'slot_position', v_update.slot_position);
      END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'updated', v_updated_count, 'results', v_results);
EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_item_positions(jsonb) TO authenticated, anon, service_role;

-- ── Recreate critical indexes with exact backup definitions ──────────────────────────────

-- Unique constraint: only one equipped item per equip_slot per player
CREATE UNIQUE INDEX idx_inventory_user_equip_slot_unique ON public.inventory
  USING btree (user_id, equip_slot)
  WHERE ((is_equipped = true) AND (equip_slot IS NOT NULL));

-- Unique constraint: only one grid item per slot_position per player
-- (when is_equipped = false and slot_position is not null)
CREATE UNIQUE INDEX idx_inventory_user_slot_unique ON public.inventory
  USING btree (user_id, slot_position)
  WHERE ((slot_position IS NOT NULL) AND (is_equipped = false));

-- Supporting indexes
CREATE INDEX IF NOT EXISTS idx_inventory_equipped ON public.inventory USING btree (user_id, is_equipped) WHERE (is_equipped = true);
CREATE INDEX IF NOT EXISTS idx_inventory_equipped_by_slot ON public.inventory USING btree (user_id, equip_slot) WHERE (is_equipped = true);

-- Cleanup existing data: ensure equipped items have no slot_position
UPDATE public.inventory SET slot_position = NULL, updated_at = NOW() WHERE is_equipped = TRUE;
