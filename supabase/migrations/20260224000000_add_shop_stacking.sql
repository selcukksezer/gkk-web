-- Migration: Add buy_shop_item RPC with stacking logic
-- Godot: ShopScreen.gd — add item to inventory with stacking
-- Handles quantity > 1 purchase, stackable item consolidation, gold revert on error

CREATE OR REPLACE FUNCTION public.buy_shop_item(
    p_item_id TEXT,
    p_currency TEXT,
    p_price BIGINT,
    p_quantity INT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_item RECORD;
    v_current_gold BIGINT;
    v_current_gems BIGINT;
    v_old_gold BIGINT;
    v_old_gems BIGINT;
    v_inventory_slot INT;
    v_existing_row RECORD;
    v_new_quantity INT;
    v_capacity INT := 20;
    v_occupied INT;
BEGIN
    -- Auth check
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Validate quantity
    IF p_quantity < 1 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
    END IF;

    -- Validate item exists
    SELECT id, name, base_price, is_stackable, max_stack, type AS item_type,
           rarity, description, icon, equip_slot, attack, defense, health, power,
           energy_restore, health_restore, can_enhance, max_enhancement, required_level,
           is_tradeable, vendor_sell_price, tolerance_increase
    INTO v_item
    FROM public.items
    WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found');
    END IF;

    -- Get current currency balance
    SELECT gold, gems INTO v_current_gold, v_current_gems
    FROM public.users
    WHERE auth_id = v_user_id OR id = v_user_id
    LIMIT 1;

    v_old_gold := v_current_gold;
    v_old_gems := v_current_gems;

    -- Check balance
    IF p_currency = 'gold' THEN
        IF v_current_gold < p_price THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
        END IF;
    ELSIF p_currency = 'gems' THEN
        IF v_current_gems < p_price THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
        END IF;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid currency');
    END IF;

    -- Deduct currency — Godot: State.gold -= price
    IF p_currency = 'gold' THEN
        UPDATE public.users
        SET gold = gold - p_price
        WHERE auth_id = v_user_id OR id = v_user_id;
    ELSE
        UPDATE public.users
        SET gems = gems - p_price
        WHERE auth_id = v_user_id OR id = v_user_id;
    END IF;

    -- Try to add item to inventory with stacking — Godot: inventory_manager.add_item(purchase_item)
    BEGIN
        IF v_item.is_stackable THEN
            -- Check if player already has this item (for stacking)
            SELECT row_id, quantity INTO v_existing_row
            FROM public.inventory
            WHERE user_id = v_user_id AND item_id = p_item_id AND NOT is_equipped
            LIMIT 1;

            IF v_existing_row.row_id IS NOT NULL THEN
                -- Stack: update quantity of existing row
                v_new_quantity := LEAST(
                    v_existing_row.quantity + p_quantity,
                    COALESCE(v_item.max_stack, 999)
                );
                UPDATE public.inventory
                SET quantity = v_new_quantity,
                    updated_at = NOW()
                WHERE row_id = v_existing_row.row_id;
            ELSE
                -- No existing stack — find free slot
                SELECT COUNT(*) INTO v_occupied
                FROM public.inventory
                WHERE user_id = v_user_id AND NOT is_equipped;

                IF v_occupied >= v_capacity THEN
                    -- Revert currency — Godot: State.gold = old_gold
                    IF p_currency = 'gold' THEN
                        UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
                    ELSE
                        UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
                    END IF;
                    RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
                END IF;

                -- Find first empty slot
                SELECT s INTO v_inventory_slot
                FROM generate_series(0, v_capacity - 1) s
                WHERE s NOT IN (
                    SELECT slot_position FROM public.inventory
                    WHERE user_id = v_user_id AND slot_position IS NOT NULL
                )
                LIMIT 1;

                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, is_equipped
                ) VALUES (
                    v_user_id, p_item_id, p_quantity, COALESCE(v_inventory_slot, 0), false
                );
            END IF;
        ELSE
            -- Non-stackable: insert new row per unit
            SELECT COUNT(*) INTO v_occupied
            FROM public.inventory
            WHERE user_id = v_user_id AND NOT is_equipped;

            IF v_occupied + p_quantity > v_capacity THEN
                -- Revert currency
                IF p_currency = 'gold' THEN
                    UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
                ELSE
                    UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
                END IF;
                RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
            END IF;

            FOR i IN 1..p_quantity LOOP
                SELECT s INTO v_inventory_slot
                FROM generate_series(0, v_capacity - 1) s
                WHERE s NOT IN (
                    SELECT slot_position FROM public.inventory
                    WHERE user_id = v_user_id AND slot_position IS NOT NULL
                )
                LIMIT 1;

                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, is_equipped
                ) VALUES (
                    v_user_id, p_item_id, 1, COALESCE(v_inventory_slot, i - 1), false
                );
            END LOOP;
        END IF;

    EXCEPTION WHEN OTHERS THEN
        -- Revert currency on any inventory error — Godot: _show_error + revert
        IF p_currency = 'gold' THEN
            UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
        ELSE
            UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
        END IF;
        RETURN jsonb_build_object('success', false, 'error', 'Failed to add item to inventory: ' || SQLERRM);
    END;

    RETURN jsonb_build_object('success', true, 'item_id', p_item_id, 'quantity', p_quantity);
END;
$$;

GRANT EXECUTE ON FUNCTION public.buy_shop_item(TEXT, TEXT, BIGINT, INT) TO authenticated, anon, service_role;
