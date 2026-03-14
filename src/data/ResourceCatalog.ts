import type { FacilityType, ResourceDefinition, ResourceRarity, ResourceRarityDistribution } from "@/types/facility";

export const RESOURCE_RARITIES: ResourceRarity[] = ["common", "uncommon", "rare", "epic", "legendary", "mythic"];

export const RESOURCE_BASE_VALUES: Record<ResourceRarity, number> = {
  common: 500,
  uncommon: 2000,
  rare: 8000,
  epic: 30000,
  legendary: 120000,
  mythic: 500000,
};

export const PLAN2_RARITY_UNLOCK_LEVELS: Record<ResourceRarity, number> = {
  common: 1,
  uncommon: 2,
  rare: 3,
  epic: 4,
  legendary: 5,
  mythic: 6,
};

export const PLAN2_DROP_RATES_BY_LEVEL: Record<number, ResourceRarityDistribution> = {
  1: { common: 100, uncommon: 0, rare: 0, epic: 0, legendary: 0, mythic: 0 },
  2: { common: 90, uncommon: 10, rare: 0, epic: 0, legendary: 0, mythic: 0 },
  3: { common: 70, uncommon: 25, rare: 5, epic: 0, legendary: 0, mythic: 0 },
  4: { common: 55, uncommon: 30, rare: 13, epic: 2, legendary: 0, mythic: 0 },
  5: { common: 40, uncommon: 30, rare: 20, epic: 8, legendary: 2, mythic: 0 },
  6: { common: 30, uncommon: 28, rare: 22, epic: 14, legendary: 5, mythic: 1 },
  7: { common: 22, uncommon: 25, rare: 23, epic: 18, legendary: 9, mythic: 3 },
  8: { common: 15, uncommon: 22, rare: 24, epic: 22, legendary: 12, mythic: 5 },
  9: { common: 10, uncommon: 18, rare: 24, epic: 24, legendary: 16, mythic: 8 },
  10: { common: 5, uncommon: 14, rare: 22, epic: 26, legendary: 20, mythic: 13 },
};

type ResourceSeed = readonly [ResourceRarity, string, string, string];

const buildFacilityResources = (
  facilityType: FacilityType,
  icon: string,
  seeds: readonly ResourceSeed[]
): ResourceDefinition[] => seeds.map(([rarity, id, name, nameTr]) => ({
  id,
  name,
  name_tr: nameTr,
  description: `${nameTr} (${rarity})`,
  icon,
  facility_type: facilityType,
  rarity,
  base_value: RESOURCE_BASE_VALUES[rarity],
  is_stackable: true,
  max_stack: 999,
}));

