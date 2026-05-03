-- =========================================================================================
-- MIGRATION: One-time backfill for users.power cache
-- =========================================================================================
-- Rationale:
-- Some accounts keep stale cached power (e.g. fixed at 500), which can cause
-- success-rate mismatch in enter_dungeon until power is recomputed.
-- This migration refreshes all cached powers from the canonical formula.
-- =========================================================================================

UPDATE public.users u
SET power = COALESCE(public.calculate_user_total_power(u.auth_id), 0)::INTEGER
WHERE u.auth_id IS NOT NULL;
