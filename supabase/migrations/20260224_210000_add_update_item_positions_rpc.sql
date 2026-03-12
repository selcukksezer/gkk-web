-- Migration: Add update_item_positions RPC (fallback for swap_slots)
-- This RPC is used as a fallback when swap_slots temporarily fails during dev.
-- It updates multiple items' slot positions via row_id.

CREATE OR REPLACE FUNCTION public.update_item_positions(
    p_updates jsonb  -- Array of {row_id, slot_position}
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_update jsonb;
    v_row_id uuid;
    v_new_position int;
    v_updated_count int := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    IF p_updates IS NULL OR p_updates::text = '[]' THEN
        RETURN jsonb_build_object('success', true, 'updated', 0);
    END IF;

    -- Old canonical behavior from yedek: iterate raw json and validate each slot.
    FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
    LOOP
        v_row_id := (v_update->>'row_id')::uuid;
        v_new_position := (v_update->>'slot_position')::int;

        -- Validate position (0-19). Prevent NULL / invalid writes that can orphan items.
        IF v_new_position IS NULL OR v_new_position < 0 OR v_new_position > 19 THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', format('Invalid slot_position: %s (must be 0-19)', COALESCE(v_update->>'slot_position', 'NULL'))
            );
        END IF;

        -- Only allow updates to items owned by the authenticated user
        UPDATE public.inventory
        SET slot_position = v_new_position, updated_at = NOW()
        WHERE row_id = v_row_id AND user_id = v_user_id;

        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'updated_count', v_updated_count);
EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_item_positions(jsonb) TO authenticated, anon, service_role;
