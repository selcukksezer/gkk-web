-- =========================================================================================
-- MIGRATION: UPDATE_MEKAN_STOCK_RPC
-- =========================================================================================

CREATE OR REPLACE FUNCTION public.update_mekan_stock(
  p_owner_id UUID,
  p_mekan_id UUID,
  p_item_id TEXT,
  p_new_quantity INT,
  p_price BIGINT
) RETURNS JSONB AS $$
DECLARE
  v_mekan RECORD;
  v_old_stock RECORD;
  v_old_quantity INT := 0;
  v_diff INT;
  v_total_inv INT;
BEGIN
  IF p_owner_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  IF p_new_quantity < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Miktar 0''dan küçük olamaz');
  END IF;

  IF p_price < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Fiyat 0''dan küçük olamaz');
  END IF;

  -- Verify mekan owner
  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND owner_id = p_owner_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadı veya size ait değil');
  END IF;

  -- Get current stock
  SELECT * INTO v_old_stock FROM public.mekan_stock WHERE mekan_id = p_mekan_id AND item_id = p_item_id;
  IF FOUND THEN
    v_old_quantity := v_old_stock.quantity;
  END IF;

  v_diff := p_new_quantity - v_old_quantity;

  IF v_diff > 0 THEN
    -- Adding to stock, need to take from inventory
    SELECT COALESCE(SUM(quantity), 0) INTO v_total_inv 
    FROM public.inventory 
    WHERE user_id = p_owner_id AND item_id = p_item_id;

    IF v_total_inv < v_diff THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanterinizde yeterli eşya yok');
    END IF;

    -- Consume from inventory
    DECLARE
      v_remaining INT := v_diff;
      v_row RECORD;
    BEGIN
      FOR v_row IN 
        SELECT row_id, quantity FROM public.inventory 
        WHERE user_id = p_owner_id AND item_id = p_item_id AND quantity > 0
        ORDER BY quantity ASC
      LOOP
        IF v_remaining <= 0 THEN EXIT; END IF;
        
        IF v_row.quantity <= v_remaining THEN
          DELETE FROM public.inventory WHERE row_id = v_row.row_id;
          v_remaining := v_remaining - v_row.quantity;
        ELSE
          UPDATE public.inventory SET quantity = quantity - v_remaining WHERE row_id = v_row.row_id;
          v_remaining := 0;
        END IF;
      END LOOP;
    END;
  ELSIF v_diff < 0 THEN
    -- Removing from stock, return to inventory
    INSERT INTO public.inventory (row_id, user_id, item_id, quantity, obtained_at)
    VALUES (gen_random_uuid(), p_owner_id, p_item_id, ABS(v_diff), EXTRACT(EPOCH FROM NOW())::BIGINT);
  END IF;

  -- Update stock table
  IF p_new_quantity = 0 THEN
    DELETE FROM public.mekan_stock WHERE mekan_id = p_mekan_id AND item_id = p_item_id;
  ELSE
    INSERT INTO public.mekan_stock (mekan_id, item_id, quantity, sell_price, stocked_at)
    VALUES (p_mekan_id, p_item_id, p_new_quantity, p_price, now())
    ON CONFLICT (mekan_id, item_id) DO UPDATE SET
      quantity = EXCLUDED.quantity,
      sell_price = EXCLUDED.sell_price,
      stocked_at = now();
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_mekan_stock(UUID, UUID, TEXT, INT, BIGINT) TO authenticated;
