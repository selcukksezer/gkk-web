BEGIN;

-- First ensure the items exist in the items table
INSERT INTO public.items (id, name, description, item_type, rarity, max_stack, is_tradable)
VALUES
  ('potion_minor_hp', 'Küçük Can İksiri', 'Az miktarda can yeniler.', 'potion', 'common', 999, true),
  ('potion_lesser_hp', 'Düşük Can İksiri', 'Bir miktar can yeniler.', 'potion', 'common', 999, true),
  ('potion_hp', 'Can İksiri', 'Orta miktarda can yeniler.', 'potion', 'uncommon', 999, true),
  ('potion_greater_hp', 'Büyük Can İksiri', 'Yüksek miktarda can yeniler.', 'potion', 'rare', 999, true),
  ('potion_superior_hp', 'Üstün Can İksiri', 'Çok yüksek miktarda can yeniler.', 'potion', 'epic', 999, true),
  ('potion_suprema_hp', 'Mükemmel Can İksiri', 'Devasa miktarda can yeniler.', 'potion', 'legendary', 999, true),
  
  ('potion_atk_buff', 'Saldırı İksiri', 'Saldırı gücünü artırır.', 'potion', 'uncommon', 999, true),
  ('potion_def_buff', 'Savunma İksiri', 'Savunmayı artırır.', 'potion', 'uncommon', 999, true),
  ('potion_crit_buff', 'Kritik İksiri', 'Kritik vuruş şansını artırır.', 'potion', 'rare', 999, true),
  ('potion_luck_buff', 'Şans İksiri', 'Şansı artırır.', 'potion', 'rare', 999, true),
  
  ('han_potion_berserk', 'Han Vahşet İksiri', 'Güçlü bir öfke durumu sağlar.', 'potion', 'epic', 999, true),
  ('han_potion_shadow', 'Han Gölge İksiri', 'Gizlenme yeteneğini artırır.', 'potion', 'rare', 999, true),
  ('han_potion_enhanced', 'Han Gelişmiş İksir', 'Tüm istatistikleri geçici olarak artırır.', 'potion', 'epic', 999, true),
  
  ('han_energy_small', 'Küçük Han Enerjisi', 'Han enerjisini bir miktar yeniler.', 'han_item', 'common', 999, true),
  ('han_energy_large', 'Büyük Han Enerjisi', 'Han enerjisini çok miktarda yeniler.', 'han_item', 'uncommon', 999, true)
ON CONFLICT (id) DO NOTHING;

