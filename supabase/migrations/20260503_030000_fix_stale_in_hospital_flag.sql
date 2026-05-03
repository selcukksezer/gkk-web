-- =========================================================================================
-- MIGRATION: Fix Stale users.in_hospital Flag
-- =========================================================================================
-- Problem:
-- users.in_hospital alanı bazı kayıtlarda hospital_until ile uyumsuz kalabiliyor
-- (örn: hospital_until NULL/past ama in_hospital=true).
-- Bu durum özellikle panelde yanıltıcı görünüme neden oluyor.
--
-- Not:
-- enter_dungeon hastane kontrolünü hospital_until > now() ile yaptığı için oyun akışı
-- çoğunlukla doğru çalışıyor; problem daha çok veri tutarlılığı/izlenebilirlik tarafında.
-- =========================================================================================

-- 1) Trigger function: hospital_until değiştiğinde in_hospital otomatik senkronlansın.
CREATE OR REPLACE FUNCTION public.sync_user_hospital_state_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Expired/invalid until değerini normalize et.
  IF NEW.hospital_until IS NOT NULL AND NEW.hospital_until <= now() THEN
    NEW.hospital_until := NULL;
    NEW.hospital_reason := NULL;
  END IF;

  -- in_hospital kolonu varsa bayrağı hospital_until üzerinden hesapla.
  BEGIN
    NEW.in_hospital := (NEW.hospital_until IS NOT NULL AND NEW.hospital_until > now());
  EXCEPTION
    WHEN undefined_column THEN
      -- Bazı ortamlarda in_hospital kolonu olmayabilir.
      NULL;
  END;

  RETURN NEW;
END;
$$;

-- 2) Trigger kurulumu (kolon varsa).
DO $$
DECLARE
  v_has_in_hospital boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'in_hospital'
  ) INTO v_has_in_hospital;

  IF v_has_in_hospital THEN
    DROP TRIGGER IF EXISTS trg_users_sync_hospital_state ON public.users;

    CREATE TRIGGER trg_users_sync_hospital_state
    BEFORE INSERT OR UPDATE OF hospital_until
    ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_user_hospital_state_trigger();
  END IF;
END;
$$;

-- 3) Tek seferlik reconcile: mevcut tutarsız satırları düzelt.
DO $$
DECLARE
  v_has_in_hospital boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'in_hospital'
  ) INTO v_has_in_hospital;

  -- Önce geçmiş hospital_until değerlerini temizle.
  UPDATE public.users
  SET
    hospital_until = NULL,
    hospital_reason = NULL
  WHERE hospital_until IS NOT NULL
    AND hospital_until <= now();

  IF v_has_in_hospital THEN
    UPDATE public.users
    SET in_hospital = (hospital_until IS NOT NULL AND hospital_until > now())
    WHERE in_hospital IS DISTINCT FROM (hospital_until IS NOT NULL AND hospital_until > now());
  END IF;
END;
$$;
