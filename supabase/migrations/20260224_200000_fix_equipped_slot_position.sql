-- Migration: Kuşanılan itemlerin slot_position'larını NULL yap ve get_inventory auto-assign implement
-- Problem: 
--   1. Kuşanılan items'te (is_equipped=true) slot_position değer taşıyor (NULL olması gerekiyor)
--   2. Unequip sonrası slot_position = NULL olan items'e otomatik boş slot atanmalı

-- Step 1: Kuşanılan items'teki tüm slot_position'ları NULL yap
UPDATE public.inventory
SET slot_position = NULL, updated_at = NOW()
WHERE is_equipped = TRUE AND equip_slot IS NOT NULL AND slot_position IS NOT NULL;

-- Step 2: get_inventory RPC'sini güncelle - slot_position NULL olanları auto-assign et
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
            -- Item metadata (denormalized in inventory table)
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

GRANT EXECUTE ON FUNCTION public.get_inventory() TO anon, authenticated, service_role;
