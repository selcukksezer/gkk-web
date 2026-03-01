-- Migration: create crafted_items_log table with indexes
-- Generated: 2026-03-01

-- Ensure gen_random_uuid is available
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.crafted_items_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  item_id text NOT NULL,
  quantity integer NOT NULL,
  rarity character varying(20) NOT NULL,
  facility_id uuid NULL,
  recipe_id text NULL,
  enhancement_level integer NULL DEFAULT 0,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT crafted_items_log_pkey PRIMARY KEY (id),
  CONSTRAINT crafted_items_log_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facilities (id) ON DELETE SET NULL,
  CONSTRAINT crafted_items_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_crafted_items_log_user_id ON public.crafted_items_log USING btree (user_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_crafted_items_log_facility_id ON public.crafted_items_log USING btree (facility_id) TABLESPACE pg_default;
