-- =========================================================================================
-- MIGRATION: Fix guild_blueprints.fragments_required
-- =========================================================================================

ALTER TABLE public.guild_blueprints
ADD COLUMN IF NOT EXISTS fragments_required INTEGER NOT NULL DEFAULT 100;

-- Normalize legacy rows
UPDATE public.guild_blueprints
SET fragments_required = 100
WHERE fragments_required IS NULL OR fragments_required <= 0;
