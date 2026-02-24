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

GRANT EXECUTE ON FUNCTION public.update_item_positions(jsonb) TO authenticated, anon, service_role;
