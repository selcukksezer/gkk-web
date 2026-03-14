BEGIN;

ALTER TABLE public.items
  ADD COLUMN IF NOT EXISTS facility_type text NULL DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_items_facility_type ON public.items(facility_type);

COMMENT ON COLUMN public.items.facility_type IS 'Plan 2 facility source for material/resource items such as mining, quarry, holy_spring.';

COMMIT;