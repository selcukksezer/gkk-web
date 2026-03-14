BEGIN;

-- PLAN_03 §5.5 + PLAN_07 han-only items:
-- Add missing han-only crafting recipes using PLAN_02 resource IDs.
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
  v.output_item_id,
  v.required_level,
  v.production_time_seconds,
  v.success_rate,
  v.xp_reward,
  v.ingredients,
  v.output_item_id,
  'han_only',
  NULL,
  v.ingredients,
  v.gold_cost
FROM (
  VALUES
    (
      'han_item_vigor_minor',
      1,
      1800,
      0.95,
      90,
      '[{"item_id":"res_apiary_rare","quantity":3},{"item_id":"res_herb_common","quantity":2}]'::jsonb,
      50000
    ),
    (
      'han_item_vigor_major',
      15,
      7200,
      0.85,
      180,
      '[{"item_id":"res_apiary_legendary","quantity":5},{"item_id":"res_herb_rare","quantity":3}]'::jsonb,
      200000
    ),
    (
      'han_item_elixir_purge',
      5,
      3600,
      0.90,
      140,
      '[{"item_id":"res_holy_rare","quantity":4},{"item_id":"res_mushroom_common","quantity":3}]'::jsonb,
      100000
    ),
    (
      'han_item_clarity',
      15,
      14400,
      0.80,
      260,
      '[{"item_id":"res_holy_legendary","quantity":5},{"item_id":"res_holy_mythic","quantity":4}]'::jsonb,
      500000
    ),
    (
      'han_item_berserk',
      25,
      21600,
      0.60,
      420,
      '[{"item_id":"res_herb_epic","quantity":5},{"item_id":"res_apiary_epic","quantity":3},{"item_id":"res_elemental_common","quantity":3}]'::jsonb,
      1000000
    ),
    (
      'han_item_shadow_brew',
      25,
      18000,
      0.70,
      360,
      '[{"item_id":"res_shadow_epic","quantity":4},{"item_id":"res_shadow_common","quantity":3}]'::jsonb,
      800000
    ),
    (
      'han_item_restoration',
      40,
      18000,
      0.75,
      460,
      '[{"item_id":"res_herb_legendary","quantity":5},{"item_id":"res_apiary_legendary","quantity":4},{"item_id":"res_holy_common","quantity":3}]'::jsonb,
      800000
    )
) AS v(
  output_item_id,
  required_level,
  production_time_seconds,
  success_rate,
  xp_reward,
  ingredients,
  gold_cost
)
WHERE EXISTS (
  SELECT 1
  FROM public.items i
  WHERE i.id = v.output_item_id
)
AND NOT EXISTS (
  SELECT 1
  FROM public.crafting_recipes cr
  WHERE cr.output_item_id = v.output_item_id
    AND COALESCE(cr.recipe_type, '') = 'han_only'
);

COMMIT;
