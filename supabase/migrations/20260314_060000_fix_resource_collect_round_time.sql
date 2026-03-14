-- Fix: Make backend completely trust the exact 120s duration if time is close (>= 115s),
-- and use exact base_rate definitions. Add warmup to LCG to ensure better randomness.

CREATE OR REPLACE FUNCTION public._plan2_facility_base_rate(p_facility_type text)
RETURNS numeric
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  RETURN CASE lower(p_facility_type)
    WHEN 'mining' THEN 10.0
    WHEN 'quarry' THEN 8.0
    WHEN 'lumber_mill' THEN 12.0
    WHEN 'clay_pit' THEN 15.0
    WHEN 'sand_quarry' THEN 20.0
    WHEN 'farming' THEN 18.0
    WHEN 'herb_garden' THEN 10.0
    WHEN 'ranch' THEN 12.0
    WHEN 'apiary' THEN 8.0
    WHEN 'mushroom_farm' THEN 10.0
    WHEN 'rune_mine' THEN 5.0
    WHEN 'holy_spring' THEN 6.0
    WHEN 'shadow_pit' THEN 4.0
    WHEN 'elemental_forge' THEN 5.0
    WHEN 'time_well' THEN 3.0
    ELSE 10.0
  END;
END;
$$;

-- Keep unlock levels aligned with web/client expectations.
-- Important: older migrations had uncommon unlock at level 3, which downgrades
-- all uncommon rolls to common at level 2 and makes 10% effectively unreachable.
CREATE OR REPLACE FUNCTION public._plan2_rarity_unlock_level(p_rarity text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE lower(p_rarity)
    WHEN 'common' THEN 1
    WHEN 'uncommon' THEN 2
    WHEN 'rare' THEN 3
    WHEN 'epic' THEN 4
    WHEN 'legendary' THEN 5
    WHEN 'mythic' THEN 6
    ELSE 10
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.collect_facility_resources_v2(
  p_facility_id uuid,
  p_seed bigint,
  p_total_count integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_facility record;
  v_base_rate numeric;
  v_elapsed_seconds numeric;
  v_max_count integer;
  v_base_count integer;
  v_upper_bound integer;
  v_clamped_count integer;
  v_jitter_step integer;
  
  -- LCG Variables
  v_lcg_mod bigint := 2147483647;
  v_lcg_mult bigint := 16807;
  v_rarity_state bigint;
  v_roll numeric;
  
  -- Weights
  v_total_weight integer;
  v_common_weight integer;
  v_uncommon_weight integer;
  v_rare_weight integer;
  v_epic_weight integer;
  v_legendary_weight integer;
  v_mythic_weight integer;
  v_current_weight integer;
  
  v_selected_rarity text;
  v_effective_rarity text;
  
  v_i integer;
  
  -- Use a JSONB object to accumulate counts per final rarity
  v_quotas jsonb := '{}'::jsonb;
  
  v_item_id text;
  v_common_item_id text;
  v_add_result jsonb;
  v_items_generated jsonb := '[]'::jsonb;
  v_added_total integer := 0;
  v_global_suspicion numeric := 0;
  v_effective_risk numeric := 0;
  v_admission_roll numeric := 0;
  v_admission_occurred boolean := false;
  v_prison_minutes integer := 0;
  
  v_key text;
  v_val text;
  v_quota integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT *
  INTO v_facility
  FROM public.facilities
  WHERE id = p_facility_id
    AND user_id = v_user_id
    AND COALESCE(is_active, true) = true
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
  END IF;

  IF v_facility.production_started_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Production not active');
  END IF;

  v_base_rate := public._plan2_facility_base_rate(v_facility.type);
  
  -- Use exactly 120s if the difference is >= 115s to match frontend perfectly and avoid FLOOR() clipping
  v_elapsed_seconds := EXTRACT(EPOCH FROM (now() - v_facility.production_started_at));
  IF v_elapsed_seconds >= 115 THEN
    v_elapsed_seconds := 120;
  END IF;
  v_elapsed_seconds := LEAST(120, GREATEST(0, v_elapsed_seconds));
  
  -- Use ROUND just in case floating point math produces 3.9999999
  v_max_count := ROUND((v_elapsed_seconds / 3600.0) * (v_base_rate * GREATEST(v_facility.level, 1) * 10))::integer;
  
  -- Use client supplied base count if present; fallback to server calculated base.
  v_base_count := GREATEST(COALESCE(p_total_count, v_max_count), 0);

  -- Percentage jitter model:
  --  - Small productions (<20) stay stable to avoid harsh jumps like 4 -> 2.
  --  - Larger productions vary by -5%..+5% based on seed.
  IF v_base_count < 20 THEN
    v_clamped_count := v_base_count;
  ELSE
    v_jitter_step := ((ABS(COALESCE(p_seed, 0)) % 11)::integer) - 5; -- -5..+5
    v_clamped_count := ROUND(v_base_count::numeric * (1 + (v_jitter_step::numeric / 100.0)))::integer;
  END IF;

  -- Allow up to +10% above theoretical base for natural variation while staying bounded.
  v_upper_bound := GREATEST(v_max_count + CEIL(v_max_count::numeric * 0.10)::integer, 0);
  v_clamped_count := LEAST(GREATEST(v_clamped_count, 0), v_upper_bound);

  IF v_clamped_count <= 0 THEN
    UPDATE public.facilities
    SET production_started_at = NULL, updated_at = now()
    WHERE id = p_facility_id;
    
    RETURN jsonb_build_object(
      'success', true,
      'count', 0,
      'items_generated', '[]'::jsonb,
      'admission_occurred', false
    );
  END IF;

  -- 1. Initialize RNG and Weights
  v_rarity_state := mod(ABS(COALESCE(p_seed, 0)) + 13579, v_lcg_mod);
  
  -- Warmup LCG to improve initial randomness distribution
  FOR v_i IN 1..5 LOOP
    v_rarity_state := mod(v_rarity_state * v_lcg_mult, v_lcg_mod);
  END LOOP;
  
  v_common_weight := public._plan2_rarity_weight(v_facility.level, 'common');
  v_uncommon_weight := public._plan2_rarity_weight(v_facility.level, 'uncommon');
  v_rare_weight := public._plan2_rarity_weight(v_facility.level, 'rare');
  v_epic_weight := public._plan2_rarity_weight(v_facility.level, 'epic');
  v_legendary_weight := public._plan2_rarity_weight(v_facility.level, 'legendary');
  v_mythic_weight := public._plan2_rarity_weight(v_facility.level, 'mythic');
  
  v_total_weight := v_common_weight + v_uncommon_weight + v_rare_weight + v_epic_weight + v_legendary_weight + v_mythic_weight;
  
  v_quotas := jsonb_build_object(
    'common', 0, 'uncommon', 0, 'rare', 0, 'epic', 0, 'legendary', 0, 'mythic', 0
  );

  -- 1.5 Admission check based on global suspicion risk.
  -- 70 risk means ~70% chance to be admitted on collect.
  SELECT COALESCE(u.global_suspicion_level, 0)
  INTO v_global_suspicion
  FROM public.users u
  WHERE u.auth_id = v_user_id
  LIMIT 1;

  IF v_global_suspicion IS NULL THEN
    SELECT COALESCE(u.global_suspicion_level, 0)
    INTO v_global_suspicion
    FROM public.users u
    WHERE u.id = v_user_id
    LIMIT 1;
  END IF;

  v_effective_risk := LEAST(100, GREATEST(COALESCE(v_global_suspicion, 0), 0));
  v_admission_roll := random() * 100.0;
  v_admission_occurred := v_admission_roll < v_effective_risk;

  -- Dynamic prison duration by risk + facility level.
  -- Example (approx):
  -- risk 70, level 2 -> ~137 min
  -- risk 85, level 8 -> ~196 min
  -- clamped to [30, 720] minutes.
  v_prison_minutes := LEAST(
    720,
    GREATEST(
      30,
      ROUND((20 + (v_effective_risk * 1.5) + (GREATEST(v_facility.level, 1) * 6)))::integer
    )
  );

  IF v_admission_occurred THEN
    UPDATE public.facilities
    SET production_started_at = NULL, updated_at = now()
    WHERE id = p_facility_id;

    -- Try update via auth_id first, fallback to id.
    UPDATE public.users
    SET prison_until = now() + make_interval(mins => v_prison_minutes),
      global_suspicion_level = 0,
      prison_reason = format('Collected at %s (risk %s, roll %s)', v_facility.type, ROUND(v_effective_risk::numeric,2)::text, ROUND(v_admission_roll::numeric,2)::text)
    WHERE auth_id = v_user_id;

    IF NOT FOUND THEN
      UPDATE public.users
      SET prison_until = now() + make_interval(mins => v_prison_minutes),
        global_suspicion_level = 0,
        prison_reason = format('Collected at %s (risk %s, roll %s)', v_facility.type, ROUND(v_effective_risk::numeric,2)::text, ROUND(v_admission_roll::numeric,2)::text)
      WHERE id = v_user_id;
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'count', 0,
      'items_generated', '[]'::jsonb,
      'admission_occurred', true,
      'admission_risk', ROUND(v_effective_risk::numeric, 2),
      'admission_roll', ROUND(v_admission_roll::numeric, 2),
      'prison_minutes', v_prison_minutes,
      'prison_reason', format('Collected at %s (risk %s, roll %s)', v_facility.type, ROUND(v_effective_risk::numeric,2)::text, ROUND(v_admission_roll::numeric,2)::text)
    );
  END IF;

  -- 2. Roll for each item
  FOR v_i IN 1..v_clamped_count LOOP
    v_rarity_state := mod(v_rarity_state * v_lcg_mult, v_lcg_mod);
    v_roll := (v_rarity_state::numeric / v_lcg_mod::numeric) * v_total_weight;
    
    v_current_weight := 0;
    v_selected_rarity := 'common';
    
    v_current_weight := v_current_weight + v_common_weight;
    IF v_roll < v_current_weight AND v_selected_rarity = 'common' THEN v_selected_rarity := 'common'; END IF;
    
    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_uncommon_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'uncommon'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_rare_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'rare'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_epic_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'epic'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_legendary_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'legendary'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_selected_rarity := 'mythic';
    END IF;

    -- Level unlock downgrade
    IF GREATEST(v_facility.level, 1) < public._plan2_rarity_unlock_level(v_selected_rarity) THEN
      v_selected_rarity := 'common';
    END IF;
    
    -- Increment the count for this rarity
    v_quotas := jsonb_set(
      v_quotas,
      ARRAY[v_selected_rarity],
      to_jsonb((COALESCE((v_quotas->>v_selected_rarity)::integer, 0) + 1))
    );
  END LOOP;

  -- 3. Add to inventory per rarity bin
  FOR v_key, v_val IN SELECT * FROM jsonb_each_text(v_quotas)
  LOOP
    v_quota := v_val::integer;
    IF v_quota <= 0 THEN
      CONTINUE;
    END IF;

    v_effective_rarity := v_key;

    -- Resolve item id from canonical Plan-2 id first (res_<facility>_<rarity>)
    v_item_id := format('res_%s_%s', lower(v_facility.type), lower(v_effective_rarity));
    v_common_item_id := format('res_%s_common', lower(v_facility.type));

    IF NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id = v_item_id) THEN
      -- Legacy fallback by attributes
      SELECT i.id
      INTO v_item_id
      FROM public.items i
      WHERE i.facility_type = v_facility.type
        AND lower(i.type) = 'material'
        AND lower(COALESCE(i.material_type, '')) = 'resource'
        AND lower(i.rarity) = lower(v_effective_rarity)
      ORDER BY i.id
      LIMIT 1;
    END IF;

    -- Force fallback to common (never silently drop quota)
    IF v_item_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id = v_item_id) THEN
      v_item_id := v_common_item_id;
    END IF;

    IF v_item_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id = v_item_id) THEN
      RAISE EXCEPTION 'Missing resource item id for facility %, rarity %', v_facility.type, v_effective_rarity;
    END IF;

    -- Add the item
    v_add_result := public.add_inventory_item_v2(
      jsonb_build_object(
        'item_id', v_item_id,
        'quantity', v_quota,
        'allow_stack', true
      ),
      NULL
    );

    IF COALESCE((v_add_result->>'success')::boolean, false) = false THEN
      RAISE EXCEPTION '%', COALESCE(v_add_result->>'error', 'Failed to add facility resources to inventory');
    END IF;

    v_added_total := v_added_total + v_quota;

    v_items_generated := v_items_generated || jsonb_build_array(
      jsonb_build_object(
        'item_id', v_item_id,
        'quantity', v_quota,
        'rarity', v_effective_rarity
      )
    );
  END LOOP;

  UPDATE public.facilities
  SET production_started_at = NULL, updated_at = now()
  WHERE id = p_facility_id;

  RETURN jsonb_build_object(
    'success', true,
    'count', v_added_total,
    'items_generated', v_items_generated,
    'admission_occurred', false,
    'admission_risk', ROUND(v_effective_risk::numeric, 2),
    'admission_roll', ROUND(v_admission_roll::numeric, 2),
    'prison_minutes', 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.collect_facility_resources_v2(uuid, bigint, integer) TO authenticated;
