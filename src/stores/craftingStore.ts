// ============================================================
// Crafting Store — Kaynak: CraftingManager.gd (217 satır)
// Tarif yükleme, üretim başlatma, kuyruk yönetimi, claim
// Server-authoritative: tüm işlemler RPC üzerinden yapılır
// ============================================================

import { create } from "zustand";
import { api } from "@/lib/api";
import type { CraftRecipe, CraftQueueItem } from "@/types/crafting";
import { usePlayerStore } from "./playerStore";
import { useInventoryStore } from "./inventoryStore";

interface CraftingState {
  // State
  recipes: CraftRecipe[];
  queue: CraftQueueItem[];
  isLoading: boolean;
  isCrafting: boolean;
  error: string | null;

  // Actions
  loadRecipes: () => Promise<void>;
  craftItem: (recipeId: string, batchCount: number) => Promise<boolean>;
  loadQueue: () => Promise<void>;
  claimItem: (queueItemId: string) => Promise<boolean>;
  hasMaterials: (recipe: CraftRecipe, batchCount?: number) => boolean;
  isQueueFull: () => boolean;
  reset: () => void;
}

const BATCH_LIMIT = 5;
const QUEUE_LIMIT = 10;

export const useCraftingStore = create<CraftingState>()((set, get) => ({
  recipes: [],
  queue: [],
  isLoading: false,
  isCrafting: false,
  error: null,

  loadRecipes: async () => {
    set({ isLoading: true, error: null });

    const playerLevel = usePlayerStore.getState().level;

    try {
      const res = await api.rpc<{ data: CraftRecipe[] }>("get_craft_recipes", {
        p_user_level: playerLevel,
      });

      if (res.success && res.data) {
        let recipes: CraftRecipe[] = [];
        const data = res.data as Record<string, unknown>;

        if (Array.isArray(data)) {
          recipes = data as unknown as CraftRecipe[];
        } else if (data.data && Array.isArray(data.data)) {
          recipes = data.data as CraftRecipe[];
        }

        set({ recipes, isLoading: false });
      } else {
        set({ isLoading: false, error: res.error || "Tarifler yüklenemedi" });
      }
    } catch (err) {
      set({
        isLoading: false,
        error: err instanceof Error ? err.message : "Tarifler yüklenemedi",
      });
    }
  },

  craftItem: async (recipeId: string, batchCount: number) => {
    // Batch limit check
    if (batchCount < 1 || batchCount > BATCH_LIMIT) {
      set({ error: `Batch 1-${BATCH_LIMIT} arası olmalı` });
      return false;
    }

    // Queue limit check
    if (get().isQueueFull()) {
      set({ error: `Üretim kuyruğu dolu (max ${QUEUE_LIMIT})` });
      return false;
    }

    // Gem cost: first craft free, each additional costs 1 gem
    const gemCost = Math.max(0, batchCount - 1);
    const { gems } = usePlayerStore.getState();

    if (gems < gemCost) {
      set({ error: "Yetersiz elmas" });
      return false;
    }

    // Materials check
    const recipe = get().recipes.find((r) => r.id === recipeId || r.recipe_id === recipeId);
    if (recipe && !get().hasMaterials(recipe, batchCount)) {
      set({ error: "Yetersiz malzeme" });
      return false;
    }

    set({ isCrafting: true, error: null });

    try {
      const userId = usePlayerStore.getState().profile?.id;
      const res = await api.rpc("craft_item_async", {
        p_user_id: userId,
        p_recipe_id: recipeId,
        p_batch_count: batchCount,
      });

      if (res.success) {
        // Update gems locally
        usePlayerStore.getState().updateGems(-gemCost, true);

        // Refresh queue & inventory
        await get().loadQueue();
        useInventoryStore.getState().fetchInventory();
        set({ isCrafting: false });
        return true;
      }

      set({ isCrafting: false, error: res.error || "Üretim başarısız" });
      return false;
    } catch (err) {
      set({
        isCrafting: false,
        error: err instanceof Error ? err.message : "Üretim başarısız",
      });
      return false;
    }
  },

  loadQueue: async () => {
    try {
      const res = await api.rpc<CraftQueueItem[]>("get_craft_queue");
      if (res.success && res.data) {
        const queue = Array.isArray(res.data) ? res.data : [];
        set({ queue });
      }
    } catch {
      // Silent fail — queue loading is non-critical
    }
  },

  // FIXED: RPC name is "claim_crafted_item" (NOT "claim_craft_item")
  // FIXED: Requires p_user_id parameter
  claimItem: async (queueItemId: string) => {
    try {
      const userId = usePlayerStore.getState().profile?.id;
      const res = await api.rpc("claim_crafted_item", {
        p_user_id: userId,
        p_queue_item_id: queueItemId,
      });

      if (res.success) {
        // Remove claimed item from queue
        set((s) => ({
          queue: s.queue.filter((q) => q.id !== queueItemId),
        }));
        // Refresh inventory to show new item
        useInventoryStore.getState().fetchInventory();
        return true;
      }
      set({ error: res.error || "Talep edilemedi" });
      return false;
    } catch {
      return false;
    }
  },

  // Check if player has required materials for a recipe
  hasMaterials: (recipe: CraftRecipe, batchCount = 1) => {
    const ingredients = recipe.ingredients ?? (recipe as any).materials ?? [];
    const { getItemQuantity } = useInventoryStore.getState();

    return ingredients.every((ing: { item_id: string; quantity: number }) => {
      const required = (ing.quantity ?? 1) * batchCount;
      const owned = getItemQuantity(ing.item_id);
      return owned >= required;
    });
  },

  isQueueFull: () => get().queue.length >= QUEUE_LIMIT,

  reset: () => set({ recipes: [], queue: [], isLoading: false, isCrafting: false, error: null }),
}));
