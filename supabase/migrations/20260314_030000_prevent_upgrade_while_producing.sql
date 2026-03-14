-- Prevent facility level upgrades if there is an active or uncollected production
CREATE OR REPLACE FUNCTION public.check_facility_upgrade_when_producing()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- If level is increasing
  IF NEW.level > OLD.level THEN
    -- And production is currently active or finished but not collected
    IF OLD.production_started_at IS NOT NULL THEN
      RAISE EXCEPTION 'Üretim devam ederken veya toplanmamış kaynak varken tesis yükseltilemez.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_facility_upgrade ON public.facilities;
CREATE TRIGGER trg_check_facility_upgrade
  BEFORE UPDATE ON public.facilities
  FOR EACH ROW
  EXECUTE FUNCTION public.check_facility_upgrade_when_producing();
