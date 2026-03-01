-- Migration: create simplified crafting_recipes table
-- Generated: 2026-03-01

-- Ensure uuid generation extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trigger helper to update `updated_at`
CREATE OR REPLACE FUNCTION public.update_crafting_recipes_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Drop existing table (if present) and create new simplified schema
DROP TABLE IF EXISTS public.crafting_recipes;

CREATE TABLE IF NOT EXISTS public.crafting_recipes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  output_item_id text NOT NULL,
  required_level integer NOT NULL DEFAULT 1,
  production_time_seconds integer NOT NULL,
  success_rate double precision NOT NULL DEFAULT 0.8,
  xp_reward integer NOT NULL DEFAULT 0,
  ingredients jsonb NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT crafting_recipes_pkey PRIMARY KEY (id),
  CONSTRAINT crafting_recipes_output_item_id_fkey FOREIGN KEY (output_item_id) REFERENCES public.items (id) ON DELETE RESTRICT
) TABLESPACE pg_default;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_crafting_recipes_output ON public.crafting_recipes USING btree (output_item_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_crafting_recipes_level ON public.crafting_recipes USING btree (required_level) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_crafting_recipes_ingredients ON public.crafting_recipes USING gin (ingredients) TABLESPACE pg_default;

-- Trigger
DROP TRIGGER IF EXISTS trigger_crafting_recipes_timestamp ON public.crafting_recipes;
CREATE TRIGGER trigger_crafting_recipes_timestamp
  BEFORE UPDATE ON public.crafting_recipes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_crafting_recipes_timestamp();
