BEGIN;

-- PLAN_03 equipment recipes:
-- Seed ONLY PLAN_* item IDs (PLAN_01 naming conventions), excluding legacy/custom IDs.
WITH slot_cfg AS (
  SELECT *
  FROM (VALUES
    ('weapon', 'mining', 'lumber', 'elemental'),
    ('chest', 'mining', 'ranch', 'quarry'),
    ('head', 'quarry', 'mining', 'farming'),
    ('legs', 'ranch', 'farming', 'clay'),
    ('boots', 'ranch', 'lumber', 'sand'),
    ('gloves', 'ranch', 'mining', 'herb'),
    ('ring', 'rune', 'mining', 'holy'),
    ('necklace', 'holy', 'rune', 'shadow')
  ) AS t(slot_group, primary_facility, secondary_facility, tertiary_facility)
), rarity_cfg AS (
  SELECT *
  FROM (VALUES
    ('common', 'common', 5, 'common', 3, 'common', 1, 1, 300, 1.00::numeric, 10000, 50),
    ('uncommon', 'uncommon', 4, 'common', 6, 'common', 3, 5, 900, 0.95::numeric, 50000, 90),
    ('rare', 'rare', 4, 'uncommon', 5, 'uncommon', 3, 15, 3600, 0.85::numeric, 250000, 180),
    ('epic', 'epic', 4, 'rare', 6, 'rare', 4, 25, 14400, 0.70::numeric, 1000000, 320),
    ('legendary', 'legendary', 5, 'epic', 6, 'rare', 5, 40, 43200, 0.50::numeric, 5000000, 520),
    ('mythic', 'mythic', 5, 'legendary', 6, 'epic', 5, 55, 86400, 0.30::numeric, 25000000, 800)
  ) AS t(
    item_rarity,
    primary_rarity,
    primary_qty,
    secondary_rarity,
    secondary_qty,
    tertiary_rarity,
    tertiary_qty,
    required_level,
    production_time_seconds,
    success_rate,
    gold_cost,
    xp_reward
  )
), rarity_names AS (
  SELECT item_rarity FROM rarity_cfg
), plan_equipment_ids AS (
  SELECT ('wpn_' || w.subtype || '_' || r.item_rarity) AS output_item_id, r.item_rarity, 'weapon'::text AS slot_group
  FROM (VALUES ('dagger'), ('sword'), ('axe'), ('staff')) AS w(subtype)
  CROSS JOIN rarity_names r

  UNION ALL

  SELECT ('chest_' || c.subtype || '_' || r.item_rarity) AS output_item_id, r.item_rarity, 'chest'::text AS slot_group
  FROM (VALUES ('plate'), ('chain'), ('leather'), ('robe')) AS c(subtype)
  CROSS JOIN rarity_names r

  UNION ALL

  SELECT ('head_' || h.subtype || '_' || r.item_rarity) AS output_item_id, r.item_rarity, 'head'::text AS slot_group
  FROM (VALUES ('helm'), ('hood'), ('crown'), ('circlet')) AS h(subtype)
  CROSS JOIN rarity_names r

  UNION ALL

  SELECT ('legs_' || l.subtype || '_' || r.item_rarity) AS output_item_id, r.item_rarity, 'legs'::text AS slot_group
  FROM (VALUES ('greaves'), ('leggings'), ('tassets'), ('pteruges')) AS l(subtype)
  CROSS JOIN rarity_names r

  UNION ALL

  SELECT ('boots_' || b.subtype || '_' || r.item_rarity) AS output_item_id, r.item_rarity, 'boots'::text AS slot_group
  FROM (VALUES ('sabaton'), ('treads'), ('sandals'), ('moccasins')) AS b(subtype)
  CROSS JOIN rarity_names r

  UNION ALL

  SELECT ('gloves_' || g.subtype || '_' || r.item_rarity) AS output_item_id, r.item_rarity, 'gloves'::text AS slot_group
  FROM (VALUES ('gauntlet'), ('bracers'), ('wraps'), ('mitts')) AS g(subtype)
  CROSS JOIN rarity_names r

  UNION ALL

  SELECT ('ring_' || rg.subtype || '_' || r.item_rarity) AS output_item_id, r.item_rarity, 'ring'::text AS slot_group
  FROM (VALUES ('signet'), ('band'), ('loop'), ('seal')) AS rg(subtype)
  CROSS JOIN rarity_names r

  UNION ALL

  SELECT ('neck_' || n.subtype || '_' || r.item_rarity) AS output_item_id, r.item_rarity, 'necklace'::text AS slot_group
  FROM (VALUES ('pendant'), ('amulet'), ('choker'), ('talisman')) AS n(subtype)
  CROSS JOIN rarity_names r
), equipment_items AS (
  SELECT p.output_item_id, p.item_rarity, p.slot_group
  FROM plan_equipment_ids p
  JOIN public.items i ON i.id = p.output_item_id
  WHERE COALESCE(i.is_han_only, false) = false
)
INSERT INTO public.crafting_recipes (
  output_item_id,
  required_level,
  production_time_seconds,
  success_rate,
  xp_reward,
  ingredients,
  item_id,
  recipe_type,
  facility_type,
  materials,
  gold_cost
)
SELECT
  e.output_item_id,
  r.required_level,
  r.production_time_seconds,
  r.success_rate,
  r.xp_reward,
  jsonb_build_array(
    jsonb_build_object(
      'item_id', ('res_' || s.primary_facility || '_' || r.primary_rarity),
      'quantity', r.primary_qty
    ),
    jsonb_build_object(
      'item_id', ('res_' || s.secondary_facility || '_' || r.secondary_rarity),
      'quantity', r.secondary_qty
    ),
    jsonb_build_object(
      'item_id', ('res_' || s.tertiary_facility || '_' || r.tertiary_rarity),
      'quantity', r.tertiary_qty
    )
  ) AS ingredients,
  e.output_item_id AS item_id,
  'equipment_plan3' AS recipe_type,
  s.primary_facility AS facility_type,
  jsonb_build_array(
    jsonb_build_object(
      'item_id', ('res_' || s.primary_facility || '_' || r.primary_rarity),
      'quantity', r.primary_qty
    ),
    jsonb_build_object(
      'item_id', ('res_' || s.secondary_facility || '_' || r.secondary_rarity),
      'quantity', r.secondary_qty
    ),
    jsonb_build_object(
      'item_id', ('res_' || s.tertiary_facility || '_' || r.tertiary_rarity),
      'quantity', r.tertiary_qty
    )
  ) AS materials,
  r.gold_cost
FROM equipment_items e
JOIN slot_cfg s
  ON s.slot_group = e.slot_group
JOIN rarity_cfg r
  ON r.item_rarity = e.item_rarity
WHERE e.slot_group IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.crafting_recipes cr
    WHERE cr.output_item_id = e.output_item_id
  );

COMMIT;
