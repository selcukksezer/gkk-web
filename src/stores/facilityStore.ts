// ============================================================
// Facility Store — Kaynak: FacilityManager.gd (1231 satır)
// 15 tesis üretim/yükseltme/toplama/şüphe yönetimi
// Server-authoritative: tüm mutasyonlar RPC üzerinden yapılır
// ============================================================

import { create } from "zustand";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import type { PlayerFacility, FacilityType, FacilityConfig, ProductionQueueItem, ResourceRarity } from "@/types/facility";
import { usePlayerStore } from "./playerStore";
import { useInventoryStore } from "./inventoryStore";

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
export const PRODUCTION_DURATION_SECONDS = 120; // 2 min test value
const RESOURCE_CAP = 100;
const QUEUE_FULL_THRESHOLD = 10;

interface FacilityState {
  // State
  facilities: PlayerFacility[];
  selectedFacilityType: FacilityType | null;
  isLoading: boolean;
  error: string | null;
  lastFetchTime: number;
  lastBribeAt: string | null;
  // Track reconciled timestamps to survive fetch overwrites
  reconciledStartTimes: Record<string, string>; // facilityId -> reconciled ISO timestamp

  // Server-backed Actions
  fetchFacilities: (forceRefresh?: boolean) => Promise<void>;
  // fetchRecipes removed: facility recipes are not used for facility production
  unlockFacility: (facilityType: FacilityType) => Promise<boolean>;
  upgradeFacility: (facilityId: string) => Promise<boolean>;
  startProduction: (facilityId: string, recipeId?: string, quantity?: number) => Promise<boolean>;
  collectProduction: (facilityId: string) => Promise<unknown>;
  collectResourcesV2: (facilityId: string, seed: number, totalCount: number) => Promise<unknown>;
  bribeOfficials: (facilityType: string, amountGems: number) => Promise<boolean>;
  incrementSuspicion: (facilityId: string, amount?: number) => Promise<boolean>;
  decrementSuspicion: (facilityId: string, amount?: number) => Promise<boolean>;
  syncGlobalRiskToDatabase: (globalSuspicion: number) => Promise<boolean>;
  calculateOfflineProduction: (facilityId: string) => Promise<unknown>;
  resetAllProduction: () => Promise<{ success: boolean; facilities_reset?: number; queue_items_deleted?: number } | { success: false }>;

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
  selectedFacilityType: null,
  isLoading: false,
  error: null,
  lastFetchTime: 0,
  lastBribeAt: null,
  reconciledStartTimes: {}, // Track reconciled timestamps

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
          const timestampToISO = (ts: any): string | null => {
                    if (ts === null || ts === undefined || ts === "" ) return null;
                    // If it's a numeric string or number, attempt numeric parse
                    let num: number | null = null;
                    if (typeof ts === 'number') num = ts;
                    else if (typeof ts === 'string' && /^\d+$/.test(ts)) num = parseInt(ts, 10);

                    if (typeof num === 'number' && !Number.isNaN(num)) {
                      // Seconds vs milliseconds
                      if (num < 10000000000) return new Date(num * 1000).toISOString();
                      return new Date(num).toISOString();
                    }

                    // Try parsing ISO-like strings
                    const parsed = Date.parse(String(ts));
                    if (!Number.isNaN(parsed)) return new Date(parsed).toISOString();

                    return null;
                  };

