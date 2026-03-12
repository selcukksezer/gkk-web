-- =========================================================================================
-- MIGRATION: Equip / Unequip — Automatic Power Cache Refresh
-- =========================================================================================
-- Context: public.users has a cached `power` column used by enter_dungeon and pvp_attack.
-- The calculate_user_total_power(auth_id UUID) function computes the live value, but it
-- is never called by equip_item or unequip_item.  This means users.power becomes stale
-- whenever gear changes, causing incorrect dungeon success rate calculations.
--
-- Fix: after each inventory UPDATE in equip_item / unequip_item, call
--   calculate_user_total_power(auth.uid())
-- and persist the result back to public.users.power.
-- =========================================================================================

-- ── equip_item (full replacement with power refresh) ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.equip_item(
    p_row_id UUID,
    p_slot   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id    UUID;
    v_item_record RECORD;
    v_new_power  NUMERIC;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Get the item to equip — verify ownership and equipability
    SELECT inv.row_id, inv.item_id, it.type, it.equip_slot, it.can_enhance
    INTO v_item_record
    FROM public.inventory inv
    LEFT JOIN public.items it ON inv.item_id = it.id
    WHERE inv.row_id = p_row_id
      AND inv.user_id = v_user_id
      AND inv.is_equipped = FALSE
    LIMIT 1;

    IF v_item_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned or already equipped');
    END IF;

    -- Consumables cannot be equipped
    IF lower(COALESCE(v_item_record.type, '')) IN ('potion', 'food', 'buff', 'consumable', 'resource', 'quest_item', 'misc') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bu esya kusanilamaz (consumable)');
    END IF;

    IF v_item_record.equip_slot IS NULL OR v_item_record.equip_slot = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bu esya kusanilamaz (equip_slot mismatch)');
    END IF;

    IF lower(COALESCE(v_item_record.equip_slot, '')) != lower(COALESCE(p_slot, '')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Yanlis slot. Bu esya suraya gidemez: ' || p_slot);
    END IF;

    -- Unequip any item currently in this slot
    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, updated_at = NOW()
    WHERE user_id   = v_user_id
      AND equip_slot = p_slot
      AND is_equipped = TRUE
      AND row_id != p_row_id;

    -- Equip the new item
    UPDATE public.inventory
    SET is_equipped = TRUE, equip_slot = p_slot, updated_at = NOW()
    WHERE row_id = p_row_id;

    -- Refresh cached power so dungeon/pvp calculations are accurate.
    -- calculate_user_total_power performs one aggregate over equipped inventory rows
    -- (expected ≤12 rows for a fully geared player) — acceptable latency on equip.
    v_new_power := public.calculate_user_total_power(v_user_id);
    UPDATE public.users
    SET power = v_new_power::integer
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object(
        'success',   true,
        'row_id',    p_row_id,
        'slot',      p_slot,
        'new_power', v_new_power::integer
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.equip_item(UUID, TEXT) TO authenticated, anon, service_role;


-- ── unequip_item (full replacement with power refresh) ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.unequip_item(p_slot TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id      UUID;
    v_updated_count INT;
    v_new_power    NUMERIC;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    UPDATE public.inventory
    SET is_equipped   = FALSE,
        equip_slot    = NULL,
        slot_position = NULL,
        updated_at    = NOW()
    WHERE user_id   = v_user_id
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, ''))
      AND is_equipped = TRUE;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found, not owned, or not equipped');
    END IF;

    -- Refresh cached power so dungeon/pvp calculations are accurate.
    -- calculate_user_total_power performs one aggregate over equipped inventory rows
    -- (expected ≤12 rows for a fully geared player) — acceptable latency on unequip.
    v_new_power := public.calculate_user_total_power(v_user_id);
    UPDATE public.users
    SET power = v_new_power::integer
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object(
        'success',   true,
        'slot',      p_slot,
        'new_power', v_new_power::integer
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.unequip_item(TEXT) TO authenticated, anon, service_role;
