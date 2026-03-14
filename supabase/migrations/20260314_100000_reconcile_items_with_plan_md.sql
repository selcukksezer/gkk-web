BEGIN;

-- Reconcile managed item ids with PLAN_01/02/03/05/07/10 catalogs.
CREATE TEMP TABLE _expected_plan_item_ids (
  id text PRIMARY KEY
) ON COMMIT DROP;

-- 1) Resource ids from PLAN_02: 15 facilities x 6 rarities = 90 ids
WITH facilities(facility) AS (
  VALUES
    ('mining'), ('quarry'), ('lumber_mill'), ('clay_pit'), ('sand_quarry'),
    ('farming'), ('herb_garden'), ('ranch'), ('apiary'), ('mushroom_farm'),
    ('rune_mine'), ('holy_spring'), ('shadow_pit'), ('elemental_forge'), ('time_well')
), rarities(rarity) AS (
  VALUES ('common'), ('uncommon'), ('rare'), ('epic'), ('legendary'), ('mythic')
)
INSERT INTO _expected_plan_item_ids(id)
SELECT format('res_%s_%s', f.facility, r.rarity)
FROM facilities f
CROSS JOIN rarities r;

-- 2) Equipment ids from PLAN_01
WITH rarities(rarity) AS (
  VALUES ('common'), ('uncommon'), ('rare'), ('epic'), ('legendary'), ('mythic')
), equip(id) AS (
  SELECT format('wpn_%s_%s', s.subtype, r.rarity)
  FROM (VALUES ('dagger'), ('sword'), ('axe'), ('staff')) s(subtype)
  CROSS JOIN rarities r

  UNION ALL
  SELECT format('chest_%s_%s', s.subtype, r.rarity)
  FROM (VALUES ('plate'), ('chain'), ('leather'), ('robe')) s(subtype)
  CROSS JOIN rarities r

  UNION ALL
  SELECT format('head_%s_%s', s.subtype, r.rarity)
  FROM (VALUES ('helm'), ('hood'), ('crown'), ('circlet')) s(subtype)
  CROSS JOIN rarities r

  UNION ALL
  SELECT format('legs_%s_%s', s.subtype, r.rarity)
  FROM (VALUES ('greaves'), ('leggings'), ('tassets'), ('pteruges')) s(subtype)
  CROSS JOIN rarities r

  UNION ALL
  SELECT format('boots_%s_%s', s.subtype, r.rarity)
  FROM (VALUES ('sabaton'), ('treads'), ('sandals'), ('moccasins')) s(subtype)
  CROSS JOIN rarities r

  UNION ALL
  SELECT format('gloves_%s_%s', s.subtype, r.rarity)
  FROM (VALUES ('gauntlet'), ('bracers'), ('wraps'), ('mitts')) s(subtype)
  CROSS JOIN rarities r

  UNION ALL
  SELECT format('ring_%s_%s', s.subtype, r.rarity)
  FROM (VALUES ('signet'), ('band'), ('loop'), ('seal')) s(subtype)
  CROSS JOIN rarities r

  UNION ALL
  SELECT format('neck_%s_%s', s.subtype, r.rarity)
  FROM (VALUES ('pendant'), ('amulet'), ('choker'), ('talisman')) s(subtype)
  CROSS JOIN rarities r
)
INSERT INTO _expected_plan_item_ids(id)
SELECT id FROM equip
ON CONFLICT (id) DO NOTHING;

-- 3) Explicit item ids from PLAN docs
INSERT INTO _expected_plan_item_ids(id)
VALUES
  -- Monument resources (PLAN_10)
  ('resource_structural'), ('resource_mystical'), ('resource_critical'),

  -- Runes (PLAN_05)
  ('rune_basic'), ('rune_advanced'), ('rune_superior'), ('rune_legendary'), ('rune_protection'), ('rune_blessed'),

  -- Scrolls (PLAN_01/05)
  ('scroll_upgrade_low'), ('scroll_upgrade_middle'), ('scroll_upgrade_high'),

  -- Catalysts (PLAN_01/03/04)
  ('catalyst_rare'), ('catalyst_epic'), ('catalyst_legendary'), ('catalyst_mythic'),

  -- Potions (PLAN_01)
  ('potion_health_minor'), ('potion_health_major'), ('potion_health_supreme'),
  ('potion_energy_minor'), ('potion_energy_major'), ('potion_energy_supreme'),
  ('potion_attack_buff'), ('potion_defense_buff'), ('potion_luck_buff'), ('potion_xp_buff'),

  -- Han-only items (PLAN_03/07)
  ('han_item_vigor_minor'), ('han_item_vigor_major'),
  ('han_item_elixir_purge'), ('han_item_clarity'), ('han_item_berserk'),
  ('han_item_shadow_brew'), ('han_item_restoration')
