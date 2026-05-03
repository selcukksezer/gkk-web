-- =========================================================================================
-- MIGRATION: Fix Level Stat Growth Fallback (Applied DB Patch)
-- =========================================================================================
-- Amaç:
-- handle_xp_level_progression fonksiyonunu güncelleyerek class tablosu lookup
-- kaçırsa bile PLAN_11 growth değerleri ile luck/stat artışını garanti etmek.
-- =========================================================================================

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
