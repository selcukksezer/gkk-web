-- ==================================================================================
-- HOTFIX: Inventory Stack Consolidation
-- ==================================================================================
-- Amaç: Aynı user_id + item_id'ye sahip birden fazla UNEQUIPPED slot olan
--        stackable itemları tek slotta topla (en eski slot_position korunur,
--        diğer slotların miktarları o slota eklenir ve silinir).
--
-- Güvenli: yalnızca is_stackable=true ve is_equipped=false itemlara dokunur.
-- Tekrar çalıştırmak güvenlidir (idempotent).
-- ==================================================================================

DO $$
DECLARE
  v_rec           RECORD;
  v_keeper_row_id UUID;
  v_total_qty     INTEGER;
  v_affected      INTEGER := 0;
BEGIN
  -- Birden fazla unequipped slotu olan stackable item grupları
  FOR v_rec IN
    SELECT
      inv.user_id,
      inv.item_id,
      COUNT(*)         AS slot_count,
      SUM(inv.quantity) AS total_qty,
      MIN(inv.slot_position) AS keeper_slot
    FROM public.inventory inv
    JOIN public.items it ON it.id = inv.item_id
    WHERE inv.is_equipped = false
      AND it.is_stackable  = true
    GROUP BY inv.user_id, inv.item_id
    HAVING COUNT(*) > 1
  LOOP
    -- Korunacak satırın row_id'sini bul (en küçük slot_position)
    SELECT row_id INTO v_keeper_row_id
    FROM public.inventory
    WHERE user_id       = v_rec.user_id
      AND item_id       = v_rec.item_id
      AND is_equipped   = false
      AND slot_position = v_rec.keeper_slot
    LIMIT 1;

    v_total_qty := v_rec.total_qty;

    -- Diğer tüm slotları sil
    DELETE FROM public.inventory
    WHERE user_id     = v_rec.user_id
      AND item_id     = v_rec.item_id
      AND is_equipped = false
      AND row_id      != v_keeper_row_id;

    -- Kalan slotu toplam miktara güncelle
    UPDATE public.inventory
    SET quantity = v_total_qty
    WHERE row_id = v_keeper_row_id;

    v_affected := v_affected + 1;

    RAISE NOTICE 'Konsolide edildi: user=% item=% slot_count=% → qty=%',
      v_rec.user_id, v_rec.item_id, v_rec.slot_count, v_total_qty;
  END LOOP;

  RAISE NOTICE 'Toplam konsolide edilen item grubu: %', v_affected;
END;
$$;