ON CONFLICT (id) DO NOTHING;

-- 4) Remove non-PLAN extras only for managed id families
DELETE FROM public.items i
WHERE (
  i.id ~ '^(res_|wpn_|chest_|head_|legs_|boots_|gloves_|ring_|neck_|potion_|rune_|scroll_|catalyst_|han_item_|han_energy_|resource_)'
)
AND NOT EXISTS (
  SELECT 1 FROM _expected_plan_item_ids e WHERE e.id = i.id
);

-- 5) Add/normalize missing explicit non-generated items
INSERT INTO public.items (
  id, name, name_tr, type, sub_type, description, rarity,
  base_price, vendor_sell_price,
  is_tradeable, is_stackable, max_stack,
  shop_available, shop_currency,
  heal_amount, energy_restore, buff_duration,
  tolerance_increase, overdose_risk,
  is_han_only, is_market_tradeable, is_direct_tradeable
)
VALUES
  -- PLAN_01 potions
  ('potion_health_minor', 'Elixir Vitae Minor', 'Kucuk Can Iksiri', 'potion', 'health', '+5,000 HP', 'common', 5000, 1750, true, true, 999, true, 'gold', 5000, 0, 0, 1, 0.00, false, true, true),
  ('potion_health_major', 'Elixir Vitae Major', 'Buyuk Can Iksiri', 'potion', 'health', '+20,000 HP', 'rare', 50000, 17500, true, true, 999, true, 'gold', 20000, 0, 0, 4, 0.02, false, true, true),
  ('potion_health_supreme', 'Elixir Vitae Suprema', 'Yuce Can Iksiri', 'potion', 'health', '+50,000 HP', 'legendary', 300000, 105000, true, true, 999, true, 'gold', 50000, 0, 0, 10, 0.08, false, true, true),

  ('potion_energy_minor', 'Essentia Vigoris Minor', 'Kucuk Enerji Iksiri', 'potion', 'energy', '+10 enerji', 'common', 3500, 1225, true, true, 999, true, 'gold', 0, 10, 0, 1, 0.00, false, true, true),
  ('potion_energy_major', 'Essentia Vigoris Major', 'Buyuk Enerji Iksiri', 'potion', 'energy', '+25 enerji', 'rare', 25000, 8750, true, true, 999, true, 'gold', 0, 25, 0, 3, 0.02, false, true, true),
  ('potion_energy_supreme', 'Essentia Vigoris Suprema', 'Yuce Enerji Iksiri', 'potion', 'energy', '+50 enerji', 'legendary', 120000, 42000, true, true, 999, true, 'gold', 0, 50, 0, 7, 0.06, false, true, true),

  ('potion_attack_buff', 'Furor Bellicum', 'Saldiri Buff Iksiri', 'potion', 'buff', '+20% attack 30 dk', 'epic', 150000, 52500, true, true, 999, true, 'gold', 0, 0, 1800, 6, 0.05, false, true, true),
  ('potion_defense_buff', 'Scutum Magicum', 'Savunma Buff Iksiri', 'potion', 'buff', '+20% defense 30 dk', 'epic', 150000, 52500, true, true, 999, true, 'gold', 0, 0, 1800, 6, 0.05, false, true, true),
  ('potion_luck_buff', 'Fortuna Aurea', 'Sans Buff Iksiri', 'potion', 'buff', '+30% luck 30 dk', 'epic', 180000, 63000, true, true, 999, true, 'gold', 0, 0, 1800, 8, 0.06, false, true, true),
  ('potion_xp_buff', 'Sapientia Accelerata', 'XP Buff Iksiri', 'potion', 'buff', '+50% XP 60 dk', 'legendary', 300000, 105000, true, true, 999, true, 'gold', 0, 0, 3600, 10, 0.08, false, true, true),

  -- PLAN_01/05 enhancement scrolls
  ('scroll_upgrade_low', 'Liber Ascensionis Minor', 'Kucuk Yukseltim Scrollu', 'scroll', 'enhancement', 'Common/Uncommon enhancement', 'uncommon', 25000, 8750, true, true, 999, true, 'gold', 0, 0, 0, 0, 0.00, false, true, true),
  ('scroll_upgrade_middle', 'Liber Ascensionis Medius', 'Orta Yukseltim Scrollu', 'scroll', 'enhancement', 'Rare/Epic enhancement', 'rare', 100000, 35000, true, true, 999, true, 'gold', 0, 0, 0, 0, 0.00, false, true, true),
  ('scroll_upgrade_high', 'Liber Ascensionis Major', 'Buyuk Yukseltim Scrollu', 'scroll', 'enhancement', 'Legendary/Mythic enhancement', 'legendary', 500000, 175000, true, true, 999, true, 'gold', 0, 0, 0, 0, 0.00, false, true, true),

  -- PLAN_01 catalysts (dungeon drop)
  ('catalyst_rare', 'Nucleus Alchemicus', 'Nadir Katalizor', 'material', 'catalyst', 'Rare crafting catalyst', 'rare', 250000, 87500, true, true, 999, false, 'gold', 0, 0, 0, 0, 0.00, false, true, true),
  ('catalyst_epic', 'Cor Transmutationis', 'Destansi Katalizor', 'material', 'catalyst', 'Epic crafting catalyst', 'epic', 1000000, 350000, true, true, 999, false, 'gold', 0, 0, 0, 0, 0.00, false, true, true),
  ('catalyst_legendary', 'Essentia Creationis', 'Efsanevi Katalizor', 'material', 'catalyst', 'Legendary crafting catalyst', 'legendary', 5000000, 1750000, true, true, 999, false, 'gold', 0, 0, 0, 0, 0.00, false, true, true),
  ('catalyst_mythic', 'Primordium Absolutum', 'Mitik Katalizor', 'material', 'catalyst', 'Mythic crafting catalyst', 'mythic', 25000000, 8750000, true, true, 999, false, 'gold', 0, 0, 0, 0, 0.00, false, true, true),

  -- PLAN_07 han vigor items
  ('han_item_vigor_minor', 'Vinum Vigor Minor', 'Kucuk Han Sarabi', 'potion', 'energy', '+50 enerji; tolerance +3', 'common', 100000, 35000, true, true, 999, true, 'gold', 0, 50, 0, 3, 0.00, true, false, false),
  ('han_item_vigor_major', 'Vinum Vigor Major', 'Buyuk Han Sarabi', 'potion', 'energy', '+100 enerji; tolerance +8; overdose riski', 'rare', 400000, 140000, true, true, 999, true, 'gold', 0, 100, 0, 8, 0.05, true, false, false)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_tr = EXCLUDED.name_tr,
  type = EXCLUDED.type,
  sub_type = EXCLUDED.sub_type,
  description = EXCLUDED.description,
  rarity = EXCLUDED.rarity,
  base_price = EXCLUDED.base_price,
  vendor_sell_price = EXCLUDED.vendor_sell_price,
  is_tradeable = EXCLUDED.is_tradeable,
  is_stackable = EXCLUDED.is_stackable,
  max_stack = EXCLUDED.max_stack,
  shop_available = EXCLUDED.shop_available,
  shop_currency = EXCLUDED.shop_currency,
  heal_amount = EXCLUDED.heal_amount,
  energy_restore = EXCLUDED.energy_restore,
  buff_duration = EXCLUDED.buff_duration,
  tolerance_increase = EXCLUDED.tolerance_increase,
  overdose_risk = EXCLUDED.overdose_risk,
  is_han_only = EXCLUDED.is_han_only,
  is_market_tradeable = EXCLUDED.is_market_tradeable,
  is_direct_tradeable = EXCLUDED.is_direct_tradeable;

-- 6) Report any remaining missing PLAN ids (usually means equipment/resource generator was not applied)
DO $$
DECLARE
  v_missing_count integer;
  v_missing_preview text;
BEGIN
  SELECT COUNT(*)
  INTO v_missing_count
  FROM _expected_plan_item_ids e
  LEFT JOIN public.items i ON i.id = e.id
  WHERE i.id IS NULL;

  IF v_missing_count > 0 THEN
    SELECT string_agg(e.id, ', ' ORDER BY e.id)
    INTO v_missing_preview
    FROM (
      SELECT e.id
      FROM _expected_plan_item_ids e
      LEFT JOIN public.items i ON i.id = e.id
      WHERE i.id IS NULL
      ORDER BY e.id
      LIMIT 30
    ) e;

    RAISE NOTICE 'PLAN item sync: % missing ids remain (first 30): %', v_missing_count, v_missing_preview;
  END IF;
END $$;

COMMIT;
