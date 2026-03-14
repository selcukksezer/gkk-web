-- Migration: Add PLAN_01 item fields and indexes
-- Generated: 2026-03-13

BEGIN;

-- Add columns if they don't exist (safe for existing production DB)
ALTER TABLE public.items
  ADD COLUMN IF NOT EXISTS luck integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_han_only boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_market_tradeable boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_direct_tradeable boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS sub_type text NULL DEFAULT ''::text,
  ADD COLUMN IF NOT EXISTS name_tr text NULL DEFAULT ''::text;

-- Create helpful indexes
CREATE INDEX IF NOT EXISTS idx_items_sub_type ON public.items USING btree (sub_type);
CREATE INDEX IF NOT EXISTS idx_items_type ON public.items USING btree (type);
CREATE INDEX IF NOT EXISTS idx_items_rarity ON public.items USING btree (rarity);
CREATE INDEX IF NOT EXISTS idx_items_required_level ON public.items USING btree (required_level);
CREATE INDEX IF NOT EXISTS idx_items_equip_slot ON public.items USING btree (equip_slot);
CREATE INDEX IF NOT EXISTS idx_items_production_building_type ON public.items USING btree (production_building_type);
CREATE INDEX IF NOT EXISTS idx_items_shop_available ON public.items USING btree (shop_available) WHERE (shop_available = true);

-- Backfill NULLs to defaults to ensure consistency
UPDATE public.items SET luck = 0 WHERE luck IS NULL;
UPDATE public.items SET is_han_only = false WHERE is_han_only IS NULL;
UPDATE public.items SET is_market_tradeable = true WHERE is_market_tradeable IS NULL;
UPDATE public.items SET is_direct_tradeable = true WHERE is_direct_tradeable IS NULL;
UPDATE public.items SET sub_type = '' WHERE sub_type IS NULL;
UPDATE public.items SET name_tr = '' WHERE name_tr IS NULL;

COMMIT;

-- Notes:
-- 1) This migration is idempotent and safe to run multiple times.
-- 2) After applying, run application-level RPC verification to ensure the new fields are returned where needed.
-- 3) If you use Supabase migrations, rename/move this file according to your migration timestamp conventions.
