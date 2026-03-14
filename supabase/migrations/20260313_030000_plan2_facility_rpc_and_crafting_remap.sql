BEGIN;

CREATE OR REPLACE FUNCTION public._plan2_facility_base_rate(p_facility_type text)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_facility_type
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

CREATE OR REPLACE FUNCTION public._plan2_rarity_unlock_level(p_rarity text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE lower(p_rarity)
    WHEN 'common' THEN 1
    WHEN 'uncommon' THEN 3
    WHEN 'rare' THEN 5
    WHEN 'epic' THEN 7
    WHEN 'legendary' THEN 9
    WHEN 'mythic' THEN 10
    ELSE 10
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public._plan2_rarity_weight(p_level integer, p_rarity text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_level integer := GREATEST(1, LEAST(COALESCE(p_level, 1), 10));
BEGIN
  RETURN CASE v_level
    WHEN 1 THEN CASE lower(p_rarity) WHEN 'common' THEN 100 ELSE 0 END
    WHEN 2 THEN CASE lower(p_rarity) WHEN 'common' THEN 90 WHEN 'uncommon' THEN 10 ELSE 0 END
    WHEN 3 THEN CASE lower(p_rarity) WHEN 'common' THEN 70 WHEN 'uncommon' THEN 25 WHEN 'rare' THEN 5 ELSE 0 END
    WHEN 4 THEN CASE lower(p_rarity) WHEN 'common' THEN 55 WHEN 'uncommon' THEN 30 WHEN 'rare' THEN 13 WHEN 'epic' THEN 2 ELSE 0 END
    WHEN 5 THEN CASE lower(p_rarity) WHEN 'common' THEN 40 WHEN 'uncommon' THEN 30 WHEN 'rare' THEN 20 WHEN 'epic' THEN 8 WHEN 'legendary' THEN 2 ELSE 0 END
    WHEN 6 THEN CASE lower(p_rarity) WHEN 'common' THEN 30 WHEN 'uncommon' THEN 28 WHEN 'rare' THEN 22 WHEN 'epic' THEN 14 WHEN 'legendary' THEN 5 WHEN 'mythic' THEN 1 ELSE 0 END
    WHEN 7 THEN CASE lower(p_rarity) WHEN 'common' THEN 22 WHEN 'uncommon' THEN 25 WHEN 'rare' THEN 23 WHEN 'epic' THEN 18 WHEN 'legendary' THEN 9 WHEN 'mythic' THEN 3 ELSE 0 END
    WHEN 8 THEN CASE lower(p_rarity) WHEN 'common' THEN 15 WHEN 'uncommon' THEN 22 WHEN 'rare' THEN 24 WHEN 'epic' THEN 22 WHEN 'legendary' THEN 12 WHEN 'mythic' THEN 5 ELSE 0 END
    WHEN 9 THEN CASE lower(p_rarity) WHEN 'common' THEN 10 WHEN 'uncommon' THEN 18 WHEN 'rare' THEN 24 WHEN 'epic' THEN 24 WHEN 'legendary' THEN 16 WHEN 'mythic' THEN 8 ELSE 0 END
    ELSE CASE lower(p_rarity) WHEN 'common' THEN 5 WHEN 'uncommon' THEN 14 WHEN 'rare' THEN 22 WHEN 'epic' THEN 26 WHEN 'legendary' THEN 20 WHEN 'mythic' THEN 13 ELSE 0 END
  END;
END;
$$;

DROP FUNCTION IF EXISTS public.get_inventory() CASCADE;

CREATE OR REPLACE FUNCTION public.get_inventory()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_items jsonb;
  v_unassigned_rows uuid[];
  v_slot_num integer;
  v_row uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.inventory inv1
  SET slot_position = COALESCE((SELECT MIN(unused_slot) FROM (
    SELECT generate_series(0, 19) AS unused_slot
    EXCEPT
    SELECT DISTINCT slot_position FROM public.inventory inv2
    WHERE inv2.user_id = v_user_id AND inv2.is_equipped = false AND inv2.slot_position IS NOT NULL
  ) available LIMIT 1), 0),
      updated_at = now()
  WHERE inv1.user_id = v_user_id
    AND inv1.is_equipped = false
    AND inv1.slot_position IS NULL;

  SELECT jsonb_agg(
    jsonb_build_object(
      'row_id', inv.row_id,
      'user_id', inv.user_id,
      'item_id', inv.item_id,
      'quantity', inv.quantity,
      'slot_position', inv.slot_position,
      'is_equipped', COALESCE(inv.is_equipped, false),
      'equip_slot', COALESCE(inv.equip_slot, it.equip_slot),
      'created_at', inv.created_at,
      'updated_at', inv.updated_at,
      'enhancement_level', COALESCE(inv.enhancement_level, 0),
      'obtained_at', inv.obtained_at,
      'is_favorite', COALESCE(inv.is_favorite, false),
      'description', COALESCE(inv.description, it.description),
      'icon', COALESCE(inv.icon, it.icon),
      'name', COALESCE(it.name, inv.item_id),
      'item_type', COALESCE(it.type, 'misc'),
      'rarity', COALESCE(it.rarity, 'common'),
      'facility_type', it.facility_type,
      'attack', COALESCE(it.attack, 0),
      'defense', COALESCE(it.defense, 0),
      'health', COALESCE(it.health, 0),
      'power', COALESCE(it.power, 0),
      'required_level', COALESCE(it.required_level, 1),
      'required_class', it.required_class,
      'weapon_type', COALESCE(inv.weapon_type, it.weapon_type),
      'armor_type', COALESCE(inv.armor_type, it.armor_type),
      'material_type', COALESCE(inv.material_type, it.material_type),
      'potion_type', COALESCE(inv.potion_type, it.potion_type),
      'base_price', COALESCE(inv.base_price, it.base_price, 0),
      'vendor_sell_price', COALESCE(inv.vendor_sell_price, it.vendor_sell_price, 0)
    ) ||
    jsonb_build_object(
      'is_tradeable', COALESCE(inv.is_tradeable, it.is_tradeable, true),
      'is_stackable', COALESCE(inv.is_stackable, it.is_stackable, true),
      'max_stack', COALESCE(inv.max_stack, it.max_stack, 999),
      'max_enhancement', COALESCE(inv.max_enhancement, it.max_enhancement, 0),
      'can_enhance', COALESCE(inv.can_enhance, it.can_enhance, false),
      'heal_amount', COALESCE(inv.heal_amount, it.heal_amount, 0),
      'tolerance_increase', COALESCE(inv.tolerance_increase, it.tolerance_increase, 0),
      'overdose_risk', COALESCE(inv.overdose_risk, it.overdose_risk, 0),
      'recipe_requirements', COALESCE(inv.recipe_requirements, it.recipe_requirements),
      'recipe_result_item_id', COALESCE(inv.recipe_result_item_id, it.recipe_result_item_id),
      'recipe_building_type', COALESCE(inv.recipe_building_type, it.recipe_building_type),
      'recipe_production_time', COALESCE(inv.recipe_production_time, it.recipe_production_time, 0),
      'recipe_required_level', COALESCE(inv.recipe_required_level, it.recipe_required_level, 0),
      'rune_enhancement_type', COALESCE(inv.rune_enhancement_type, it.rune_enhancement_type),
      'rune_success_bonus', COALESCE(inv.rune_success_bonus, it.rune_success_bonus, 0),
      'rune_destruction_reduction', COALESCE(inv.rune_destruction_reduction, it.rune_destruction_reduction, 0),
      'cosmetic_effect', COALESCE(inv.cosmetic_effect, it.cosmetic_effect),
      'cosmetic_bind_on_pickup', COALESCE(inv.cosmetic_bind_on_pickup, it.cosmetic_bind_on_pickup, false),
      'cosmetic_showcase_only', COALESCE(inv.cosmetic_showcase_only, it.cosmetic_showcase_only, false),
      'production_building_type', COALESCE(inv.production_building_type, it.production_building_type),
      'production_rate_per_hour', COALESCE(inv.production_rate_per_hour, it.production_rate_per_hour, 0),
      'production_required_level', COALESCE(inv.production_required_level, it.production_required_level, 0),
      'bound_to_player', COALESCE(inv.bound_to_player, false),
      'pending_sync', COALESCE(inv.pending_sync, false)
    )
    ORDER BY COALESCE(inv.slot_position, 999), inv.created_at
  )
  INTO v_items
  FROM public.inventory inv
  LEFT JOIN public.items it ON inv.item_id = it.id
  WHERE inv.user_id = v_user_id AND inv.is_equipped = false;

  RETURN jsonb_build_object('success', true, 'items', COALESCE(v_items, '[]'::jsonb));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_inventory() TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.start_facility_production(p_facility_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_facility record;
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

  IF v_facility.production_started_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Production already active');
  END IF;

  UPDATE public.facilities
  SET production_started_at = now()
  WHERE id = p_facility_id;

  RETURN jsonb_build_object('success', true, 'facility_id', p_facility_id, 'production_started_at', now());
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_facility_production(uuid) TO authenticated;

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
  v_elapsed_seconds := LEAST(
    120,
    GREATEST(0, EXTRACT(EPOCH FROM (now() - v_facility.production_started_at)))
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
      ELSE 99
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
    'count', COALESCE(v_clamped_count, 0),
    'items_generated', v_items_generated,
    'admission_occurred', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.collect_facility_resources_v2(uuid, bigint, integer) TO authenticated;

WITH remapped AS (
  SELECT
    cr.id,
    jsonb_agg(
      CASE elem.ingredient->>'item_id'
        WHEN 'ancient_rune' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_rune_legendary'::text))
        WHEN 'blessed_essence' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_holy_rare'::text))
        WHEN 'bone' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_ranch_common'::text))
        WHEN 'celestial_honey' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_apiary_legendary'::text))
        WHEN 'copper_ore' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_mining_common'::text))
        WHEN 'cotton' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_farming_common'::text))
        WHEN 'crystal_shard' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_quarry_uncommon'::text))
        WHEN 'divine_tear' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_holy_legendary'::text))
        WHEN 'dragon_root' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_herb_rare'::text))
        WHEN 'dragon_scale' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_ranch_legendary'::text))
        WHEN 'elder_wood' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_lumber_rare'::text))
        WHEN 'energy_shard' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_rune_uncommon'::text))
        WHEN 'fire_essence' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_elemental_common'::text))
        WHEN 'gold_ore' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_mining_rare'::text))
        WHEN 'golden_wheat' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_farming_rare'::text))
        WHEN 'granite' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_quarry_common'::text))
        WHEN 'healing_herb' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_herb_common'::text))
        WHEN 'healing_mushroom' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_mushroom_common'::text))
        WHEN 'holy_water' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_holy_common'::text))
        WHEN 'honey' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_apiary_common'::text))
        WHEN 'immortality_shroom' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_mushroom_legendary'::text))
        WHEN 'iron_ore' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_mining_common'::text))
        WHEN 'leather' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_ranch_common'::text))
        WHEN 'lightning_core' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_elemental_uncommon'::text))
        WHEN 'magic_crystal' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_rune_uncommon'::text))
        WHEN 'magical_grain' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_farming_uncommon'::text))
        WHEN 'mana_crystal' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_holy_uncommon'::text))
        WHEN 'mithril_ore' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_mining_legendary'::text))
        WHEN 'monster_hide' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_ranch_uncommon'::text))
        WHEN 'moonstone' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_mining_legendary'::text))
        WHEN 'oak_wood' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_lumber_common'::text))
        WHEN 'obsidian' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_quarry_rare'::text))
        WHEN 'phoenix_petal' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_herb_legendary'::text))
        WHEN 'pine_wood' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_lumber_common'::text))
        WHEN 'poison_herb' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_herb_uncommon'::text))
        WHEN 'power_rune' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_rune_rare'::text))
        WHEN 'primordial_flame' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_elemental_legendary'::text))
        WHEN 'purification_water' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_holy_rare'::text))
        WHEN 'rare_flower' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_herb_uncommon'::text))
        WHEN 'raw_rune' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_rune_common'::text))
        WHEN 'royal_jelly' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_apiary_rare'::text))
        WHEN 'silver_ore' THEN jsonb_set(elem.ingredient, '{item_id}', to_jsonb('res_mining_uncommon'::text))
        ELSE elem.ingredient
      END
      ORDER BY elem.ord
    ) AS new_ingredients
  FROM public.crafting_recipes cr
  CROSS JOIN LATERAL jsonb_array_elements(cr.ingredients) WITH ORDINALITY AS elem(ingredient, ord)
  WHERE jsonb_typeof(cr.ingredients) = 'array'
  GROUP BY cr.id
)
UPDATE public.crafting_recipes cr
SET ingredients = remapped.new_ingredients,
    updated_at = now()
FROM remapped
WHERE cr.id = remapped.id
  AND cr.ingredients IS DISTINCT FROM remapped.new_ingredients;

COMMIT;
