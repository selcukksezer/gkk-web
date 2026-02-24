-- Migration: Add equipment RPCs (equip_item / unequip_item / get_equipped_items)

-- Ensure equip columns exist (idempotent)
ALTER TABLE public.inventory 
ADD COLUMN IF NOT EXISTS is_equipped BOOLEAN DEFAULT false;

ALTER TABLE public.inventory
ADD COLUMN IF NOT EXISTS equip_slot TEXT;

CREATE INDEX IF NOT EXISTS idx_inventory_equipped 
ON public.inventory(user_id, is_equipped) 
WHERE is_equipped = true;

-- RPC: Equip Item
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

-- RPC: Unequip Item
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

        -- When unequipping, clear equip_slot and clear slot_position to avoid slot collisions
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

-- RPC: Get Equipped Items
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

GRANT EXECUTE ON FUNCTION public.equip_item(UUID, TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.unequip_item(TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_equipped_items() TO authenticated, anon, service_role;
