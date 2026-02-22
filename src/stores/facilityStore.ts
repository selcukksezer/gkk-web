// ============================================================
// Facility Store — Kaynak: FacilityManager.gd (1231 satır)
// 15 tesis üretim/yükseltme/toplama/şüphe yönetimi
// Server-authoritative: tüm mutasyonlar RPC üzerinden yapılır
// ============================================================

import { create } from "zustand";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import type { PlayerFacility, FacilityType, FacilityConfig, ProductionQueueItem, ResourceRarity, FacilityRecipe } from "@/types/facility";
import { usePlayerStore } from "./playerStore";

// ── Constants (from FacilityManager.gd) ──────────────────────

export const RARITY_DISTRIBUTION: Record<ResourceRarity, number> = {
  common: 70.0,
  uncommon: 20.0,
  rare: 8.0,
  epic: 1.5,
  legendary: 0.5,
};

export const RARITY_UNLOCK_LEVELS: Record<ResourceRarity, number> = {
  common: 1,
  uncommon: 3,
  rare: 5,
  epic: 7,
  legendary: 10,
};

/** Base rarity weights (level 1). Higher levels scale up rarer drops. */
const RARITY_BASE_WEIGHTS: Record<ResourceRarity, number> = {
  common: 700,
  uncommon: 200,
  rare: 80,
  epic: 15,
  legendary: 5,
};

/** Per-level weight scaling for rarities above common */
const RARITY_LEVEL_SCALING: Partial<Record<ResourceRarity, number>> = {
  uncommon: 15,
  rare: 8,
  epic: 3,
  legendary: 1.5,
};

export const FACILITY_RESOURCES_FULL: Record<FacilityType, string[]> = {
  mining: ["iron_ore", "copper_ore", "silver_ore", "gold_ore", "mithril_ore"],
  quarry: ["granite", "marble", "crystal_shard", "obsidian", "moonstone"],
  lumber_mill: ["oak_wood", "pine_wood", "bamboo", "elder_wood", "world_tree_sap"],
  clay_pit: ["ceramic_clay", "brick_clay", "enchanted_clay", "dragon_clay"],
  sand_quarry: ["glass_sand", "crystal_sand", "star_dust", "void_sand"],
  farming: ["wheat", "vegetables", "cotton", "magical_grain", "golden_wheat"],
  herb_garden: ["healing_herb", "poison_herb", "rare_flower", "dragon_root", "phoenix_petal"],
  ranch: ["leather", "bone", "wool", "monster_hide", "dragon_scale"],
  apiary: ["honey", "beeswax", "bee_venom", "royal_jelly", "celestial_honey"],
  mushroom_farm: ["healing_mushroom", "poison_mushroom", "glowing_mushroom", "ghost_mushroom", "immortality_shroom"],
  rune_mine: ["raw_rune", "magic_crystal", "energy_shard", "power_rune", "ancient_rune"],
  holy_spring: ["holy_water", "mana_crystal", "purification_water", "blessed_essence", "divine_tear"],
  shadow_pit: ["dark_essence", "shadow_crystal", "curse_dust", "void_fragment", "abyss_core"],
  elemental_forge: ["fire_essence", "ice_crystal", "lightning_core", "storm_shard", "primordial_flame"],
  time_well: ["time_crystal", "aging_dust", "eternity_essence", "temporal_shard", "infinity_stone"],
};

