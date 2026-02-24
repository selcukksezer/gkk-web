-- Add shop visibility and currency controls to items
-- Allows managing item listing/currency directly from Supabase Dashboard

ALTER TABLE public.items
  ADD COLUMN IF NOT EXISTS shop_available boolean NOT NULL DEFAULT true;

ALTER TABLE public.items
  ADD COLUMN IF NOT EXISTS shop_currency text NOT NULL DEFAULT 'gold';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'items_shop_currency_check'
      AND conrelid = 'public.items'::regclass
  ) THEN
    ALTER TABLE public.items
      ADD CONSTRAINT items_shop_currency_check
      CHECK (shop_currency IN ('gold', 'gems'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_items_shop_available
  ON public.items (shop_available)
  WHERE shop_available = true;