          return {
            id: f.id,
            facility_type: (f.facility_type || f.type) as FacilityType,
            level: f.level,
            suspicion: f.suspicion ?? f.suspicion_level ?? 0,
            is_active: f.is_active !== false,
            // Normalize production timestamp (or null when missing)
            production_started_at: timestampToISO(f.production_started_at) || null,
            facility_queue: (f.facility_queue || []).map((item: any) => {
              const started = timestampToISO(item.started_at) || null;
              const completed = timestampToISO(item.completed_at) || null;
              return {
                id: item.id,
                facility_id: item.facility_id,
                quantity: item.quantity || 1,
                rarity: (item.rarity_outcome || item.rarity || 'common').toLowerCase(),
                started_at: started,
                completes_at: completed,
                is_completed: item.status === 'completed' || item.collected === true || !!item.completed_at,
              };
            }),
          };
        });

        facilitiesData = facilitiesData.filter((f) => f.is_active !== false);

        // Restore any reconciled timestamps that were in the old state
        // This preserves reconciliation across fetch cycles (e.g., polling)
        const reconciledTimestamps = get().reconciledStartTimes;
        const facilitiesWithReconciliation = facilitiesData.map((f) => {
          if (reconciledTimestamps[f.id] && reconciledTimestamps[f.id] !== f.production_started_at) {
            // Facility has a reconciled timestamp; restore it
            return { ...f, production_started_at: reconciledTimestamps[f.id] };
          }
          return f;
        });

        set({
          facilities: facilitiesWithReconciliation,
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
  // recipes fetching removed — facilities no longer use recipes

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
      // Update gold locally first (Godot does this)
      usePlayerStore.getState().updateGold(gold - cost);
      // Wait for server settle (Godot timing)
      await new Promise((r) => setTimeout(r, 500));
      // Refetch facilities from server (Godot: fetch_my_facilities(true))
      await get().fetchFacilities(true);
      // Refresh player data from server (Godot: State.refresh_data())
      await usePlayerStore.getState().refreshData();
      return true;
    }
    set({ error: res.error || "Yükseltme başarısız" });
    return false;
  },

  // ── Start production (costs 50 energy) ─────────────────────
  // Godot: FacilityManager.gd lines 999-1048
  startProduction: async (facilityId: string, recipeId?: string, quantity: number = 1) => {
    const playerStore = usePlayerStore.getState();
    if (playerStore.energy < PRODUCTION_ENERGY_COST) {
      set({ error: `${PRODUCTION_ENERGY_COST} enerji gerekli` });
      return false;
    }

    if (playerStore.inPrison) {
      set({ error: "Hapisteyken üretim başlatamazsınız!" });
      return false;
    }

    const params: Record<string, unknown> = { p_facility_id: facilityId };
    console.log("[facilityStore] startProduction RPC call with params:", params);
    const res = await api.rpc("start_facility_production", params);
    console.log("[facilityStore] startProduction RPC response:", res);
    
    if (res.success) {
      playerStore.consumeEnergy(PRODUCTION_ENERGY_COST);
      
      try {
        const facility = get().getFacilityById(facilityId);
        if (facility) {
          const durationMs = PRODUCTION_DURATION_SECONDS * 1000;
          const nowIso = new Date().toISOString();
          const completesAt = new Date(Date.now() + durationMs).toISOString();
          const tempItem = {
            id: `tmp-${Date.now()}`,
            facility_id: facilityId,
            quantity: quantity || 1,
            rarity: "common",
            started_at: nowIso,
            completes_at: completesAt,
            is_completed: false,
          } as any;

          set((state) => ({
            facilities: state.facilities.map((f) => {
              if (f.id !== facilityId) return f;
              return {
                ...f,
                production_started_at: f.production_started_at || nowIso,
                facility_queue: [...(f.facility_queue || []), tempItem],
              } as any;
            }),
          }));
        }
      } catch (err) {
        console.warn("Optimistic queue update failed:", err);
      }
      
      // Godot: FacilityManager.gd lines 1019-1022 (similar timing)
      await new Promise((r) => setTimeout(r, 700));

      // Calculate the known bribe threshold upfront before ANY fetch
      let bribeThreshold = NaN;
      try {
        const facilityStoreTs = get().lastBribeAt ? Date.parse(get().lastBribeAt) : NaN;
        const playerStoreTs = usePlayerStore.getState().lastBribeAt ? Date.parse(usePlayerStore.getState().lastBribeAt) : NaN;
        bribeThreshold = Number.isNaN(facilityStoreTs)
          ? playerStoreTs
          : Number.isNaN(playerStoreTs)
          ? facilityStoreTs
          : Math.min(facilityStoreTs, playerStoreTs);
      } catch (err) {
        console.warn("[facilityStore] startProduction: bribe threshold calc failed:", err);
      }

      // Fetch fresh facility data from server AFTER setting up reconciliation threshold
      await get().fetchFacilities(true);

      // IMMEDIATELY reconcile after fetch: if the server-returned production start timestamp 
      // is earlier than our known bribe threshold (race / eventual consistency), override it 
      // so this production counts toward suspicion. This must happen BEFORE any other operations.
      try {
        const f = get().getFacilityById(facilityId);
        if (f && !Number.isNaN(bribeThreshold)) {
          const serverStarted = f.production_started_at ? Date.parse(f.production_started_at) : NaN;
          
          if (Number.isNaN(serverStarted) || serverStarted < bribeThreshold) {
            const newIso = new Date(bribeThreshold).toISOString();
            set((state) => ({
              facilities: state.facilities.map((x) => (x.id === facilityId ? { ...x, production_started_at: newIso } : x)),
              // Store reconciled timestamp so it survives future fetch overwrites (e.g., polling)
              reconciledStartTimes: { ...state.reconciledStartTimes, [facilityId]: newIso },
            }));
            console.log("[facilityStore] startProduction: reconciled start timestamp to bribe for", facilityId, "from", serverStarted > 0 ? new Date(serverStarted).toISOString() : "INVALID", "to", newIso);
          }
        }
      } catch (err) {
        console.warn("[facilityStore] startProduction: post-fetch timestamp reconcile failed:", err);
      }

      // Godot: FacilityManager.gd lines 1023-1026
      // After production starts, global risk increases (now counting this facility)
      const globalRisk = get().getGlobalSuspicionRisk();
      await get().syncGlobalRiskToDatabase(globalRisk);

      // Godot: FacilityManager.gd line 1027
      // Refresh player data to get updated global_suspicion_level
      await usePlayerStore.getState().refreshData();

      // CRITICAL: Re-reconcile after player refresh, in case refreshData triggered
      // any store updates that may have refreshed facility data from server
      try {
        const f = get().getFacilityById(facilityId);
        if (f && !Number.isNaN(bribeThreshold)) {
          const serverStarted = f.production_started_at ? Date.parse(f.production_started_at) : NaN;
          
          if (Number.isNaN(serverStarted) || serverStarted < bribeThreshold) {
            const newIso = new Date(bribeThreshold).toISOString();
            set((state) => ({
              facilities: state.facilities.map((x) => (x.id === facilityId ? { ...x, production_started_at: newIso } : x)),
              // Update the stored reconciled timestamp as well
              reconciledStartTimes: { ...state.reconciledStartTimes, [facilityId]: newIso },
            }));
            console.log("[facilityStore] startProduction: re-reconciled start timestamp post-refresh for", facilityId, "to", newIso);
          }
        }
      } catch (err) {
        console.warn("[facilityStore] startProduction: post-refresh timestamp reconcile failed:", err);
      }
      
      return true;
    }
    set({ error: res.error || "Üretim başlatılamadı" });
    return false;
  },

  // ── Collect production (basic) ─────────────────────────────
  // DEPRECATED: Use collectResourcesV2 instead. This kept for legacy compatibility.
  collectProduction: async (facilityId: string) => {
    if (usePlayerStore.getState().inPrison) {
      set({ error: "Hapisteyken üretim toplayamazsınız!" });
      return null;
    }

    const res = await api.rpc<unknown>("collect_facility_production", {
      p_facility_id: facilityId,
    });

    console.log("[facilityStore] collect_facility_production response:", res);

    if (res.success) {
      await get().incrementSuspicion(facilityId, 5);
      await new Promise((r) => setTimeout(r, 600));
      await get().fetchFacilities(true);
      return res.data;
    }
    set({ error: res.error || "Toplama başarısız" });
    return null;
  },

  // ── Collect resources V2 (deterministic seed) ──────────────
  // Godot: FacilityManager.gd lines 1049-1184 — collect_facility_resources()
  // Flow:
  //   1. Calculate resources for UI (shown_count = total_count)
  //   2. Generate deterministic seed from production_started_at
  //   3. Call collect_facility_resources_v2 RPC with seed & total_count
  //   4. Server validates with same LCG RNG, returns items_generated
  //   5. Check if admission_occurred (prison check result)
  //   6. If admitted: resources discarded, player sent to prison
  //   7. Else: inventory updated, sync global_suspicion to database
  collectResourcesV2: async (facilityId: string, seed: number, totalCount: number) => {
    console.log("[facilityStore] collectResourcesV2 called:", { facilityId, seed, totalCount });
    
    // Prison check (should be done by caller, but safety check)
    if (usePlayerStore.getState().inPrison) {
      set({ error: "Hapisteyken toplama yapılamaz!" });
      return null;
    }

    // Snapshot inventory counts BEFORE collect so we can detect if server actually
    // added items. If server did not persist items, we will attempt to add them
    // client-side via `addItemToServer` as a fallback.
    const inventoryBefore: Record<string, number> = {};
    try {
      const invState = useInventoryStore.getState();
      for (const it of invState.items || []) {
        inventoryBefore[it.item_id] = invState.getItemQuantity(it.item_id) || 0;
      }
    } catch (e) {
      // Non-fatal; continue without snapshot
      console.warn('[facilityStore] Failed to snapshot inventory before collect:', e);
    }

    // Step 1: Call RPC with seed and count
    const res = await api.rpc<any>("collect_facility_resources_v2", {
      p_facility_id: facilityId,
      p_seed: seed,
      p_total_count: totalCount,
    });
    
    console.log("[facilityStore] collectResourcesV2 response:", res);

    if (!res.success) {
      set({ error: res.error || "Toplama başarısız" });
      return null;
    }

    const rpcResult = res.data as Record<string, any>;
    const addedCount = rpcResult?.count ?? 0;
    const admissionOccurred = rpcResult?.admission_occurred ?? false;
    const itemsGenerated = rpcResult?.items_generated ?? [];

    // Step 2: Refresh facilities (production cleared on server)
    await get().fetchFacilities(true);

    // Step 3: Sync global risk to database after collection
    const globalRisk = get().getGlobalSuspicionRisk();
    await get().syncGlobalRiskToDatabase(globalRisk);

    // Step 4: Refresh player data from server
    await usePlayerStore.getState().refreshData();

    // Step 5: Refresh inventory if collection succeeded and player not imprisoned
    try {
      if (!admissionOccurred) {
        await useInventoryStore.getState().fetchInventory();
      } else {
        // Still attempt a refresh so UI shows accurate empty changes
        await useInventoryStore.getState().fetchInventory();
      }
    } catch (err) {
      console.warn('[facilityStore] inventory refresh failed after collect:', err);
    }

    // Fallback: if server did not actually add items to inventory but RPC reported
    // items_generated, add them via `addItemToServer`. This handles cases where the
    // RPC returns generated items but the DB wasn't updated for some reason.
    try {
      if (!admissionOccurred && Array.isArray(itemsGenerated) && itemsGenerated.length > 0) {
        const invAfterState = useInventoryStore.getState();
        // Build counts before/after
        const afterCounts: Record<string, number> = {};
        for (const it of invAfterState.items || []) {
          afterCounts[it.item_id] = invAfterState.getItemQuantity(it.item_id) || 0;
        }

        // Aggregate generated items by item_id
        const generatedAgg: Record<string, number> = {};
        for (const g of itemsGenerated) {
          const id = g.item_id || g.itemId || g.id || g;
          if (!id) continue;
          generatedAgg[id] = (generatedAgg[id] || 0) + (g.quantity || 1);
        }

        // For any item where after - before < expected, call addItemToServer for the delta
        for (const [itemId, expectedQty] of Object.entries(generatedAgg)) {
          const before = inventoryBefore[itemId] || 0;
          const after = afterCounts[itemId] || 0;
          const delta = expectedQty - (after - before);
          if (delta > 0) {
            console.warn(`[facilityStore] Inventory missing ${delta}x ${itemId}, adding via RPC fallback`);
            // Call addItemToServer with aggregated quantity
            await useInventoryStore.getState().addItemToServer({ item_id: itemId, quantity: delta });
          }
        }
      }
    } catch (e) {
      console.warn('[facilityStore] Fallback inventory add failed:', e);
    }

    // Return result with admission flag
    return {
      success: true,
      count: addedCount,
      total_count: admissionOccurred ? 0 : addedCount,
      items_generated: admissionOccurred ? [] : itemsGenerated,
      message: admissionOccurred ? "Sent to prison! Resources lost." : `Resources collected: ${addedCount} items`,
      admission_occurred: admissionOccurred,
    };
  },

  // ── Bribe officials ────────────────────────────────────────
  // Godot: FacilityManager.gd lines 399-416 (bribe mechanism)
  bribeOfficials: async (facilityType: string, amountGems: number) => {
    const res = await api.rpc("bribe_officials", {
      p_facility_type: facilityType,
      p_amount_gems: amountGems,
    });
    if (res.success) {
      const nowIso = new Date().toISOString();
      set({ lastBribeAt: nowIso });
      // Also update player store immediately so UI reflects the bribe
      try {
        usePlayerStore.setState({ lastBribeAt: nowIso, globalSuspicionLevel: 0, bribeActiveUntil: Date.now() + 60_000 });
      } catch (e) {
        console.warn('[facilityStore] Failed to set playerStore.lastBribeAt locally:', e);
      }

      // Persist last_bribe_at to Supabase so server-side global suspicion uses the timestamp
      try {
        const playerProfile = usePlayerStore.getState().profile;
        const playerId = playerProfile?.id;
        if (playerId) {
          // First attempt patch by DB id
          let patchRes = await api.patch(`/rest/v1/users?id=eq.${playerId}`, {
            last_bribe_at: nowIso,
          });

          if (!patchRes.success) {
            console.warn('[facilityStore] API patch by id failed:', patchRes);
            // Try patch by auth_id (some deployments use auth_id as primary key)
            try {
              const profile = usePlayerStore.getState().profile as any;
              const authId = profile?.auth_id || profile?.authId || profile?.user_id || null;
              if (authId) {
                patchRes = await api.patch(`/rest/v1/users?auth_id=eq.${authId}`, { last_bribe_at: nowIso });
              }
            } catch (errAuthPatch) {
              console.warn('[facilityStore] Patch by auth_id attempt failed:', errAuthPatch);
            }
          }

          if (!patchRes.success) {
            // Fallback: try direct Supabase client update (may succeed if session present)
            try {
              const { supabase } = await import("@/lib/supabase");
              const { data, error } = await supabase.from('users').update({ last_bribe_at: nowIso }).eq('id', playerId).select().single();
              if (error) {
                console.warn('[facilityStore] Supabase fallback update failed:', error.message || error);
              } else {
                console.log('[facilityStore] Supabase fallback update succeeded:', data);
                patchRes = { success: true } as any;
              }
            } catch (err2) {
              console.warn('[facilityStore] Supabase fallback update threw:', err2);
            }
          } else {
            console.log('[facilityStore] last_bribe_at persisted via API patch');
          }
          // If we successfully persisted last_bribe_at, wait for the player's profile to reflect it
          if (patchRes && patchRes.success) {
            const start = Date.now();
            const timeout = 5000; // wait up to 5s for DB to become consistent
            let reflected = false;
            while (Date.now() - start < timeout) {
              try {
                await usePlayerStore.getState().fetchProfile();
                const prof = usePlayerStore.getState().profile as any;
                if (prof && (prof.last_bribe_at || prof.lastBribeAt) && String(prof.last_bribe_at || prof.lastBribeAt).startsWith(nowIso.slice(0, 19))) {
                  reflected = true;
                  break;
                }
              } catch (e) {
                // ignore and retry
              }
              await new Promise((r) => setTimeout(r, 500));
            }
            if (!reflected) {
              console.warn('[facilityStore] last_bribe_at not reflected in profile within timeout; continuing anyway');
            }
          }
        }
      } catch (err) {
        console.warn('[facilityStore] Failed to persist last_bribe_at to Supabase:', err);
      }
      // Godot timing: wait for server events to settle
      await new Promise((r) => setTimeout(r, 500));
      // Godot: FacilityManager.gd lines 404-416
      await get().fetchFacilities(true);
      // Godot: State.refresh_data() — get latest global_suspicion
      await usePlayerStore.getState().refreshData();
      // Godot: sync_global_risk_to_database()
      const globalRisk = get().getGlobalSuspicionRisk();
      await get().syncGlobalRiskToDatabase(globalRisk);
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
    // Godot: FacilityManager.gd lines 353-390 — sync_global_risk_to_database()
    // Send raw risk calculated by get_global_suspicion_risk() to server
    // Server: calculates baseline + adjusted_risk (new_level = displayed risk)
    const res = await api.rpc<any>("update_global_suspicion_level", {
      p_global_suspicion: globalSuspicion,
    });
    
    if (res.success && res.data) {
      // Godot: rpc_result.get("new_level") — adjusted risk after baseline subtraction
      const adjustedRisk = (res.data as any)?.new_level ?? globalSuspicion;
      // Godot: State.player["global_suspicion_level"] = adjusted_risk
      // Web: Update playerStore so UI reflects server-adjusted suspicion
      usePlayerStore.getState().updatePlayerData({
        global_suspicion_level: adjustedRisk,
      });
      console.log("[facilityStore] Global suspicion synced: raw=%d%%, adjusted=%d%%", globalSuspicion, adjustedRisk);
      return true;
    }
    return false;
  },

  // ── Offline production ─────────────────────────────────────
  calculateOfflineProduction: async (facilityId: string) => {
    const res = await api.rpc("calculate_offline_production", {
      p_facility_id: facilityId,
    });
    if (res.success) return res.data;
    return null;
  },

  // ── Reset all production (admin / test RPC from DB) ─────────
  resetAllProduction: async () => {
    try {
      const res = await api.rpc<{ success: boolean; facilities_reset?: number; queue_items_deleted?: number }>(
        "reset_all_facility_production"
      );

      if (res.success) {
        // Wait briefly to allow server side to commit
        await new Promise((r) => setTimeout(r, 500));
        await get().fetchFacilities(true);
        return {
          success: true,
          facilities_reset: (res as any).facilities_reset || 0,
          queue_items_deleted: (res as any).queue_items_deleted || 0,
        };
      }

      set({ error: res.error || "Reset başarısız" });
      return { success: false };
    } catch (err) {
      set({ error: err instanceof Error ? err.message : "Reset başarısız" });
      return { success: false };
    }
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

  // ── Global suspicion risk formula (raw calculation) ────────────────────
  // Godot: FacilityManager.gd lines 328-352 — get_global_suspicion_risk()
  // RAW risk (before baseline subtraction): (active_count * 5) + floor(level_sum * 0.5)
  // active = production_started_at != null (bribe does NOT affect this calculation)
  // Baseline subtraction happens server-side in update_global_suspicion_level RPC
  getGlobalSuspicionRisk: () => {
    const { facilities, lastBribeAt } = get();

    // Prefer the EARLIEST of facilityStore.lastBribeAt and playerStore.lastBribeAt.
    // This ensures productions started after the local client bribe (but before
    // the server's persisted timestamp) are still counted toward raw risk.
    const playerLastBribe = usePlayerStore.getState().lastBribeAt;
    const facilityTs = lastBribeAt ? Date.parse(String(lastBribeAt)) : NaN;
    const playerTs = playerLastBribe ? Date.parse(String(playerLastBribe)) : NaN;
    let bribeThreshold = "1970-01-01T00:00:00Z";
    if (!Number.isNaN(facilityTs) && !Number.isNaN(playerTs)) {
      bribeThreshold = facilityTs <= playerTs ? String(lastBribeAt) : String(playerLastBribe);
    } else if (!Number.isNaN(facilityTs)) {
      bribeThreshold = String(lastBribeAt);
    } else if (!Number.isNaN(playerTs)) {
      bribeThreshold = String(playerLastBribe);
    }
    const bribeTs = Date.parse(bribeThreshold) || 0;

    let activeCount = 0;
    let levelSum = 0;
    // Debug: log bribe threshold and facility start times to troubleshoot zero-risk cases
    try {
      console.log("[facilityStore] getGlobalSuspicionRisk: bribeThreshold=", bribeThreshold, "(ts=", bribeTs, ")", "facilityTs=", facilityTs, "playerTs=", playerTs);
      for (const f of facilities) {
        console.log("[facilityStore] facility", f.id, "started=", f.production_started_at, "level=", f.level);
      }
    } catch (e) {
      // ignore
    }

    // Godot: FacilityManager.gd lines 340-347
    // Count only facilities with production_started_at != null AND started AFTER last_bribe_at
    for (const f of facilities) {
      const started = f.production_started_at ? Date.parse(String(f.production_started_at)) : NaN;
      if (!Number.isNaN(started) && started >= bribeTs) {
        activeCount++;
        levelSum += f.level;
      }
    }

    // Godot: FacilityManager.gd line 350
    // risk = (active_count * 5) + int(level_sum * 0.5)
    const risk = (activeCount * 5) + Math.floor(levelSum * 0.5);
    const clamped = Math.max(0, Math.min(100, risk));
    try {
      console.log("[facilityStore] getGlobalSuspicionRisk: activeCount=", activeCount, "levelSum=", levelSum, "rawRisk=", risk, "clamped=", clamped);
    } catch (e) {
      // ignore
    }
    return clamped;
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
      reconciledStartTimes: {},
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
