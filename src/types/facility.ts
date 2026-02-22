// ============================================================
// Facility Types — Kaynak: FacilityManager.gd satır 20-250
// ============================================================

export type FacilityType =
  // Temel Kaynaklar (1-5)
  | "mining"
  | "quarry"
  | "lumber_mill"
  | "clay_pit"
  | "sand_quarry"
  // Organik Kaynaklar (6-10)
  | "farming"
  | "herb_garden"
  | "ranch"
  | "apiary"
  | "mushroom_farm"
  // Mistik Kaynaklar (11-15)
  | "rune_mine"
  | "holy_spring"
  | "shadow_pit"
  | "elemental_forge"
  | "time_well";

export interface FacilityConfig {
  name: string;
  icon: string;
  description: string;
  resources: string[];
  base_rate: number;
  unlock_level: number;
  unlock_cost: number;
  base_upgrade_cost: number;
  upgrade_multiplier: number;
}

export interface PlayerFacility {
  id: string;
  user_id?: string;
  player_id?: string;
  facility_type?: FacilityType;
  type?: FacilityType;
  level: number;
  suspicion?: number;
  suspicion_level?: number;
  is_active: boolean;
  last_collection_at?: string | null;
  last_production_collected_at?: string | null;
  production_started_at: string | null;
  facility_queue: ProductionQueueItem[];
  is_unlocked?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface ProductionQueueItem {
  id: string;
  facility_id: string;
  quantity: number;
  rarity: string;
  started_at: string;
  completes_at: string;
  is_completed: boolean;
}

export type ResourceRarity =
  | "common"
  | "uncommon"
  | "rare"
  | "epic"
  | "legendary";

export interface ResourceRarityDistribution {
  common: number;
  uncommon: number;
  rare: number;
  epic: number;
  legendary: number;
}

// Facility recipes are no longer used for facility production in the web client.
// Keeping crafting recipes separate under `src/types/crafting.ts`.
