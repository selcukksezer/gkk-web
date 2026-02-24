-- Enforce sell rewards in GOLD only (never gems)
-- 1) Add secure sell RPC for inventory vendor sales
-- 2) Enforce market order currency to gold at DB level

CREATE OR REPLACE FUNCTION public.sell_inventory_item_by_row(
  p_row_id uuid,
  p_quantity int DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_current_qty int;
  v_vendor_sell_price int;
  v_sell_qty int;
  v_gold_earned int := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
  END IF;

  SELECT quantity, COALESCE(vendor_sell_price, 0)
  INTO v_current_qty, v_vendor_sell_price
  FROM public.inventory
  WHERE row_id = p_row_id
    AND user_id = v_user_id
  FOR UPDATE;

  IF v_current_qty IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned');
  END IF;

  v_sell_qty := LEAST(v_current_qty, p_quantity);
  v_gold_earned := GREATEST(0, v_vendor_sell_price * v_sell_qty);

  IF v_sell_qty >= v_current_qty THEN
    DELETE FROM public.inventory
    WHERE row_id = p_row_id
      AND user_id = v_user_id;
  ELSE
    UPDATE public.inventory
    SET quantity = quantity - v_sell_qty,
        updated_at = NOW()
    WHERE row_id = p_row_id
      AND user_id = v_user_id;
  END IF;

  UPDATE public.users
  SET gold = COALESCE(gold, 0) + v_gold_earned
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'sold_quantity', v_sell_qty,
    'currency', 'gold',
    'gold_earned', v_gold_earned,
    'gems_earned', 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sell_inventory_item_by_row(uuid, int) TO authenticated, anon, service_role;

ALTER TABLE public.market_orders
  ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'gold';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'market_orders_currency_gold_only_check'
      AND conrelid = 'public.market_orders'::regclass
  ) THEN
    ALTER TABLE public.market_orders
      ADD CONSTRAINT market_orders_currency_gold_only_check
      CHECK (currency = 'gold');
  END IF;
END $$;
