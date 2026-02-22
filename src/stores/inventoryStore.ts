// ============================================================
// Inventory Store — Kaynak: InventoryManager.gd (547 satır)
// + StateStore.gd inventory array
// Server-authoritative: tüm mutasyonlar RPC üzerinden yapılır
// ============================================================

import { create } from "zustand";
import { api } from "@/lib/api";
import type { InventoryItem } from "@/types/inventory";
import { INVENTORY_CAPACITY } from "@/types/inventory";
import type { ItemType } from "@/types/item";

interface InventoryState {
  // State
  items: InventoryItem[];
  equippedItems: Record<string, InventoryItem | null>;
  isLoading: boolean;
  error: string | null;

  // Actions — server-backed
  fetchInventory: () => Promise<void>;
  addItemToServer: (itemData: Record<string, unknown>, slotPosition?: number | null) => Promise<boolean>;
  removeItem: (itemId: string, quantity?: number) => Promise<boolean>;
  removeItemByRowId: (rowId: string, quantity?: number) => Promise<boolean>;
  equipItem: (itemId: string, slot: string) => Promise<boolean>;
  unequipItem: (slot: string) => Promise<boolean>;
  swapSlots: (fromSlot: number, toSlot: number) => Promise<boolean>;
  batchUpdatePositions: (updates: Array<{ row_id: string; slot_position: number }>) => Promise<boolean>;
  updateItemEnhancement: (rowId: string, newLevel: number) => Promise<boolean>;
  useItem: (itemId: string) => Promise<boolean>;

  // Local helpers
  addItemLocal: (item: InventoryItem) => void;
  setItems: (items: InventoryItem[]) => void;
  getItemBySlot: (slot: number) => InventoryItem | undefined;
  getItemById: (itemId: string) => InventoryItem | undefined;
  getItemByRowId: (rowId: string) => InventoryItem | undefined;
  getEquippedItem: (slot: string) => InventoryItem | null;
  getItemQuantity: (itemId: string) => number;
  getItemsByType: (type: ItemType) => InventoryItem[];
  getTotalValue: () => number;
  hasMaterials: (ingredients: Array<{ item_id: string; quantity: number }>) => boolean;
  isFull: () => boolean;
  findFirstEmptySlot: () => number;
  reset: () => void;
}

