-- =========================================================================================
-- MIGRATION: Normalize users.hospital_until / users.prison_until to timestamptz
-- =========================================================================================
-- Problem:
-- Some environments store these columns as timestamp without time zone, while
-- game logic compares with now() on server in UTC. Flutter then parses the raw
-- value as local time and may show "healthy" even though server returns in_hospital.
--
-- Fix:
-- 1) Convert both columns to timestamptz when needed.
-- 2) Interpret existing naive timestamps as UTC during conversion.
-- =========================================================================================

DO $$
DECLARE
  v_hospital_type TEXT;
  v_prison_type TEXT;
BEGIN
  SELECT data_type
  INTO v_hospital_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'hospital_until';

  IF v_hospital_type = 'timestamp without time zone' THEN
    ALTER TABLE public.users
      ALTER COLUMN hospital_until TYPE timestamptz
      USING (
        CASE
          WHEN hospital_until IS NULL THEN NULL
          ELSE hospital_until AT TIME ZONE 'UTC'
        END
      );
  END IF;

  SELECT data_type
  INTO v_prison_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'prison_until';

  IF v_prison_type = 'timestamp without time zone' THEN
    ALTER TABLE public.users
      ALTER COLUMN prison_until TYPE timestamptz
      USING (
        CASE
          WHEN prison_until IS NULL THEN NULL
          ELSE prison_until AT TIME ZONE 'UTC'
        END
      );
  END IF;
END $$;
