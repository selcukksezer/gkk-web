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
  recipe_id: string;
  recipe_name: string;
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

export interface FacilityRecipe {
  id: string;
  facility_type: FacilityType;
  output_item_id: string;
  output_quantity: number;
  input_materials: Record<string, number>;
  gold_cost: number;
  duration_seconds: number;
  required_level: number;
  success_rate: number;
  base_suspicion_increase: number;
  production_speed_bonus: number;
  rarity_distribution: ResourceRarityDistribution;
  min_facility_level: number;
}