export const useInventoryStore = create<InventoryState>()((set, get) => ({
  items: [],
  equippedItems: {},
  isLoading: false,
  error: null,

  // ── Fetch from server ──────────────────────────────────────
  fetchInventory: async () => {
    set({ isLoading: true, error: null });
    try {
      const res = await api.rpc<{ items: InventoryItem[] }>("get_inventory");

      if (res.success && res.data) {
        let items: InventoryItem[] = [];
        const data = res.data as Record<string, unknown>;

        if (Array.isArray(data)) {
          items = data as unknown as InventoryItem[];
        } else if (data.items && Array.isArray(data.items)) {
          items = data.items;
        } else if (data.data) {
          const inner = data.data as Record<string, unknown>;
          if (Array.isArray(inner)) {
            items = inner as unknown as InventoryItem[];
          } else if (inner.items && Array.isArray(inner.items)) {
            items = inner.items as InventoryItem[];
          }
        }

        items = ensureSlotPositions(items);

        const equipped: Record<string, InventoryItem | null> = {};
        items.forEach((item) => {
          if (item.is_equipped && item.equipped_slot) {
            equipped[item.equipped_slot] = item;
          }
        });

        set({ items, equippedItems: equipped, isLoading: false });
      } else {
        set({ isLoading: false, error: res.error || "Envanter yüklenemedi" });
      }
    } catch (err) {
      set({
        isLoading: false,
        error: err instanceof Error ? err.message : "Envanter yüklenemedi",
      });
    }
  },

  // ── Add item via server RPC (add_inventory_item_v2) ────────
  addItemToServer: async (itemData: Record<string, unknown>, slotPosition: number | null = null) => {
    const res = await api.rpc("add_inventory_item_v2", {
      item_data: itemData,
      p_slot_position: slotPosition,
    });

    if (res.success) {
      // Re-fetch to get server-assigned row_id and slot
      await get().fetchInventory();
      return true;
    }
    set({ error: res.error || "Öğe eklenemedi" });
    return false;
  },

  // ── Local-only add (for optimistic UI from other systems) ──
  addItemLocal: (item: InventoryItem) => {
    set((s) => {
      const existing = s.items.find(
        (i) => i.item_id === item.item_id && !i.is_equipped
      );
      if (existing) {
        return {
          items: s.items.map((i) =>
            i.row_id === existing.row_id
              ? { ...i, quantity: i.quantity + item.quantity }
              : i
          ),
        };
      }

      const newItem = { ...item };
      if (newItem.slot_position < 0) {
        newItem.slot_position = get().findFirstEmptySlot();
      }
      return { items: [...s.items, newItem] };
    });
  },

  // ── Remove by item_id ──────────────────────────────────────
  removeItem: async (itemId: string, quantity = 1) => {
    const res = await api.rpc("remove_inventory_item", {
      p_item_id: itemId,
      p_quantity: quantity,
    });

    if (res.success) {
      set((s) => {
        const item = s.items.find((i) => i.item_id === itemId);
        if (!item) return s;

        if (quantity >= item.quantity) {
          return { items: s.items.filter((i) => i.item_id !== itemId) };
        }
        return {
          items: s.items.map((i) =>
            i.item_id === itemId ? { ...i, quantity: i.quantity - quantity } : i
          ),
        };
      });
      return true;
    }
    return false;
  },

  // ── Remove by row_id (specific inventory row) ─────────────
  removeItemByRowId: async (rowId: string, quantity = 1) => {
    const res = await api.rpc("remove_inventory_item_by_row", {
      p_row_id: rowId,
      p_quantity: quantity,
    });

    if (res.success) {
      set((s) => {
        const item = s.items.find((i) => i.row_id === rowId);
        if (!item) return s;

        if (quantity >= item.quantity) {
          return { items: s.items.filter((i) => i.row_id !== rowId) };
        }
        return {
          items: s.items.map((i) =>
            i.row_id === rowId ? { ...i, quantity: i.quantity - quantity } : i
          ),
        };
      });
      return true;
    }
    return false;
  },

  // ── Equip item ─────────────────────────────────────────────
  equipItem: async (itemId: string, slot: string) => {
    const res = await api.rpc("equip_item", {
      p_item_id: itemId,
      p_slot: slot,
    });

    if (res.success) {
      set((s) => {
        const updatedItems = s.items.map((i) => {
          if (i.item_id === itemId) {
            return { ...i, is_equipped: true, equipped_slot: slot };
          }
          if (i.equipped_slot === slot && i.is_equipped) {
            return { ...i, is_equipped: false, equipped_slot: "" };
          }
          return i;
        });

        const equipped = { ...s.equippedItems };
        equipped[slot] = updatedItems.find((i) => i.item_id === itemId) || null;

        return { items: updatedItems, equippedItems: equipped };
      });
      return true;
    }
    return false;
  },

  // ── Unequip item ───────────────────────────────────────────
  unequipItem: async (slot: string) => {
    const res = await api.rpc("unequip_item", { p_slot: slot });

    if (res.success) {
      set((s) => {
        const updatedItems = s.items.map((i) => {
          if (i.equipped_slot === slot && i.is_equipped) {
            return { ...i, is_equipped: false, equipped_slot: "" };
          }
          return i;
        });
        const equipped = { ...s.equippedItems };
        equipped[slot] = null;
        return { items: updatedItems, equippedItems: equipped };
      });
      return true;
    }
    return false;
  },

  // ── Swap slots ─────────────────────────────────────────────
  swapSlots: async (fromSlot: number, toSlot: number) => {
    const res = await api.rpc("swap_slots", {
      p_from_slot: fromSlot,
      p_to_slot: toSlot,
    });

    if (res.success) {
      set((s) => ({
        items: s.items.map((item) => {
          if (item.slot_position === fromSlot) return { ...item, slot_position: toSlot };
          if (item.slot_position === toSlot) return { ...item, slot_position: fromSlot };
          return item;
        }),
      }));
      return true;
    }
    return false;
  },

  // ── Batch update positions ─────────────────────────────────
  batchUpdatePositions: async (updates: Array<{ row_id: string; slot_position: number }>) => {
    const res = await api.rpc("update_item_positions", {
      p_updates: updates,
    });
    if (res.success) {
      set((s) => {
        const updateMap = new Map(updates.map((u) => [u.row_id, u.slot_position]));
        return {
          items: s.items.map((item) => {
            const newPos = updateMap.get(item.row_id);
            return newPos !== undefined ? { ...item, slot_position: newPos } : item;
          }),
        };
      });
      return true;
    }
    return false;
  },

  // ── Update enhancement level via server RPC ────────────────
  updateItemEnhancement: async (rowId: string, newLevel: number) => {
    const res = await api.rpc("upgrade_item_enhancement", {
      p_row_id: rowId,
      p_new_level: newLevel,
    });

    if (res.success) {
      set((s) => ({
        items: s.items.map((i) =>
          i.row_id === rowId ? { ...i, enhancement_level: newLevel } : i
        ),
      }));
      return true;
    }
    return false;
  },

  // ── Use item (potion / consumable dispatch) ────────────────
  useItem: async (itemId: string) => {
    const item = get().items.find((i) => i.item_id === itemId);
    if (!item) return false;

    if (item.item_type === "potion") {
      const res = await api.post("/api/v1/potion/use", { item_id: itemId });
      if (res.success) {
        await get().fetchInventory();
        return true;
      }
      return false;
    }

    // Generic consumable
    const res = await api.post("/api/v1/inventory/use", { item_id: itemId });
    if (res.success) {
      await get().fetchInventory();
      return true;
    }
    return false;
  },

  // ── Getters & Helpers ──────────────────────────────────────
  setItems: (items: InventoryItem[]) => set({ items: ensureSlotPositions(items) }),

  getItemBySlot: (slot: number) =>
    get().items.find((i) => i.slot_position === slot),

  getItemById: (itemId: string) =>
    get().items.find((i) => i.item_id === itemId),

  getItemByRowId: (rowId: string) =>
    get().items.find((i) => i.row_id === rowId),

  getEquippedItem: (slot: string) =>
    get().equippedItems[slot] ?? null,

  getItemQuantity: (itemId: string) => {
    return get().items
      .filter((i) => i.item_id === itemId)
      .reduce((sum, i) => sum + (i.quantity ?? 1), 0);
  },

  getItemsByType: (type: ItemType) =>
    get().items.filter((i) => i.item_type === type),

  getTotalValue: () =>
    get().items.reduce(
      (sum, i) => sum + (i.vendor_sell_price ?? i.base_price ?? 0) * (i.quantity ?? 1),
      0
    ),

  hasMaterials: (ingredients: Array<{ item_id: string; quantity: number }>) => {
    const { getItemQuantity } = get();
    return ingredients.every((ing) => getItemQuantity(ing.item_id) >= ing.quantity);
  },

  isFull: () => get().items.filter((i) => !i.is_equipped).length >= INVENTORY_CAPACITY,

  findFirstEmptySlot: () => {
    const occupied = new Set(get().items.map((i) => i.slot_position));
    for (let i = 0; i < INVENTORY_CAPACITY; i++) {
      if (!occupied.has(i)) return i;
    }
    return -1;
  },

  reset: () => set({ items: [], equippedItems: {}, isLoading: false, error: null }),
}));

// Helper: ensure all items have valid slot positions
function ensureSlotPositions(items: InventoryItem[]): InventoryItem[] {
  const occupied = new Set<number>();
  const result: InventoryItem[] = [];

  for (const item of items) {
    if (
      item.slot_position >= 0 &&
      item.slot_position < INVENTORY_CAPACITY &&
      !occupied.has(item.slot_position)
    ) {
      occupied.add(item.slot_position);
      result.push(item);
    } else {
      result.push({ ...item, slot_position: -1 });
    }
  }

  let nextSlot = 0;
  return result.map((item) => {
    if (item.slot_position >= 0) return item;
    while (occupied.has(nextSlot)) nextSlot++;
    occupied.add(nextSlot);
    return { ...item, slot_position: nextSlot };
  });
}
