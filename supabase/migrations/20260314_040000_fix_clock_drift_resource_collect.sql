-- Fix: Add a 2-second grace period to elapsed_seconds to prevent dropping items due to clock drift.
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
  v_remaining integer;
  v_item_id text;
  v_add_result jsonb;
  v_items_generated jsonb := '[]'::jsonb;
  v_rarity text;
  v_effective_rarity text;
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

  FOR v_rarity, v_quota IN
    WITH rarities(rarity, sort_order) AS (
      VALUES
        ('common', 1),
        ('uncommon', 2),
        ('rare', 3),
        ('epic', 4),
        ('legendary', 5),
        ('mythic', 6)
    ),
    weighted AS (
      SELECT
        rarity,
        sort_order,
        public._plan2_rarity_weight(v_facility.level, rarity) AS weight,
        (public._plan2_rarity_weight(v_facility.level, rarity)::numeric / 100.0) * v_clamped_count AS raw_count
      FROM rarities
    ),
    floored AS (
      SELECT
        rarity,
        sort_order,
        FLOOR(raw_count)::integer AS base_count,
        raw_count - FLOOR(raw_count) AS remainder,
        ABS(mod((COALESCE(p_seed, 0) + sort_order * 48271)::bigint, 4294967295))::numeric / 4294967295.0 AS tie_break
      FROM weighted
    ),
    ranked AS (
      SELECT
        rarity,
        base_count,
        ROW_NUMBER() OVER (ORDER BY remainder DESC, tie_break DESC, sort_order ASC) AS rn
      FROM floored
    ),
    totals AS (
      SELECT COALESCE(SUM(base_count), 0) AS base_sum FROM floored
    )
    SELECT
      ranked.rarity,
      ranked.base_count + CASE WHEN ranked.rn <= GREATEST(v_clamped_count - totals.base_sum, 0) THEN 1 ELSE 0 END AS quota
    FROM ranked
    CROSS JOIN totals
    ORDER BY CASE ranked.rarity
      WHEN 'common' THEN 1
      WHEN 'uncommon' THEN 2
      WHEN 'rare' THEN 3
      WHEN 'epic' THEN 4
      WHEN 'legendary' THEN 5
      WHEN 'mythic' THEN 6
      ELSE 7
    END
  LOOP
    IF v_quota <= 0 THEN
      CONTINUE;
    END IF;

    v_effective_rarity := v_rarity;
    IF GREATEST(v_facility.level, 1) < public._plan2_rarity_unlock_level(v_effective_rarity) THEN
      v_effective_rarity := 'common';
    END IF;

    SELECT id
    INTO v_item_id
    FROM public.items
    WHERE facility_type = v_facility.type
      AND lower(type) = 'material'
      AND lower(COALESCE(material_type, '')) = 'resource'
      AND lower(rarity) = v_effective_rarity
    ORDER BY id
    LIMIT 1;

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
      v_effective_rarity := 'common';
    END IF;

    IF v_item_id IS NULL THEN
      CONTINUE;
    END IF;

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