export const FACILITIES_CONFIG: Record<FacilityType, FacilityConfig> = {
  mining: { name: "Maden", icon: "⛏️", description: "Cevher çıkarma tesisi", resources: FACILITY_RESOURCES_FULL.mining, base_rate: 10, unlock_level: 1, unlock_cost: 500, base_upgrade_cost: 1000, upgrade_multiplier: 1.5 },
  quarry: { name: "Taş Ocağı", icon: "🪨", description: "Taş ve kristal çıkarma", resources: FACILITY_RESOURCES_FULL.quarry, base_rate: 8, unlock_level: 2, unlock_cost: 800, base_upgrade_cost: 1200, upgrade_multiplier: 1.5 },
  lumber_mill: { name: "Kereste Fabrikası", icon: "🪵", description: "Ahşap üretimi", resources: FACILITY_RESOURCES_FULL.lumber_mill, base_rate: 12, unlock_level: 3, unlock_cost: 1000, base_upgrade_cost: 1500, upgrade_multiplier: 1.5 },
  clay_pit: { name: "Kil Çukuru", icon: "🏺", description: "Kil çıkarma", resources: FACILITY_RESOURCES_FULL.clay_pit, base_rate: 15, unlock_level: 4, unlock_cost: 1200, base_upgrade_cost: 1800, upgrade_multiplier: 1.5 },
  sand_quarry: { name: "Kum Ocağı", icon: "🏜️", description: "Kum ve toz çıkarma", resources: FACILITY_RESOURCES_FULL.sand_quarry, base_rate: 20, unlock_level: 5, unlock_cost: 1500, base_upgrade_cost: 2000, upgrade_multiplier: 1.5 },
  farming: { name: "Çiftlik", icon: "🌾", description: "Tarım ürünleri", resources: FACILITY_RESOURCES_FULL.farming, base_rate: 18, unlock_level: 6, unlock_cost: 2000, base_upgrade_cost: 2500, upgrade_multiplier: 1.5 },
  herb_garden: { name: "Şifalı Otlar Bahçesi", icon: "🌿", description: "Bitki yetiştirme", resources: FACILITY_RESOURCES_FULL.herb_garden, base_rate: 10, unlock_level: 7, unlock_cost: 2500, base_upgrade_cost: 3000, upgrade_multiplier: 1.5 },
  ranch: { name: "Çiftlik Hayvanları", icon: "🐄", description: "Hayvan ürünleri", resources: FACILITY_RESOURCES_FULL.ranch, base_rate: 12, unlock_level: 8, unlock_cost: 3000, base_upgrade_cost: 3500, upgrade_multiplier: 1.5 },
  apiary: { name: "Arı Kovanı", icon: "🐝", description: "Bal ve mum üretimi", resources: FACILITY_RESOURCES_FULL.apiary, base_rate: 8, unlock_level: 9, unlock_cost: 3500, base_upgrade_cost: 4000, upgrade_multiplier: 1.5 },
  mushroom_farm: { name: "Mantar Çiftliği", icon: "🍄", description: "Mantar yetiştirme", resources: FACILITY_RESOURCES_FULL.mushroom_farm, base_rate: 10, unlock_level: 10, unlock_cost: 4000, base_upgrade_cost: 5000, upgrade_multiplier: 1.5 },
  rune_mine: { name: "Rün Madeni", icon: "🔮", description: "Rün taşı çıkarma", resources: FACILITY_RESOURCES_FULL.rune_mine, base_rate: 5, unlock_level: 11, unlock_cost: 5000, base_upgrade_cost: 6000, upgrade_multiplier: 1.6 },
  holy_spring: { name: "Kutsal Pınar", icon: "💧", description: "Kutsal su toplama", resources: FACILITY_RESOURCES_FULL.holy_spring, base_rate: 6, unlock_level: 12, unlock_cost: 6000, base_upgrade_cost: 7000, upgrade_multiplier: 1.6 },
  shadow_pit: { name: "Gölge Çukuru", icon: "🌑", description: "Karanlık öz toplama", resources: FACILITY_RESOURCES_FULL.shadow_pit, base_rate: 4, unlock_level: 13, unlock_cost: 7000, base_upgrade_cost: 8000, upgrade_multiplier: 1.6 },
  elemental_forge: { name: "Element Ocağı", icon: "🔥", description: "Element özü üretimi", resources: FACILITY_RESOURCES_FULL.elemental_forge, base_rate: 5, unlock_level: 14, unlock_cost: 8000, base_upgrade_cost: 10000, upgrade_multiplier: 1.6 },
  time_well: { name: "Zaman Kuyusu", icon: "⏳", description: "Zaman kristali toplama", resources: FACILITY_RESOURCES_FULL.time_well, base_rate: 3, unlock_level: 15, unlock_cost: 10000, base_upgrade_cost: 12000, upgrade_multiplier: 1.7 },
};

const PRODUCTION_ENERGY_COST = 50;
const PRODUCTION_DURATION_SECONDS = 120; // 2 min test value
const RESOURCE_CAP = 100;
const QUEUE_FULL_THRESHOLD = 10;

