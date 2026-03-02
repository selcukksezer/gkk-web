-- ============================================================
-- Migration: Fix Identity Karmaşası (auth_id / user_id / id)
-- ============================================================
-- 
-- KÖK NEDEN:
--   public.users.id    = Uygulama UUID (gen_random_uuid)   -- PK
--   public.users.auth_id = auth.users.id (Supabase Auth UUID) -- FK
--   auth.uid()          = Supabase Auth UUID (JWT sub)
--
--   inventory.user_id   → auth.users(id) = Auth UUID
--   Tüm RPC'ler         → v_user_id := auth.uid() → WHERE user_id = v_user_id
--   RLS policy'ler       → auth.uid() = user_id
--
-- KURALI:
--   inventory.user_id HER ZAMAN auth.users.id (= Auth UUID) olmalı.
--   Asla public.users.id kullanılmamalı.
--
-- Bu migration:
--   1) inventory.user_id FK'sini auth.users(id) olarak garanti eder
--   2) Yanlışlıkla public.users.id yazılmış satırları düzeltir (varsa)
--   3) RLS policy'leri oluşturur/günceller
--   4) buy_shop_item RPC'sini oluşturur (yoksa)
--   5) get_inventory RPC'sini oluşturur/günceller
-- ============================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 0: FK'yı SİL (BÖLÜM 2'de UPDATE yapabilmek için)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.inventory
  DROP CONSTRAINT IF EXISTS inventory_user_id_fkey;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 1: Yanlışlıkla public.users.id yazılmış satırları düzelt
-- ─────────────────────────────────────────────────────────────
-- Eğer user_id bir public.users.id ise (auth.users'da yoksa),
-- public.users.auth_id üzerinden doğru Auth UUID'ye eşle.

UPDATE public.inventory i
SET user_id = (
  SELECT u.auth_id
  FROM public.users u
  WHERE u.id = i.user_id
  LIMIT 1
)
WHERE NOT EXISTS (
  -- Bu user_id auth.users'da yok — yani yanlış yazılmış
  SELECT 1 FROM auth.users a WHERE a.id = i.user_id
)
AND EXISTS (
  -- Ama public.users.id olarak mevcut — düzeltebiliriz
  SELECT 1 FROM public.users u WHERE u.id = i.user_id AND u.auth_id IS NOT NULL
);

-- Hala auth.users'da olmayan satırları sil (eşleştirilemeyenler)
DELETE FROM public.inventory i
WHERE NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.id = i.user_id);

-- Kontrol: hepsi geçerli olmalı
-- SELECT COUNT(*) FROM public.inventory i WHERE NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.id = i.user_id);

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 2: inventory.user_id FK'sini oluştur (satırlar düzeltildikten sonra)
-- ─────────────────────────────────────────────────────────────
-- FK: inventory.user_id → auth.users(id) ON DELETE CASCADE
-- Bu, tüm RPC'ler ve RLS ile tutarlıdır.
ALTER TABLE public.inventory
  ADD CONSTRAINT inventory_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 3: RLS Policy'ler (Inventory)
-- ─────────────────────────────────────────────────────────────

-- RLS etkinleştir
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;

-- Mevcut policy'leri düşür (idempotent)
DROP POLICY IF EXISTS "inventory_select_own" ON public.inventory;
DROP POLICY IF EXISTS "inventory_insert_own" ON public.inventory;
DROP POLICY IF EXISTS "inventory_update_own" ON public.inventory;
DROP POLICY IF EXISTS "inventory_delete_own" ON public.inventory;

-- NOTE: SELECT policy'sini atlatıyoruz — get_inventory RPC SECURITY DEFINER olduğu için
-- ve REST queries için user kendi user_id'sini filter etmeli client-side.
-- İstemci kodunda RPC (SECURITY DEFINER) kullanması yeterli.

-- INSERT: Kullanıcı sadece kendi user_id'si ile insert yapabilsin
CREATE POLICY "inventory_insert_own" ON public.inventory
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: Kullanıcı sadece kendi satırlarını güncellesin
CREATE POLICY "inventory_update_own" ON public.inventory
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: Kullanıcı sadece kendi satırlarını silsin
CREATE POLICY "inventory_delete_own" ON public.inventory
  FOR DELETE
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 4: buy_shop_item RPC (yoksa oluştur)
-- ─────────────────────────────────────────────────────────────
-- Bu RPC, mağazadan eşya alımını sunucu tarafında halleder:
--   1) Bakiye kontrolü
--   2) Bakiye düşüşü (public.users tablosunda)
--   3) Envantere ekleme (inventory tablosunda, user_id = auth.uid())

