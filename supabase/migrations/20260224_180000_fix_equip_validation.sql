-- ============================================================
-- Migration: Fix Equipment Validation
-- ============================================================
-- 
-- Kuşanma kuralları:
-- 1) Sadece kuşanılabilir eşyalar (can_enhance=true VEYA equip_slot != NULL) kuşanılabilecek
-- 2) Consumables/potions kuşanılamayacak (type = 'potion', 'food', vb)
-- 3) Doğru slot kontrolü: item.equip_slot = p_slot olmalı
-- 4) Kuşanılan itemler inventoryde görünmeyecek (is_equipped = true)
-- ============================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 1: equip_item RPC güncelle — validasyon ekle
-- ─────────────────────────────────────────────────────────────

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
    v_item_data RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Get the item to equip — öğelerin kuşanılabilir olup olmadığını kontrol et
    SELECT inv.row_id, inv.item_id, it.type, it.equip_slot, it.can_enhance
    INTO v_item_record
    FROM public.inventory inv
    LEFT JOIN public.items it ON inv.item_id = it.id
    WHERE inv.row_id = p_row_id AND inv.user_id = v_user_id AND inv.is_equipped = FALSE
    LIMIT 1;

    IF v_item_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned or already equipped');
    END IF;

    -- Consumables kuşanılamayacak (potion, food, etc.) — type karşılaştırması case-insensitive
    IF lower(COALESCE(v_item_record.type, '')) IN ('potion', 'food', 'buff', 'consumable', 'resource', 'quest_item', 'misc') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Bu eşya kuşanılamaz (consumable)');
    END IF;

    -- Kuşanılabilir eşya mı? (equip_slot NULL değilse kuşanılabilir)
    IF v_item_record.equip_slot IS NULL OR v_item_record.equip_slot = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bu eşya kuşanılamaz (equip_slot mismatch)');
    END IF;

    -- Doğru slot kontrolü: item.equip_slot = p_slot (case-insensitive)
    IF lower(COALESCE(v_item_record.equip_slot, '')) != lower(COALESCE(p_slot, '')) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yanlış slot. Bu eşya şuraya gidemez: ' || p_slot);
    END IF;

    -- Unequip any item currently in this slot
    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, updated_at = NOW()
    WHERE user_id = v_user_id 
      AND equip_slot = p_slot 
      AND is_equipped = TRUE
      AND row_id != p_row_id;

    -- Equip the new item
    UPDATE public.inventory
    SET is_equipped = TRUE, equip_slot = p_slot, updated_at = NOW()
    WHERE row_id = p_row_id;

    RETURN jsonb_build_object('success', true, 'row_id', p_row_id, 'slot', p_slot);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 2: unequip_item RPC — zaten yeterli
-- ─────────────────────────────────────────────────────────────
-- (Değişiklik yok, var olan RPC kullan)

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 3: get_inventory'yi güncelle — is_equipped=true itemleri filtrele
-- ─────────────────────────────────────────────────────────────
-- Envanterde gösterilecek itemler: is_equipped = false VEYA (is_equipped = true ama slot ile order etc)
-- Temek: kuşanılan itemler inventory listesinde görünmeyecek

CREATE OR REPLACE FUNCTION public.get_inventory()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_auth_id UUID;
  v_items JSONB;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- SELECT inventory — kuşanılan itemler (is_equipped=true) HARİÇ
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      i.row_id,
      i.item_id,
      i.quantity,
      i.slot_position,
      i.is_equipped,
      i.equip_slot AS equipped_slot,
      i.enhancement_level,
      i.is_favorite,
      i.pending_sync,
      i.obtained_at,
      i.created_at,
      i.updated_at,
      COALESCE(it.name, i.item_id) AS name,
      COALESCE(it.description, '') AS description,
      COALESCE(it.icon, '📦') AS icon,
      COALESCE(it.type, 'misc') AS item_type,
      COALESCE(it.rarity, 'common') AS rarity,
      COALESCE(it.base_price, 0) AS base_price,
      COALESCE(it.vendor_sell_price, 0) AS vendor_sell_price,
      COALESCE(it.attack, 0) AS attack,
      COALESCE(it.defense, 0) AS defense,
      COALESCE(it.health, 0) AS health,
      COALESCE(it.power, 0) AS power,
      COALESCE(it.mana_restore, 0) AS mana,
      COALESCE(it.equip_slot, '') AS equip_slot,
      COALESCE(it.weapon_type, '') AS weapon_type,
      COALESCE(it.armor_type, '') AS armor_type,
      COALESCE(it.required_level, 1) AS required_level,
      COALESCE(it.can_enhance, false) AS can_enhance,
      COALESCE(it.max_enhancement, 0) AS max_enhancement,
      COALESCE(it.is_stackable, true) AS is_stackable
    FROM public.inventory i
    LEFT JOIN public.items it ON it.id = i.item_id
    WHERE i.user_id = v_auth_id 
      AND i.is_equipped = FALSE  -- Kuşanılan itemler gizle
    ORDER BY i.slot_position NULLS LAST, i.created_at DESC
  ) t;

  RETURN jsonb_build_object('success', true, 'items', v_items);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 4: get_equipped_items RPC — kuşanılan itemleri döndür
-- ─────────────────────────────────────────────────────────────

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

  -- Aggregate via subquery to allow ORDER BY on inv.equip_slot
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  INTO v_equipped_items
  FROM (
    SELECT
    inv.row_id,
    inv.item_id,
    inv.equip_slot,
    COALESCE(inv.enhancement_level, 0) AS enhancement_level,
    inv.quantity,
    inv.obtained_at,
    COALESCE(it.name, '') AS name,
    COALESCE(it.description, '') AS description,
    COALESCE(it.icon, '📦') AS icon,
    COALESCE(it.type, 'misc') AS item_type,
    COALESCE(it.rarity, 'common') AS rarity,
    COALESCE(it.attack, 0) AS attack,
    COALESCE(it.defense, 0) AS defense,
    COALESCE(it.health, 0) AS health,
    COALESCE(it.power, 0) AS power,
    COALESCE(it.required_level, 1) AS required_level,
    it.required_class
    FROM public.inventory inv
    LEFT JOIN public.items it ON inv.item_id = it.id
    WHERE inv.user_id = v_user_id AND inv.is_equipped = TRUE
    ORDER BY inv.equip_slot
  ) t;

  RETURN jsonb_build_object('success', true, 'items', v_equipped_items);
END;
$$;

-- Grants
GRANT EXECUTE ON FUNCTION public.equip_item(UUID, TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.unequip_item(TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_equipped_items() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_inventory() TO authenticated, anon, service_role;

COMMIT;

-- ============================================================
-- ÖZET:
-- ✅ equip_item: Consumables kuşanılamayacak (potion, food, etc)
-- ✅ equip_item: Doğru slot kontrolü — item.equip_slot = p_slot
-- ✅ get_inventory: Kuşanılan itemler gizli (is_equipped = false olanlar gösterilir)
-- ✅ get_equipped_items: Kuşanılan itemleri ayrı döndürür (UI için)
-- ✅ Kuşanılan item drag-drop ile çıkarılabilir (unequip)
-- ============================================================