interface FacilityState {
  // State
  facilities: PlayerFacility[];
  recipes: Record<FacilityType, FacilityRecipe[]>;
  selectedFacilityType: FacilityType | null;
  isLoading: boolean;
  error: string | null;
  lastFetchTime: number;
  lastBribeAt: string | null;

  // Server-backed Actions
  fetchFacilities: (forceRefresh?: boolean) => Promise<void>;
  fetchRecipes: (facilityType: FacilityType) => Promise<FacilityRecipe[]>;
  unlockFacility: (facilityType: FacilityType) => Promise<boolean>;
  upgradeFacility: (facilityId: string) => Promise<boolean>;
  startProduction: (facilityId: string) => Promise<boolean>;
  collectProduction: (facilityId: string) => Promise<unknown>;
  collectResourcesV2: (facilityId: string, seed: number, totalCount: number) => Promise<unknown>;
  bribeOfficials: (facilityType: string, amountGems: number) => Promise<boolean>;
  incrementSuspicion: (facilityId: string, amount?: number) => Promise<boolean>;
  decrementSuspicion: (facilityId: string, amount?: number) => Promise<boolean>;
  syncGlobalRiskToDatabase: (globalSuspicion: number) => Promise<boolean>;
  calculateOfflineProduction: (facilityId: string) => Promise<unknown>;

  // Local helpers / getters
  selectFacility: (type: FacilityType | null) => void;
  getFacility: (type: FacilityType) => PlayerFacility | undefined;
  getFacilityById: (id: string) => PlayerFacility | undefined;
  isFacilityUnlocked: (type: FacilityType) => boolean;
  getFacilityLevel: (type: FacilityType) => number;
  getFacilitySuspicion: (type: FacilityType) => number;
  getProductionQueue: (facilityId: string) => ProductionQueueItem[];
  getUpgradeCost: (facilityType: FacilityType, currentLevel: number) => number;
  getGlobalSuspicionRisk: () => number;
  getRarityWeightsAtLevel: (level: number) => Record<ResourceRarity, number>;
  calculateIdleResources: (facilityType: FacilityType, facilityLevel: number, productionStartedAt: string, totalCount: number) => Array<{ item_id: string; rarity: ResourceRarity }>;
  reset: () => void;
}

const CACHE_DURATION = 60_000; // 60 seconds