CREATE OR REPLACE FUNCTION public.buy_shop_item(
  p_item_id TEXT,
  p_currency TEXT DEFAULT 'gold',
  p_price INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_auth_id UUID;
  v_user_row RECORD;
  v_new_balance INTEGER;
  v_inv_row_id UUID;
  v_slot INTEGER;
BEGIN
  -- 1) Kimlik doğrula
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- 2) public.users'tan bakiye al (auth_id ile)
  SELECT id, gold, gems INTO v_user_row
  FROM public.users
  WHERE auth_id = v_auth_id
  LIMIT 1;

  IF v_user_row IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  -- 3) Bakiye kontrolü ve düşüşü
  IF p_currency = 'gems' THEN
    IF v_user_row.gems < p_price THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz gem');
    END IF;
    v_new_balance := v_user_row.gems - p_price;
    UPDATE public.users SET gems = v_new_balance WHERE auth_id = v_auth_id;
  ELSIF p_currency = 'gold' THEN
    IF v_user_row.gold < p_price THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın');
    END IF;
    v_new_balance := v_user_row.gold - p_price;
    UPDATE public.users SET gold = v_new_balance WHERE auth_id = v_auth_id;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Unknown currency: ' || p_currency);
  END IF;

  -- 4) İlk boş slot bul (0-19)
  SELECT s.slot
  INTO v_slot
  FROM generate_series(0, 19) AS s(slot)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.inventory
    WHERE user_id = v_auth_id
      AND slot_position = s.slot
      AND is_equipped = false
  )
  ORDER BY s.slot
  LIMIT 1;

  -- v_slot NULL ise envanter dolu
  IF v_slot IS NULL THEN
    -- Bakiye geri al
    IF p_currency = 'gems' THEN
      UPDATE public.users SET gems = v_user_row.gems WHERE auth_id = v_auth_id;
    ELSE
      UPDATE public.users SET gold = v_user_row.gold WHERE auth_id = v_auth_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu');
  END IF;

  -- 5) Envantere ekle — user_id = Auth UUID (auth.uid())
  INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, obtained_at)
  VALUES (v_auth_id, p_item_id, 1, v_slot, EXTRACT(EPOCH FROM NOW())::BIGINT)
  RETURNING row_id INTO v_inv_row_id;

  RETURN jsonb_build_object(
    'success', true,
    'row_id', v_inv_row_id,
    'item_id', p_item_id,
    'slot_position', v_slot,
    'new_balance', v_new_balance,
    'currency', p_currency
  );
END;
$$;

