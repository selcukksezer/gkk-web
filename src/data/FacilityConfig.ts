// ============================================================
// Facility Configuration — Kaynak: FacilityManager.gd satır 20-250
// Tüm 15 tesis: Temel (1-5), Organik (6-10), Mistik (11-15)
// ============================================================

import type { FacilityType, FacilityConfig } from "@/types/facility";
import { FACILITY_RESOURCE_IDS } from "@/data/ResourceCatalog";

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
    resources: FACILITY_RESOURCE_IDS.mining,
    base_rate: 10.0,
    unlock_level: 1,
    unlock_cost: 50000,
    base_upgrade_cost: 100000,
    upgrade_multiplier: 1.5,
  },
  quarry: {
    name: "Taş Ocağı",
    icon: "🪨",
    description: "Granit, mermer ve kristal çıkarır",
    resources: FACILITY_RESOURCE_IDS.quarry,
    base_rate: 8.0,
    unlock_level: 2,
    unlock_cost: 80000,
    base_upgrade_cost: 120000,
    upgrade_multiplier: 1.5,
  },
  lumber_mill: {
    name: "Kereste Fabrikası",
    icon: "🪵",
    description: "Meşe, çam ve bambu odunu üretir",
    resources: FACILITY_RESOURCE_IDS.lumber_mill,
    base_rate: 12.0,
    unlock_level: 3,
    unlock_cost: 100000,
    base_upgrade_cost: 150000,
    upgrade_multiplier: 1.5,
  },
  clay_pit: {
    name: "Kil Ocağı",
    icon: "🏺",
    description: "Seramik kili ve tuğla malzemesi çıkarır",
    resources: FACILITY_RESOURCE_IDS.clay_pit,
    base_rate: 15.0,
    unlock_level: 4,
    unlock_cost: 120000,
    base_upgrade_cost: 180000,
    upgrade_multiplier: 1.5,
  },
  sand_quarry: {
    name: "Kum Ocağı",
    icon: "🏖️",
    description: "Cam kumu ve kristal kumu toplar",
    resources: FACILITY_RESOURCE_IDS.sand_quarry,
    base_rate: 20.0,
    unlock_level: 5,
    unlock_cost: 150000,
    base_upgrade_cost: 200000,
    upgrade_multiplier: 1.5,
  },
  // ===== ORGANİK KAYNAKLAR =====
  farming: {
    name: "Çiftlik",
    icon: "🌾",
    description: "Buğday, sebze ve pamuk yetiştirir",
    resources: FACILITY_RESOURCE_IDS.farming,
    base_rate: 18.0,
    unlock_level: 6,
    unlock_cost: 200000,
    base_upgrade_cost: 250000,
    upgrade_multiplier: 1.5,
  },
  herb_garden: {
    name: "Ot Bahçesi",
    icon: "🌿",
    description: "Şifalı otlar ve nadir bitkiler yetiştirir",
    resources: FACILITY_RESOURCE_IDS.herb_garden,
    base_rate: 10.0,
    unlock_level: 7,
    unlock_cost: 250000,
    base_upgrade_cost: 300000,
    upgrade_multiplier: 1.5,
  },
  ranch: {
    name: "Hayvancılık",
    icon: "🐄",
    description: "Deri, kemik ve yün üretir",
    resources: FACILITY_RESOURCE_IDS.ranch,
    base_rate: 12.0,
    unlock_level: 8,
    unlock_cost: 300000,
    base_upgrade_cost: 350000,
    upgrade_multiplier: 1.5,
  },
  apiary: {
    name: "Arıcılık",
    icon: "🐝",
    description: "Bal, balmumu ve arı zehiri toplar",
    resources: FACILITY_RESOURCE_IDS.apiary,
    base_rate: 8.0,
    unlock_level: 9,
    unlock_cost: 350000,
    base_upgrade_cost: 400000,
    upgrade_multiplier: 1.5,
  },
  mushroom_farm: {
    name: "Mantar Çiftliği",
    icon: "🍄",
    description: "Şifalı ve zehirli mantarlar yetiştirir",
    resources: FACILITY_RESOURCE_IDS.mushroom_farm,
    base_rate: 10.0,
    unlock_level: 10,
    unlock_cost: 400000,
    base_upgrade_cost: 500000,
    upgrade_multiplier: 1.5,
  },
  // ===== MİSTİK KAYNAKLAR =====
  rune_mine: {
    name: "Rune Madeni",
    icon: "🔮",
    description: "Ham rune taşları ve büyülü kristaller çıkarır",
    resources: FACILITY_RESOURCE_IDS.rune_mine,
    base_rate: 5.0,
    unlock_level: 15,
    unlock_cost: 500000,
    base_upgrade_cost: 600000,
    upgrade_multiplier: 1.6,
  },
  holy_spring: {
    name: "Kutsal Kaynak",
    icon: "⛲",
    description: "Kutsal su ve mana kristalleri üretir",
    resources: FACILITY_RESOURCE_IDS.holy_spring,
    base_rate: 6.0,
    unlock_level: 20,
    unlock_cost: 600000,
    base_upgrade_cost: 700000,
    upgrade_multiplier: 1.6,
  },
  shadow_pit: {
    name: "Gölge Çukuru",
    icon: "🕳️",
    description: "Karanlık esans ve gölge kristalleri toplar",
    resources: FACILITY_RESOURCE_IDS.shadow_pit,
    base_rate: 4.0,
    unlock_level: 25,
    unlock_cost: 700000,
    base_upgrade_cost: 800000,
    upgrade_multiplier: 1.6,
  },
  elemental_forge: {
    name: "Elementel Ocak",
    icon: "🔥",
    description: "Ateş, buz ve yıldırım esansı üretir",
    resources: FACILITY_RESOURCE_IDS.elemental_forge,
    base_rate: 5.0,
    unlock_level: 30,
    unlock_cost: 800000,
    base_upgrade_cost: 1000000,
    upgrade_multiplier: 1.6,
  },
  time_well: {
    name: "Zaman Kuyusu",
    icon: "⏳",
    description: "Zaman kristali ve hızlandırma tozu üretir",
    resources: FACILITY_RESOURCE_IDS.time_well,
    base_rate: 3.0,
    unlock_level: 40,
    unlock_cost: 1000000,
    base_upgrade_cost: 1200000,
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