export const useFacilityStore = create<FacilityState>()((set, get) => ({
  facilities: [],
  recipes: {},
  selectedFacilityType: null,
  isLoading: false,
  error: null,
  lastFetchTime: 0,
  lastBribeAt: null,

  // ── Fetch from server ──────────────────────────────────────
  fetchFacilities: async (forceRefresh = false) => {
    const { lastFetchTime, facilities } = get();
    const now = Date.now();

    if (!forceRefresh && now - lastFetchTime < CACHE_DURATION && facilities.length > 0) {
      return;
    }

    set({ isLoading: true, error: null });

    try {
      const res = await api.rpc<{ success: boolean; data: PlayerFacility[] }>(
        "get_player_facilities_with_queue"
      );

      if (res.success && res.data) {
        let facilitiesData: PlayerFacility[] = [];
        const data = res.data as Record<string, unknown>;

        if (Array.isArray(data)) {
          facilitiesData = data as unknown as PlayerFacility[];
        } else if (data.data && Array.isArray(data.data)) {
          facilitiesData = data.data as PlayerFacility[];
        }

        // Normalize field names from Supabase
        facilitiesData = facilitiesData.map((f: any) => {
          const timestampToISO = (ts: any) => {
            if (!ts) return new Date().toISOString();
            // Check if it's a Unix timestamp in seconds (< 10^13) or milliseconds (>= 10^13)
            const num = typeof ts === 'string' ? parseInt(ts, 10) : ts;
            if (num < 10000000000) {
              // Likely seconds
              return new Date(num * 1000).toISOString();
            } else {
              // Likely milliseconds
              return new Date(num).toISOString();
            }
          };

          return {
            id: f.id,
            facility_type: (f.facility_type || f.type) as FacilityType,
            level: f.level,
            suspicion: f.suspicion ?? f.suspicion_level ?? 0,
            is_active: f.is_active !== false,
            production_started_at: f.production_started_at,
            facility_queue: (f.facility_queue || []).map((item: any) => ({
              id: item.id,
              facility_id: item.facility_id,
              recipe_id: item.recipe_id || 'unknown_recipe',
              recipe_name: item.recipe_name || item.recipe_id || 'Unknown Recipe',
              quantity: item.quantity || 1,
              rarity: (item.rarity_outcome || 'common').toLowerCase(),
              started_at: timestampToISO(item.started_at),
              completes_at: timestampToISO(item.completed_at),
              is_completed: item.status === 'completed' || item.collected === true,
            })),
          };
        });

        facilitiesData = facilitiesData.filter((f) => f.is_active !== false);

        set({
          facilities: facilitiesData,
          isLoading: false,
          lastFetchTime: now,
        });
      } else {
        set({ isLoading: false, error: res.error || "Tesisler yüklenemedi" });
      }
    } catch (err) {
      set({
        isLoading: false,
        error: err instanceof Error ? err.message : "Tesisler yüklenemedi",
      });
    }
  },

  // ── Fetch recipes for facility ─────────────────────────────
  fetchRecipes: async (facilityType: FacilityType) => {
    const cached = get().recipes[facilityType];
    if (cached && cached.length > 0) {
      return cached;
    }

    try {
      const res = await api.rpc<{ success: boolean; data: any }>(
        "get_facility_recipes_rpc",
        { p_facility_type: facilityType }
      );

      if (res.success && res.data) {
        let recipesData: FacilityRecipe[] = [];
        const data = res.data as any;

        if (Array.isArray(data)) {
          recipesData = data;
        } else if (data.data && Array.isArray(data.data)) {
          recipesData = data.data;
        } else if (data.recipes && Array.isArray(data.recipes)) {
          recipesData = data.recipes;
        }

        set((state) => ({
          recipes: {
            ...state.recipes,
            [facilityType]: recipesData,
          },
        }));

        return recipesData;
      }
      return [];
    } catch (err) {
      console.error(`Failed to fetch recipes for ${facilityType}:`, err);
      return [];
    }
  },

  // ── Unlock facility ────────────────────────────────────────
  unlockFacility: async (facilityType: FacilityType) => {
    const config = FACILITIES_CONFIG[facilityType];
    const playerLevel = usePlayerStore.getState().level;
    const gold = usePlayerStore.getState().gold;

    if (playerLevel < config.unlock_level) {
      set({ error: `Seviye ${config.unlock_level} gerekli` });
      return false;
    }
    if (gold < config.unlock_cost) {
      set({ error: `${config.unlock_cost} altın gerekli` });
      return false;
    }

    const res = await api.rpc("unlock_facility", { p_type: facilityType });
    if (res.success) {
      usePlayerStore.getState().updateGold(gold - config.unlock_cost);
      await get().fetchFacilities(true);
      return true;
    }
    set({ error: res.error || "Tesis açılamadı" });
    return false;
  },

  // ── Upgrade facility ───────────────────────────────────────
  upgradeFacility: async (facilityId: string) => {
    const facility = get().getFacilityById(facilityId);
    if (!facility) return false;

    const facilityType = facility.facility_type;
    const cost = get().getUpgradeCost(facilityType, facility.level);

    const gold = usePlayerStore.getState().gold;

    if (gold < cost) {
      set({ error: `${cost} altın gerekli` });
      return false;
    }

    const res = await api.rpc("upgrade_facility", { p_facility_id: facilityId });
    if (res.success) {
      usePlayerStore.getState().updateGold(gold - cost);
      await get().fetchFacilities(true);
      return true;
    }
    set({ error: res.error || "Yükseltme başarısız" });
    return false;
  },

  // ── Start production (costs 50 energy) ─────────────────────
  startProduction: async (facilityId: string) => {
    const playerStore = usePlayerStore.getState();
    if (playerStore.energy < PRODUCTION_ENERGY_COST) {
      set({ error: `${PRODUCTION_ENERGY_COST} enerji gerekli` });
      return false;
    }

    // Prison check
    if (playerStore.inPrison) {
      set({ error: "Hapisteyken üretim başlatamazsınız!" });
      return false;
    }

    const res = await api.rpc("start_facility_production", { p_facility_id: facilityId });
    if (res.success) {
      playerStore.consumeEnergy(PRODUCTION_ENERGY_COST);
      await get().fetchFacilities(true);
      return true;
    }
    set({ error: res.error || "Üretim başlatılamadı" });
    return false;
  },

  // ── Collect production (basic) ─────────────────────────────
  collectProduction: async (facilityId: string) => {
    // Prison check on collection
    if (usePlayerStore.getState().inPrison) {
      set({ error: "Hapisteyken üretim toplayamazsınız!" });
      return null;
    }

    const res = await api.rpc<unknown>("collect_facility_production", {
      p_facility_id: facilityId,
    });

    if (res.success) {
      // Increment suspicion after collection
      await get().incrementSuspicion(facilityId, 5);
      await get().fetchFacilities(true);
      return res.data;
    }
    set({ error: res.error || "Toplama başarısız" });
    return null;
  },

  // ── Collect resources V2 (with deterministic seed) ─────────
  collectResourcesV2: async (facilityId: string, seed: number, totalCount: number) => {
    const res = await api.rpc<unknown>("collect_facility_resources_v2", {
      p_facility_id: facilityId,
      p_seed: seed,
      p_total_count: totalCount,
    });
    if (res.success) {
      await get().fetchFacilities(true);
      return res.data;
    }
    set({ error: res.error || "V2 toplama başarısız" });
    return null;
  },

  // ── Bribe officials ────────────────────────────────────────
  bribeOfficials: async (facilityType: string, amountGems: number) => {
    const res = await api.rpc("bribe_officials", {
      p_facility_type: facilityType,
      p_amount_gems: amountGems,
    });
    if (res.success) {
      set({ lastBribeAt: new Date().toISOString() });
      await get().fetchFacilities(true);
      return true;
    }
    set({ error: res.error || "Rüşvet başarısız" });
    return false;
  },

  // ── Suspicion management ───────────────────────────────────
  incrementSuspicion: async (facilityId: string, amount = 5) => {
    const res = await api.rpc("increment_facility_suspicion", {
      p_facility_id: facilityId,
      p_amount: amount,
    });
    return res.success;
  },

  decrementSuspicion: async (facilityId: string, amount = 10) => {
    const res = await api.rpc("decrement_facility_suspicion", {
      p_facility_id: facilityId,
      p_amount: amount,
    });
    return res.success;
  },

  syncGlobalRiskToDatabase: async (globalSuspicion: number) => {
    const res = await api.rpc("update_global_suspicion_level", {
      p_global_suspicion: globalSuspicion,
    });
    return res.success;
  },

  // ── Offline production ─────────────────────────────────────
  calculateOfflineProduction: async (facilityId: string) => {
    const res = await api.rpc("calculate_offline_production", {
      p_facility_id: facilityId,
    });
    if (res.success) return res.data;
    return null;
  },

  // ── Selection ──────────────────────────────────────────────
  selectFacility: (type: FacilityType | null) => set({ selectedFacilityType: type }),

  // ── Getters ────────────────────────────────────────────────
  getFacility: (type: FacilityType) =>
    get().facilities.find((f) => f.facility_type === type),

  getFacilityById: (id: string) =>
    get().facilities.find((f) => f.id === id),

  isFacilityUnlocked: (type: FacilityType) =>
    get().facilities.some((f) => f.facility_type === type),

  getFacilityLevel: (type: FacilityType) =>
    get().getFacility(type)?.level ?? 0,

  getFacilitySuspicion: (type: FacilityType) =>
    get().getFacility(type)?.suspicion ?? 0,

  getProductionQueue: (facilityId: string) => {
    const facility = get().facilities.find((f) => f.id === facilityId);
    return facility?.facility_queue || [];
  },

  // ── Upgrade cost formula: base_upgrade_cost * pow(upgrade_multiplier, current_level) ──
  getUpgradeCost: (facilityType: FacilityType, currentLevel: number) => {
    const config = FACILITIES_CONFIG[facilityType];
    return Math.floor(config.base_upgrade_cost * Math.pow(config.upgrade_multiplier, currentLevel));
  },

  // ── Global suspicion risk formula ──────────────────────────
  // (active_count * 5) + int(level_sum * 0.5), clamped 0-100
  // active = production_started_at != null AND > last_bribe_at
  getGlobalSuspicionRisk: () => {
    const { facilities, lastBribeAt } = get();
    const bribeThreshold = lastBribeAt ?? "1970-01-01T00:00:00Z";

    let activeCount = 0;
    let levelSum = 0;

    for (const f of facilities) {
      if (
        f.production_started_at &&
        f.production_started_at > bribeThreshold
      ) {
        activeCount++;
        levelSum += f.level;
      }
    }

    const risk = (activeCount * 5) + Math.floor(levelSum * 0.5);
    return Math.max(0, Math.min(100, risk));
  },

  // ── Rarity weights at level (scaled) ──────────────────────
  getRarityWeightsAtLevel: (level: number): Record<ResourceRarity, number> => {
    const weights: Record<ResourceRarity, number> = { ...RARITY_BASE_WEIGHTS };
    if (level > 1) {
      for (const [rarity, scaling] of Object.entries(RARITY_LEVEL_SCALING)) {
        weights[rarity as ResourceRarity] += (level - 1) * (scaling as number);
      }
    }
    return weights;
  },

  // ── Deterministic idle resource calculation (LCG RNG) ──────
  calculateIdleResources: (
    facilityType: FacilityType,
    facilityLevel: number,
    productionStartedAt: string,
    totalCount: number
  ): Array<{ item_id: string; rarity: ResourceRarity }> => {
    const resources = FACILITY_RESOURCES_FULL[facilityType] || [];
    if (resources.length === 0 || totalCount === 0) return [];

    const clampedCount = Math.min(totalCount, RESOURCE_CAP);

    // Deterministic seed from production_started_at
    let detSeed = hashString(productionStartedAt) % 2147483647;
    if (detSeed < 0) detSeed = -detSeed;

    // Build rarity weights at this level
    const weights = get().getRarityWeightsAtLevel(facilityLevel);
    const rarities: ResourceRarity[] = ["common", "uncommon", "rare", "epic", "legendary"];
    const totalWeight = rarities.reduce((sum, r) => sum + weights[r], 0);

    const results: Array<{ item_id: string; rarity: ResourceRarity }> = [];

    for (let i = 1; i <= clampedCount; i++) {
      // LCG RNG matching Godot: ((seed + i) * 16807) % 2147483647
      const rngVal = ((detSeed + i) * 16807) % 2147483647 / 2147483647;

      // Select rarity by cumulative threshold
      let selectedRarity: ResourceRarity = "common";
      let cumulative = 0;
      for (const r of rarities) {
        cumulative += weights[r] / totalWeight;
        if (rngVal < cumulative) {
          selectedRarity = r;
          break;
        }
      }

      // Check if rarity is unlocked at facility level
      if (facilityLevel < RARITY_UNLOCK_LEVELS[selectedRarity]) {
        selectedRarity = "common"; // Downgrade to common
      }

      // Select resource index by rarity
      let resourceIndex: number;
      switch (selectedRarity) {
        case "common":
          resourceIndex = (detSeed + i) % 2; // index 0 or 1
          break;
        case "uncommon":
          resourceIndex = 2;
          break;
        case "rare":
        case "epic":
          resourceIndex = 3;
          break;
        case "legendary":
          resourceIndex = 4;
          break;
        default:
          resourceIndex = 0;
      }

      // Clamp to pool size
      resourceIndex = Math.min(resourceIndex, resources.length - 1);

      results.push({
        item_id: resources[resourceIndex],
        rarity: selectedRarity,
      });
    }

    return results;
  },

  reset: () =>
    set({
      facilities: [],
      selectedFacilityType: null,
      isLoading: false,
      error: null,
      lastFetchTime: 0,
      lastBribeAt: null,
    }),
}));

// Simple string hash (matches Godot's hash() for deterministic seed)
function hashString(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash |= 0; // Convert to 32bit integer
  }
  return hash;
}
