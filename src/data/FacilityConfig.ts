// ============================================================
// Facility Configuration — Kaynak: FacilityManager.gd satır 20-250
// Tüm 15 tesis: Temel (1-5), Organik (6-10), Mistik (11-15)
// ============================================================

import type { FacilityType, FacilityConfig } from "@/types/facility";

export const FACILITY_TYPES: Record<FacilityType, string> = {
  // Temel Kaynaklar (1-5)
  mining: "Maden Ocağı",
  quarry: "Taş Ocağı",
  lumber_mill: "Kereste Fabrikası",
  clay_pit: "Kil Ocağı",
  sand_quarry: "Kum Ocağı",
  // Organik Kaynaklar (6-10)
  farming: "Çiftlik",
  herb_garden: "Ot Bahçesi",
  ranch: "Hayvancılık",
  apiary: "Arıcılık",
  mushroom_farm: "Mantar Çiftliği",
  // Mistik Kaynaklar (11-15)
  rune_mine: "Rune Madeni",
  holy_spring: "Kutsal Kaynak",
  shadow_pit: "Gölge Çukuru",
  elemental_forge: "Elementel Ocak",
  time_well: "Zaman Kuyusu",
};

export const FACILITIES_CONFIG: Record<FacilityType, FacilityConfig> = {
  // ===== TEMEL KAYNAKLAR =====
  mining: {
    name: "Maden Ocağı",
    icon: "⛏️",
    description: "Demir, bakır, altın ve gümüş cevheri çıkarır",
    resources: ["iron_ore", "copper_ore", "gold_ore", "silver_ore"],
    base_rate: 10.0,
    unlock_level: 1,
    unlock_cost: 500,
    base_upgrade_cost: 1000,
    upgrade_multiplier: 1.5,
  },
  quarry: {
    name: "Taş Ocağı",
    icon: "🪨",
    description: "Granit, mermer ve kristal çıkarır",
    resources: ["granite", "marble", "crystal_shard"],
    base_rate: 8.0,
    unlock_level: 2,
    unlock_cost: 800,
    base_upgrade_cost: 1200,
    upgrade_multiplier: 1.5,
  },
  lumber_mill: {
    name: "Kereste Fabrikası",
    icon: "🪵",
    description: "Meşe, çam ve bambu odunu üretir",
    resources: ["oak_wood", "pine_wood", "bamboo"],
    base_rate: 12.0,
    unlock_level: 3,
    unlock_cost: 1000,
    base_upgrade_cost: 1500,
    upgrade_multiplier: 1.5,
  },
  clay_pit: {
    name: "Kil Ocağı",
    icon: "🏺",
    description: "Seramik kili ve tuğla malzemesi çıkarır",
    resources: ["ceramic_clay", "brick_clay"],
    base_rate: 15.0,
    unlock_level: 4,
    unlock_cost: 1200,
    base_upgrade_cost: 1800,
    upgrade_multiplier: 1.5,
  },
  sand_quarry: {
    name: "Kum Ocağı",
    icon: "🏖️",
    description: "Cam kumu ve kristal kumu toplar",
    resources: ["glass_sand", "crystal_sand"],
    base_rate: 20.0,
    unlock_level: 5,
    unlock_cost: 1500,
    base_upgrade_cost: 2000,
    upgrade_multiplier: 1.5,
  },
  // ===== ORGANİK KAYNAKLAR =====
  farming: {
    name: "Çiftlik",
    icon: "🌾",
    description: "Buğday, sebze ve pamuk yetiştirir",
    resources: ["wheat", "vegetables", "cotton"],
    base_rate: 18.0,
    unlock_level: 6,
    unlock_cost: 2000,
    base_upgrade_cost: 2500,
    upgrade_multiplier: 1.5,
  },
  herb_garden: {
    name: "Ot Bahçesi",
    icon: "🌿",
    description: "Şifalı otlar ve nadir bitkiler yetiştirir",
    resources: ["healing_herb", "poison_herb", "rare_flower"],
    base_rate: 10.0,
    unlock_level: 7,
    unlock_cost: 2500,
    base_upgrade_cost: 3000,
    upgrade_multiplier: 1.5,
  },
  ranch: {
    name: "Hayvancılık",
    icon: "🐄",
    description: "Deri, kemik ve yün üretir",
    resources: ["leather", "bone", "wool"],
    base_rate: 12.0,
    unlock_level: 8,
    unlock_cost: 3000,
    base_upgrade_cost: 3500,
    upgrade_multiplier: 1.5,
  },
  apiary: {
    name: "Arıcılık",
    icon: "🐝",
    description: "Bal, balmumu ve arı zehiri toplar",
    resources: ["honey", "beeswax", "bee_venom"],
    base_rate: 8.0,
    unlock_level: 9,
    unlock_cost: 3500,
    base_upgrade_cost: 4000,
    upgrade_multiplier: 1.5,
  },
  mushroom_farm: {
    name: "Mantar Çiftliği",
    icon: "🍄",
    description: "Şifalı ve zehirli mantarlar yetiştirir",
    resources: ["healing_mushroom", "poison_mushroom", "glowing_mushroom"],
    base_rate: 10.0,
    unlock_level: 10,
    unlock_cost: 4000,
    base_upgrade_cost: 5000,
    upgrade_multiplier: 1.5,
  },
  // ===== MİSTİK KAYNAKLAR =====
  rune_mine: {
    name: "Rune Madeni",
    icon: "🔮",
    description: "Ham rune taşları ve büyülü kristaller çıkarır",
    resources: ["raw_rune", "magic_crystal", "energy_shard"],
    base_rate: 5.0,
    unlock_level: 11,
    unlock_cost: 5000,
    base_upgrade_cost: 6000,
    upgrade_multiplier: 1.6,
  },
  holy_spring: {
    name: "Kutsal Kaynak",
    icon: "⛲",
    description: "Kutsal su ve mana kristalleri üretir",
    resources: ["holy_water", "mana_crystal", "purification_water"],
    base_rate: 6.0,
    unlock_level: 12,
    unlock_cost: 6000,
    base_upgrade_cost: 7000,
    upgrade_multiplier: 1.6,
  },
  shadow_pit: {
    name: "Gölge Çukuru",
    icon: "🕳️",
    description: "Karanlık esans ve gölge kristalleri toplar",
    resources: ["dark_essence", "shadow_crystal", "curse_dust"],
    base_rate: 4.0,
    unlock_level: 13,
    unlock_cost: 7000,
    base_upgrade_cost: 8000,
    upgrade_multiplier: 1.6,
  },
  elemental_forge: {
    name: "Elementel Ocak",
    icon: "🔥",
    description: "Ateş, buz ve yıldırım esansı üretir",
    resources: ["fire_essence", "ice_crystal", "lightning_core"],
    base_rate: 5.0,
    unlock_level: 14,
    unlock_cost: 8000,
    base_upgrade_cost: 10000,
    upgrade_multiplier: 1.6,
  },
  time_well: {
    name: "Zaman Kuyusu",
    icon: "⏳",
    description: "Zaman kristali ve hızlandırma tozu üretir",
    resources: ["time_crystal", "aging_dust", "eternity_essence"],
    base_rate: 3.0,
    unlock_level: 15,
    unlock_cost: 10000,
    base_upgrade_cost: 12000,
    upgrade_multiplier: 1.7,
  },
};

export function getFacilityTier(type: FacilityType): "basic" | "organic" | "mystical" {
  const basicTypes: FacilityType[] = ["mining", "quarry", "lumber_mill", "clay_pit", "sand_quarry"];
  const organicTypes: FacilityType[] = ["farming", "herb_garden", "ranch", "apiary", "mushroom_farm"];
  if (basicTypes.includes(type)) return "basic";
  if (organicTypes.includes(type)) return "organic";
  return "mystical";
}

export function getFacilitiesByTier(tier: "basic" | "organic" | "mystical"): FacilityType[] {
  const tiers: Record<string, FacilityType[]> = {
    basic: ["mining", "quarry", "lumber_mill", "clay_pit", "sand_quarry"],
    organic: ["farming", "herb_garden", "ranch", "apiary", "mushroom_farm"],
    mystical: ["rune_mine", "holy_spring", "shadow_pit", "elemental_forge", "time_well"],
  };
  return tiers[tier];
}