export const RESOURCE_CATALOG_LIST: ResourceDefinition[] = [
  ...buildFacilityResources("mining", "⛏️", [
    ["common", "res_mining_common", "Ferrum Crudum", "Ham Demir"],
    ["uncommon", "res_mining_uncommon", "Cuprum Purum", "Saf Bakır"],
    ["rare", "res_mining_rare", "Argentum Vena", "Gümüş Damarı"],
    ["epic", "res_mining_epic", "Aurum Nobile", "Asil Altın"],
    ["legendary", "res_mining_legendary", "Mithrilium", "Mithril"],
    ["mythic", "res_mining_mythic", "Celestium Purus", "Saf Celestium"],
  ]),
  ...buildFacilityResources("quarry", "🪨", [
    ["common", "res_quarry_common", "Saxum Vulgare", "Sıradan Taş"],
    ["uncommon", "res_quarry_uncommon", "Granitus Solidus", "Katı Granit"],
    ["rare", "res_quarry_rare", "Marmor Album", "Beyaz Mermer"],
    ["epic", "res_quarry_epic", "Obsidianum Nigrum", "Kara Obsidyen"],
    ["legendary", "res_quarry_legendary", "Adamantium Fragmentum", "Adamantit Parçası"],
    ["mythic", "res_quarry_mythic", "Petra Aeterna", "Ebedi Taş"],
  ]),
  ...buildFacilityResources("lumber_mill", "🪵", [
    ["common", "res_lumber_common", "Lignum Quercus", "Meşe Kerestesi"],
    ["uncommon", "res_lumber_uncommon", "Lignum Pinus", "Çam Kerestesi"],
    ["rare", "res_lumber_rare", "Lignum Ebenum", "Abanoz"],
    ["epic", "res_lumber_epic", "Lignum Draconum", "Ejder Ağacı"],
    ["legendary", "res_lumber_legendary", "Lignum Mundi", "Dünya Ağacı Dalı"],
    ["mythic", "res_lumber_mythic", "Lignum Yggdrasil", "Yggdrasil Dalı"],
  ]),
  ...buildFacilityResources("clay_pit", "🏺", [
    ["common", "res_clay_common", "Argilla Vulgaris", "Sıradan Kil"],
    ["uncommon", "res_clay_uncommon", "Argilla Ceramica", "Seramik Kili"],
    ["rare", "res_clay_rare", "Argilla Aurata", "Altın Kil"],
    ["epic", "res_clay_epic", "Argilla Draconis", "Ejder Kili"],
    ["legendary", "res_clay_legendary", "Argilla Elementalis", "Elementel Kil"],
    ["mythic", "res_clay_mythic", "Argilla Primaeva", "İlkel Kil"],
  ]),
  ...buildFacilityResources("sand_quarry", "🏜️", [
    ["common", "res_sand_common", "Arena Vulgaris", "Sıradan Kum"],
    ["uncommon", "res_sand_uncommon", "Arena Vitrea", "Cam Kumu"],
    ["rare", "res_sand_rare", "Arena Crystallina", "Kristal Kum"],
    ["epic", "res_sand_epic", "Arena Aurata", "Altın Kum"],
    ["legendary", "res_sand_legendary", "Arena Stellaris", "Yıldız Kumu"],
    ["mythic", "res_sand_mythic", "Arena Temporis", "Zaman Kumu"],
  ]),
  ...buildFacilityResources("farming", "🌾", [
    ["common", "res_farming_common", "Triticum Vulgare", "Sıradan Buğday"],
    ["uncommon", "res_farming_uncommon", "Hordeum Robustum", "Güçlü Arpa"],
    ["rare", "res_farming_rare", "Gossypium Aureum", "Altın Pamuk"],
    ["epic", "res_farming_epic", "Fructus Draconis", "Ejder Meyvesi"],
    ["legendary", "res_farming_legendary", "Semen Vitae", "Yaşam Tohumu"],
    ["mythic", "res_farming_mythic", "Flora Aeterna", "Ebedi Bitki"],
  ]),
  ...buildFacilityResources("herb_garden", "🌿", [
    ["common", "res_herb_common", "Herba Medicinalis", "Şifalı Ot"],
    ["uncommon", "res_herb_uncommon", "Herba Venenata", "Zehirli Ot"],
    ["rare", "res_herb_rare", "Flos Lunaris", "Ay Çiçeği"],
    ["epic", "res_herb_epic", "Radix Draconis", "Ejder Kökü"],
    ["legendary", "res_herb_legendary", "Herba Immortalis", "Ölümsüzlük Otu"],
    ["mythic", "res_herb_mythic", "Essentia Vitalis", "Hayat Özü"],
  ]),
  ...buildFacilityResources("ranch", "🐄", [
    ["common", "res_ranch_common", "Corium Vulgare", "Sıradan Deri"],
    ["uncommon", "res_ranch_uncommon", "Lana Fortis", "Güçlü Yün"],
    ["rare", "res_ranch_rare", "Cornu Bestiae", "Canavar Boynuzu"],
    ["epic", "res_ranch_epic", "Pellis Wyvernae", "Wyvern Derisi"],
    ["legendary", "res_ranch_legendary", "Ungula Unicornis", "Unicorn Tırnağı"],
    ["mythic", "res_ranch_mythic", "Sanguis Phoenicis", "Anka Kanı"],
  ]),
  ...buildFacilityResources("apiary", "🐝", [
    ["common", "res_apiary_common", "Mel Silvestre", "Orman Balı"],
    ["uncommon", "res_apiary_uncommon", "Cera Pura", "Saf Balmumu"],
    ["rare", "res_apiary_rare", "Mel Regale", "Kraliyet Jelesi"],
    ["epic", "res_apiary_epic", "Venenum Apis", "Arı Zehiri Özü"],
    ["legendary", "res_apiary_legendary", "Mel Aureum", "Altın Bal"],
    ["mythic", "res_apiary_mythic", "Ambrosia Divina", "İlahi Ambrosia"],
  ]),
  ...buildFacilityResources("mushroom_farm", "🍄", [
    ["common", "res_mushroom_common", "Fungus Medicinalis", "Şifalı Mantar"],
    ["uncommon", "res_mushroom_uncommon", "Fungus Luminescens", "Parlayan Mantar"],
    ["rare", "res_mushroom_rare", "Fungus Venenatus", "Zehirli Mantar"],
    ["epic", "res_mushroom_epic", "Fungus Crystallinus", "Kristal Mantar"],
    ["legendary", "res_mushroom_legendary", "Fungus Temporis", "Zaman Mantarı"],
    ["mythic", "res_mushroom_mythic", "Fungus Primordialis", "İlkel Mantar"],
  ]),
  ...buildFacilityResources("rune_mine", "🔮", [
    ["common", "res_rune_common", "Lapis Runicus", "Ham Rune Taşı"],
    ["uncommon", "res_rune_uncommon", "Crystallum Magicum", "Büyü Kristali"],
    ["rare", "res_rune_rare", "Fragmentum Energiae", "Enerji Parçası"],
    ["epic", "res_rune_epic", "Nucleus Runicus", "Rune Çekirdeği"],
    ["legendary", "res_rune_legendary", "Cor Arcanum", "Gizemli Kalp"],
    ["mythic", "res_rune_mythic", "Essentia Runica", "Rune Özü"],
  ]),
  ...buildFacilityResources("holy_spring", "💧", [
    ["common", "res_holy_common", "Aqua Sacra", "Kutsal Su"],
    ["uncommon", "res_holy_uncommon", "Crystallum Manae", "Mana Kristali"],
    ["rare", "res_holy_rare", "Aqua Purificata", "Arındırma Suyu"],
    ["epic", "res_holy_epic", "Lacrimae Angelorum", "Melek Gözyaşı"],
    ["legendary", "res_holy_legendary", "Fons Vitae", "Yaşam Kaynağı"],
    ["mythic", "res_holy_mythic", "Aqua Aeterna", "Ebedi Su"],
  ]),
  ...buildFacilityResources("shadow_pit", "🌑", [
    ["common", "res_shadow_common", "Pulvis Umbrae", "Gölge Tozu"],
    ["uncommon", "res_shadow_uncommon", "Crystallum Umbrale", "Gölge Kristali"],
    ["rare", "res_shadow_rare", "Essentia Tenebrarum", "Karanlık Esansı"],
    ["epic", "res_shadow_epic", "Cor Umbrae", "Gölge Kalbi"],
    ["legendary", "res_shadow_legendary", "Nucleus Abyssi", "Uçurum Çekirdeği"],
    ["mythic", "res_shadow_mythic", "Vacuum Aeternale", "Ebedi Boşluk"],
  ]),
  ...buildFacilityResources("elemental_forge", "🔥", [
    ["common", "res_elemental_common", "Ignis Scintilla", "Ateş Kıvılcımı"],
    ["uncommon", "res_elemental_uncommon", "Glacies Fragmentum", "Buz Parçası"],
    ["rare", "res_elemental_rare", "Fulmen Nucleus", "Yıldırım Çekirdeği"],
    ["epic", "res_elemental_epic", "Terra Cor", "Toprak Kalbi"],
    ["legendary", "res_elemental_legendary", "Elementum Purum", "Saf Element"],
    ["mythic", "res_elemental_mythic", "Quintessentia", "Beşinci Element"],
  ]),
  ...buildFacilityResources("time_well", "⏳", [
    ["common", "res_time_common", "Pulvis Temporis", "Zaman Tozu"],
    ["uncommon", "res_time_uncommon", "Fragmentum Horae", "Saat Parçası"],
    ["rare", "res_time_rare", "Crystallum Temporale", "Zaman Kristali"],
    ["epic", "res_time_epic", "Essentia Chronos", "Kronos Esansı"],
    ["legendary", "res_time_legendary", "Momentum Aeternum", "Ebedi An"],
    ["mythic", "res_time_mythic", "Infinitas Temporis", "Sonsuz Zaman"],
  ]),
];