-- Insert crafting recipes for potions and Han energy items
WITH new_recipes(
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
) AS (
  VALUES
  -- HP Potions
  (
    'potion_minor_hp', 1, 30, 1.0, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_herb_common','quantity',1)),
    'potion_minor_hp', 'potion', 'herb_garden',
    jsonb_build_array(jsonb_build_object('item_id','res_herb_common','quantity',1)),
    100
  ),
  (
    'potion_lesser_hp', 1, 60, 1.0, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_herb_common','quantity',2)),
    'potion_lesser_hp', 'potion', 'herb_garden',
    jsonb_build_array(jsonb_build_object('item_id','res_herb_common','quantity',2)),
    300
  ),
  (
    'potion_hp', 2, 120, 0.98, 0,
    jsonb_build_array(
      jsonb_build_object('item_id','res_herb_uncommon','quantity',2),
      jsonb_build_object('item_id','res_mushroom_common','quantity',1)
    ),
    'potion_hp', 'potion', 'mushroom_farm',
    jsonb_build_array(jsonb_build_object('item_id','res_herb_uncommon','quantity',2)),
    1500
  ),
  (
    'potion_greater_hp', 3, 300, 0.95, 0,
    jsonb_build_array(
      jsonb_build_object('item_id','res_herb_uncommon','quantity',4),
      jsonb_build_object('item_id','res_mushroom_uncommon','quantity',1)
    ),
    'potion_greater_hp', 'potion', 'mushroom_farm',
    jsonb_build_array(jsonb_build_object('item_id','res_herb_uncommon','quantity',4)),
    6000
  ),
  (
    'potion_superior_hp', 5, 900, 0.90, 0,
    jsonb_build_array(
      jsonb_build_object('item_id','res_herb_rare','quantity',4),
      jsonb_build_object('item_id','res_mushroom_rare','quantity',2)
    ),
    'potion_superior_hp', 'potion', 'mushroom_farm',
    jsonb_build_array(jsonb_build_object('item_id','res_herb_rare','quantity',4)),
    30000
  ),
  (
    'potion_suprema_hp', 7, 1800, 0.80, 0,
    jsonb_build_array(
      jsonb_build_object('item_id','res_herb_legendary','quantity',6),
      jsonb_build_object('item_id','res_mushroom_epic','quantity',4)
    ),
    'potion_suprema_hp', 'potion', 'mushroom_farm',
    jsonb_build_array(jsonb_build_object('item_id','res_herb_legendary','quantity',6)),
    120000
  ),

  -- Buff Potions
  (
    'potion_atk_buff', 2, 300, 0.98, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_herb_uncommon','quantity',3)),
    'potion_atk_buff', 'potion', 'herb_garden',
    jsonb_build_array(jsonb_build_object('item_id','res_herb_uncommon','quantity',3)),
    2000
  ),
  (
    'potion_def_buff', 2, 300, 0.98, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_herb_uncommon','quantity',3)),
    'potion_def_buff', 'potion', 'herb_garden',
    jsonb_build_array(jsonb_build_object('item_id','res_herb_uncommon','quantity',3)),
    2000
  ),
  (
    'potion_crit_buff', 4, 600, 0.95, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_rune_uncommon','quantity',2), jsonb_build_object('item_id','res_mushroom_uncommon','quantity',2)),
    'potion_crit_buff', 'potion', 'rune_mine',
    jsonb_build_array(jsonb_build_object('item_id','res_rune_uncommon','quantity',2)),
    15000
  ),
  (
    'potion_luck_buff', 4, 600, 0.95, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_apiary_uncommon','quantity',2), jsonb_build_object('item_id','res_herb_uncommon','quantity',2)),
    'potion_luck_buff', 'potion', 'apiary',
    jsonb_build_array(jsonb_build_object('item_id','res_apiary_uncommon','quantity',2)),
    15000
  ),

  -- Han (black-market) Potions
  (
    'han_potion_berserk', 6, 1200, 0.85, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_mushroom_epic','quantity',3), jsonb_build_object('item_id','res_elemental_epic','quantity',1)),
    'han_potion_berserk', 'potion', 'mushroom_farm',
    jsonb_build_array(jsonb_build_object('item_id','res_mushroom_epic','quantity',3)),
    75000
  ),
  (
    'han_potion_shadow', 5, 900, 0.88, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_shadow_rare','quantity',2), jsonb_build_object('item_id','res_herb_rare','quantity',2)),
    'han_potion_shadow', 'potion', 'shadow_pit',
    jsonb_build_array(jsonb_build_object('item_id','res_shadow_rare','quantity',2)),
    40000
  ),
  (
    'han_potion_enhanced', 5, 900, 0.88, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_mushroom_rare','quantity',3), jsonb_build_object('item_id','res_elemental_uncommon','quantity',2)),
    'han_potion_enhanced', 'potion', 'elemental_forge',
    jsonb_build_array(jsonb_build_object('item_id','res_mushroom_rare','quantity',3)),
    50000
  ),

  -- Han-only energy items (Han items)
  (
    'han_energy_small', 1, 60, 1.0, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_apiary_common','quantity',1), jsonb_build_object('item_id','res_clay_common','quantity',1)),
    'han_energy_small', 'han_item', 'apiary',
    jsonb_build_array(jsonb_build_object('item_id','res_apiary_common','quantity',1)),
    5000
  ),
  (
    'han_energy_large', 1, 120, 1.0, 0,
    jsonb_build_array(jsonb_build_object('item_id','res_apiary_uncommon','quantity',2), jsonb_build_object('item_id','res_clay_common','quantity',2)),
    'han_energy_large', 'han_item', 'apiary',
    jsonb_build_array(jsonb_build_object('item_id','res_apiary_uncommon','quantity',2)),
    15000
  )
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
  nr.output_item_id,
  nr.required_level,
  nr.production_time_seconds,
  nr.success_rate,
  nr.xp_reward,
  nr.ingredients,
  nr.item_id,
  nr.recipe_type,
  nr.facility_type,
  nr.materials,
  nr.gold_cost
FROM new_recipes nr
WHERE NOT EXISTS (
  SELECT 1 FROM public.crafting_recipes cr WHERE cr.output_item_id = nr.output_item_id
);

COMMIT;
