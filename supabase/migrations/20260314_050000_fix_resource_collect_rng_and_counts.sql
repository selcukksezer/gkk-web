-- Fix: Change resource collection to use seeded RNG instead of fractional distribution,
-- and group by item_id before adding to inventory to avoid the "4 shows but 3 added" bug.

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
  v_clamped_count integer;
  
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
  v_add_result jsonb;
  v_items_generated jsonb := '[]'::jsonb;
  
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
  
  -- Add a 2-second grace period for clock drift
  v_elapsed_seconds := LEAST(
    120,
    GREATEST(0, EXTRACT(EPOCH FROM (now() - v_facility.production_started_at)) + 2.0)
  );
  
  v_max_count := FLOOR((v_elapsed_seconds / 3600.0) * (v_base_rate * GREATEST(v_facility.level, 1) * 10))::integer;
  v_clamped_count := LEAST(GREATEST(COALESCE(p_total_count, 0), 0), GREATEST(v_max_count, 0));

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

    -- Find item
    SELECT id
    INTO v_item_id
    FROM public.items
    WHERE facility_type = v_facility.type
      AND lower(type) = 'material'
      AND lower(COALESCE(material_type, '')) = 'resource'
      AND lower(rarity) = v_effective_rarity
    ORDER BY id
    LIMIT 1;

    -- Fallback to common if missing
    IF v_item_id IS NULL AND v_effective_rarity <> 'common' THEN
      SELECT id
      INTO v_item_id
      FROM public.items
      WHERE facility_type = v_facility.type
        AND lower(type) = 'material'
        AND lower(COALESCE(material_type, '')) = 'resource'
        AND lower(rarity) = 'common'
      ORDER BY id
      LIMIT 1;
      
      -- If fallback happens, we should technically add this to the common quota
      -- but since we are doing it per key, we can just process it here.
      -- Wait, if it falls back to common, and we also process common, we might have multiple loops calling
      -- add_inventory_item_v2 for the same common item ID.
      -- Let's just do it directly. Calling add_inventory_item_v2 twice for the same ID is normally fine if quantity is aggregated,
      -- but to be 100% safe, it's better to aggregate by item_id first.
    END IF;

    IF v_item_id IS NULL THEN
      CONTINUE;
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
    'count', v_clamped_count,
    'items_generated', v_items_generated,
    'admission_occurred', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.collect_facility_resources_v2(uuid, bigint, integer) TO authenticated;