export const RESOURCE_CATALOG = Object.fromEntries(
  RESOURCE_CATALOG_LIST.map((resource) => [resource.id, resource])
) as Record<string, ResourceDefinition>;

export const FACILITY_RESOURCE_IDS = Object.fromEntries(
  Object.entries(
    RESOURCE_CATALOG_LIST.reduce<Record<FacilityType, string[]>>((acc, resource) => {
      if (!acc[resource.facility_type]) {
        acc[resource.facility_type] = [];
      }
      acc[resource.facility_type].push(resource.id);
      return acc;
    }, {
      mining: [], quarry: [], lumber_mill: [], clay_pit: [], sand_quarry: [],
      farming: [], herb_garden: [], ranch: [], apiary: [], mushroom_farm: [],
      rune_mine: [], holy_spring: [], shadow_pit: [], elemental_forge: [], time_well: [],
    })
  ).map(([facilityType, ids]) => [facilityType, ids])
) as Record<FacilityType, string[]>;

export const FACILITY_RESOURCE_BY_RARITY = Object.fromEntries(
  Object.keys(FACILITY_RESOURCE_IDS).map((facilityType) => {
    const defs = RESOURCE_CATALOG_LIST.filter((resource) => resource.facility_type === facilityType);
    return [facilityType, Object.fromEntries(defs.map((resource) => [resource.rarity, resource.id]))];
  })
) as Record<FacilityType, Record<ResourceRarity, string>>;

export function getDropRatesForLevel(level: number): ResourceRarityDistribution {
  const normalizedLevel = Math.max(1, Math.min(10, level));
  return PLAN2_DROP_RATES_BY_LEVEL[normalizedLevel];
}

export function getResourceDefinition(resourceId: string): ResourceDefinition | undefined {
  return RESOURCE_CATALOG[resourceId];
}

export function getFacilityResourceDefinitions(facilityType: FacilityType): ResourceDefinition[] {
  return RESOURCE_CATALOG_LIST.filter((resource) => resource.facility_type === facilityType);
}