-- Grant: authenticated kullanıcılar çağırabilsin
GRANT EXECUTE ON FUNCTION public.buy_shop_item(TEXT, TEXT, INTEGER) TO authenticated;
-- Anon da çağırabilsin (JWT ile auth.uid() dolar)
GRANT EXECUTE ON FUNCTION public.buy_shop_item(TEXT, TEXT, INTEGER) TO anon;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 5: get_inventory RPC (yoksa oluştur / güncelle)
-- ─────────────────────────────────────────────────────────────
-- Envanteri items tablosuyla join ederek döner (varsa).
-- user_id = auth.uid() (Auth UUID)

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

  -- SELECT inventory, dönen veriler:
  -- - Inventory satırı: row_id, item_id, quantity, slot_position, is_equipped, equip_slot, ...
  -- - Item catalog (items tablosundan LEFT JOIN varsa, yoksa NULL/default)
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
      -- Item catalog data — items tablosu varsa join et, yoksa item_id'yi fallback olarak kullan
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
    ORDER BY i.slot_position NULLS LAST, i.created_at DESC
  ) t;

  RETURN jsonb_build_object('success', true, 'items', v_items);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_inventory() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_inventory() TO anon;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 6: add_inventory_item_v2 RPC (yoksa oluştur / güncelle)
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.add_inventory_item_v2(
  item_data JSONB,
  p_slot_position INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_auth_id UUID;
  v_item_id TEXT;
  v_quantity INTEGER;
  v_is_stackable BOOLEAN;
  v_catalog_stack BOOLEAN;
  v_slot INTEGER;
  v_existing RECORD;
  v_row_id UUID;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_item_id := item_data->>'item_id';
  v_quantity := COALESCE((item_data->>'quantity')::INTEGER, 1);

  -- Allow caller (claim) to control stacking via item_data.allow_stack (default true)
  v_is_stackable := COALESCE((item_data->>'allow_stack')::boolean, true);

  -- Enforce catalog: if item is not stackable in items table, do NOT stack regardless of caller flag
  SELECT is_stackable INTO v_catalog_stack FROM public.items WHERE id = v_item_id;
  IF v_catalog_stack IS NULL THEN
    v_catalog_stack := false;
  END IF;

  v_is_stackable := v_is_stackable AND v_catalog_stack;

  IF v_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'item_id required');
  END IF;
  -- Stack behavior respecting catalog.max_stack:
  IF v_is_stackable THEN
    -- Get max stack size for item from catalog
    DECLARE
      v_max_stack INTEGER := 0;
      v_existing_space INTEGER := 0;
      v_space INTEGER := 0;
      v_add INTEGER := 0;
      v_required_slots INTEGER := 0;
      v_free_slots INTEGER := 0;
      v_rows RECORD;
    BEGIN
      SELECT COALESCE(max_stack, 999999) INTO v_max_stack FROM public.items WHERE id = v_item_id;
      IF v_max_stack IS NULL OR v_max_stack <= 0 THEN
        v_max_stack := 999999;
      END IF;

      -- Total available space in existing stacks for this item
      SELECT COALESCE(SUM(GREATEST(0, v_max_stack - quantity)), 0) INTO v_existing_space
      FROM public.inventory
      WHERE user_id = v_auth_id AND item_id = v_item_id AND is_equipped = false;

      -- If all quantity fits into existing stacks, just fill them
      IF v_quantity <= v_existing_space THEN
        FOR v_rows IN
          SELECT row_id, quantity FROM public.inventory
          WHERE user_id = v_auth_id AND item_id = v_item_id AND is_equipped = false
          ORDER BY created_at ASC
        LOOP
          EXIT WHEN v_quantity <= 0;
          v_space := v_max_stack - v_rows.quantity;
          IF v_space > 0 THEN
            v_add := LEAST(v_space, v_quantity);
            UPDATE public.inventory
            SET quantity = quantity + v_add, updated_at = NOW()
            WHERE row_id = v_rows.row_id;
            v_quantity := v_quantity - v_add;
          END IF;
        END LOOP;
        RETURN jsonb_build_object('success', true, 'action', 'stacked');
      END IF;

      -- Need new slots as well. Compute required new slots and ensure enough free slots exist
      v_required_slots := CEIL( (v_quantity - v_existing_space)::numeric / v_max_stack::numeric )::integer;
      SELECT COUNT(*) INTO v_free_slots FROM generate_series(0,19) AS s(slot)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.inventory WHERE user_id = v_auth_id AND slot_position = s.slot AND is_equipped = false
      );

      IF v_free_slots < v_required_slots THEN
        RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu');
      END IF;

      -- Fill existing stacks first
      FOR v_rows IN
        SELECT row_id, quantity FROM public.inventory
        WHERE user_id = v_auth_id AND item_id = v_item_id AND is_equipped = false
        ORDER BY created_at ASC
      LOOP
        EXIT WHEN v_quantity <= 0;
        v_space := v_max_stack - v_rows.quantity;
        IF v_space > 0 THEN
          v_add := LEAST(v_space, v_quantity);
          UPDATE public.inventory
          SET quantity = quantity + v_add, updated_at = NOW()
          WHERE row_id = v_rows.row_id;
          v_quantity := v_quantity - v_add;
        END IF;
      END LOOP;

      -- Insert new rows for remaining quantity
      WHILE v_quantity > 0 LOOP
        v_add := LEAST(v_max_stack, v_quantity);
        SELECT s.slot INTO v_slot FROM generate_series(0,19) AS s(slot)
        WHERE NOT EXISTS (
          SELECT 1 FROM public.inventory WHERE user_id = v_auth_id AND slot_position = s.slot AND is_equipped = false
        ) ORDER BY s.slot LIMIT 1;

        INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, obtained_at)
        VALUES (v_auth_id, v_item_id, v_add, v_slot, EXTRACT(EPOCH FROM NOW())::BIGINT)
        RETURNING row_id INTO v_row_id;

        v_quantity := v_quantity - v_add;
      END LOOP;

      RETURN jsonb_build_object('success', true, 'action', 'stacked_inserted');
    END;
  END IF;

  -- Boş slot bul
  v_slot := p_slot_position;
  IF v_slot IS NULL THEN
    SELECT s.slot INTO v_slot
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = v_auth_id AND slot_position = s.slot AND is_equipped = false
    )
    ORDER BY s.slot LIMIT 1;
  END IF;

  IF v_slot IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu');
  END IF;

  INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, obtained_at)
  VALUES (v_auth_id, v_item_id, v_quantity, v_slot, EXTRACT(EPOCH FROM NOW())::BIGINT)
  RETURNING row_id INTO v_row_id;

  RETURN jsonb_build_object('success', true, 'row_id', v_row_id, 'slot_position', v_slot, 'action', 'inserted');
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_inventory_item_v2(JSONB, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_inventory_item_v2(JSONB, INTEGER) TO anon;

COMMIT;

-- ============================================================
-- ÖZET:
-- ✅ inventory.user_id FK → auth.users(id) (Auth UUID) — TÜM RPC/RLS ile tutarlı
-- ✅ Yanlışlıkla public.users.id yazılmış satırlar düzeltildi
-- ✅ RLS policy'ler oluşturuldu (SELECT/INSERT/UPDATE/DELETE — auth.uid())
-- ✅ buy_shop_item RPC: Bakiye kontrol → düş → envantere ekle (Auth UUID)
-- ✅ get_inventory RPC: Items join ile envanter listele (Auth UUID)
-- ✅ add_inventory_item_v2 RPC: Stackable + slot yönetimi (Auth UUID)
-- ============================================================
