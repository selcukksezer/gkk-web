-- =========================================================================================
-- MIGRATION: Fix Level Progression and Stat Growth
-- =========================================================================================
-- Problem:
-- XP artiyor fakat oyuncu level atlamiyor; level atlama stat artislari uygulanmiyor.
--
-- Plan referansi:
-- PLAN_06_ECONOMY_BALANCE.md §11
-- XP_needed(level) = 100 * level * (1 + level * 0.15), level cap 70
-- PLAN_11_CHARACTER_CLASS_SYSTEM.md §3.2
-- Level basina sinif buyumeleri: attack/defense/health/luck
-- =========================================================================================

CREATE OR REPLACE FUNCTION public.xp_needed_for_level(p_level integer)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_level IS NULL OR p_level < 1 THEN
    RETURN 0;
  END IF;

  RETURN floor(100 * p_level * (1 + p_level * 0.15));
END;
$$;

CREATE OR REPLACE FUNCTION public.total_xp_for_level(p_level integer)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_total integer := 0;
  v_i integer;
BEGIN
  IF p_level IS NULL OR p_level <= 1 THEN
    RETURN 0;
  END IF;

  FOR v_i IN 1..(p_level - 1) LOOP
    v_total := v_total + public.xp_needed_for_level(v_i);
  END LOOP;

  RETURN v_total;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_xp_level_progression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_level integer;
  v_new_level integer;
  v_levels_gained integer;
  v_next_level_total_xp integer;
  v_class_key text;
  v_attack_gain integer := 0;
  v_defense_gain integer := 0;
  v_health_gain integer := 0;
  v_luck_gain integer := 0;
  v_level_cap constant integer := 70;
BEGIN
  -- Sadece XP artisi ile level ilerlet.
  IF COALESCE(NEW.xp, 0) <= COALESCE(OLD.xp, 0) THEN
    RETURN NEW;
  END IF;

  v_old_level := GREATEST(COALESCE(OLD.level, 1), 1);
  v_new_level := v_old_level;

  IF v_old_level >= v_level_cap THEN
    NEW.level := v_old_level;
    RETURN NEW;
  END IF;

  LOOP
    EXIT WHEN v_new_level >= v_level_cap;

    v_next_level_total_xp := public.total_xp_for_level(v_new_level + 1);
    EXIT WHEN COALESCE(NEW.xp, 0) < v_next_level_total_xp;

    v_new_level := v_new_level + 1;
  END LOOP;

  v_levels_gained := v_new_level - v_old_level;

  IF v_levels_gained <= 0 THEN
    RETURN NEW;
  END IF;

  NEW.level := v_new_level;

  -- Sinif buyumesi (PLAN_11): attack/defense/health/luck
  v_class_key := lower(COALESCE(NEW.character_class, OLD.character_class, ''));
  IF v_class_key <> '' THEN
    SELECT
      COALESCE(attack_per_level, 0),
      COALESCE(defense_per_level, 0),
      COALESCE(health_per_level, 0),
      COALESCE(luck_per_level, 0)
    INTO
      v_attack_gain,
      v_defense_gain,
      v_health_gain,
      v_luck_gain
    FROM public.character_classes
    WHERE id = v_class_key
    LIMIT 1;

    IF NOT FOUND THEN
      CASE v_class_key
        WHEN 'warrior' THEN
          v_attack_gain := 3;
          v_defense_gain := 2;
          v_health_gain := 15;
          v_luck_gain := 1;
        WHEN 'alchemist' THEN
          v_attack_gain := 1;
          v_defense_gain := 2;
          v_health_gain := 20;
          v_luck_gain := 2;
        WHEN 'shadow' THEN
          v_attack_gain := 2;
          v_defense_gain := 1;
          v_health_gain := 12;
          v_luck_gain := 3;
        ELSE
          v_attack_gain := 0;
          v_defense_gain := 0;
          v_health_gain := 0;
          v_luck_gain := 0;
      END CASE;
    END IF;

    NEW.attack := COALESCE(NEW.attack, 0) + (v_attack_gain * v_levels_gained);
    NEW.defense := COALESCE(NEW.defense, 0) + (v_defense_gain * v_levels_gained);
    NEW.max_health := COALESCE(NEW.max_health, 0) + (v_health_gain * v_levels_gained);
    NEW.health := COALESCE(NEW.health, 0) + (v_health_gain * v_levels_gained);
    NEW.luck := COALESCE(NEW.luck, 0) + (v_luck_gain * v_levels_gained);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_xp_level_progression ON public.users;

CREATE TRIGGER trg_users_xp_level_progression
BEFORE UPDATE OF xp ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_xp_level_progression();

-- Backfill: Mevcut kullanicilarin XP'sine gore eksik level/stat artisini uygula.
DO $$
DECLARE
  v_user record;
  v_target_level integer;
  v_levels_gained integer;
  v_next_level_total_xp integer;
  v_attack_gain integer := 0;
  v_defense_gain integer := 0;
  v_health_gain integer := 0;
  v_luck_gain integer := 0;
BEGIN
  FOR v_user IN
    SELECT auth_id, level, xp, character_class
    FROM public.users
  LOOP
    v_target_level := GREATEST(COALESCE(v_user.level, 1), 1);

    LOOP
      EXIT WHEN v_target_level >= 70;
      v_next_level_total_xp := public.total_xp_for_level(v_target_level + 1);
      EXIT WHEN COALESCE(v_user.xp, 0) < v_next_level_total_xp;
      v_target_level := v_target_level + 1;
    END LOOP;

    v_levels_gained := v_target_level - GREATEST(COALESCE(v_user.level, 1), 1);

    IF v_levels_gained > 0 THEN
      v_attack_gain := 0;
      v_defense_gain := 0;
      v_health_gain := 0;
      v_luck_gain := 0;

      IF v_user.character_class IS NOT NULL THEN
        SELECT
          COALESCE(attack_per_level, 0),
          COALESCE(defense_per_level, 0),
          COALESCE(health_per_level, 0),
          COALESCE(luck_per_level, 0)
        INTO
          v_attack_gain,
          v_defense_gain,
          v_health_gain,
          v_luck_gain
        FROM public.character_classes
        WHERE id = v_user.character_class
        LIMIT 1;

        IF NOT FOUND THEN
          CASE lower(v_user.character_class)
            WHEN 'warrior' THEN
              v_attack_gain := 3;
              v_defense_gain := 2;
              v_health_gain := 15;
              v_luck_gain := 1;
            WHEN 'alchemist' THEN
              v_attack_gain := 1;
              v_defense_gain := 2;
              v_health_gain := 20;
              v_luck_gain := 2;
            WHEN 'shadow' THEN
              v_attack_gain := 2;
              v_defense_gain := 1;
              v_health_gain := 12;
              v_luck_gain := 3;
          END CASE;
        END IF;
      END IF;

      UPDATE public.users
      SET
        level = v_target_level,
        attack = attack + v_attack_gain * v_levels_gained,
        defense = defense + v_defense_gain * v_levels_gained,
        max_health = max_health + v_health_gain * v_levels_gained,
        health = health + v_health_gain * v_levels_gained,
        luck = luck + v_luck_gain * v_levels_gained
      WHERE auth_id = v_user.auth_id;
    END IF;
  END LOOP;
END;
$$;
