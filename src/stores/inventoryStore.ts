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
  unequipItemToSlot: (rowId: string, slotName: string, targetSlot: number) => Promise<boolean>;
  swapSlots: (fromSlot: number, toSlot: number) => Promise<boolean>;
  moveItemToSlot: (rowId: string, targetSlot: number) => Promise<boolean>;
  batchUpdatePositions: (updates: Array<{ row_id: string; slot_position: number }>) => Promise<boolean>;
  updateItemEnhancement: (rowId: string, newLevel: number) => Promise<boolean>;
  useItem: (itemId: string) => Promise<boolean>;
  splitStack: (rowId: string, splitQuantity: number) => Promise<boolean>;
  trashItem: (rowId: string) => Promise<boolean>;
  toggleFavorite: (rowId: string) => Promise<boolean>;

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
      // Envanter ve kuşanılan itemleri ayrı çek
      const [invRes, equippedRes] = await Promise.all([
        api.rpc<{ items: InventoryItem[] }>("get_inventory"),
        api.rpc<{ items: InventoryItem[] }>("get_equipped_items"),
      ]);
      console.log("[InventoryStore] fetchInventory RPC response:", invRes);
      console.log("[InventoryStore] fetchEquipped RPC response:", equippedRes);

      if (invRes.success && invRes.data) {
        let items: InventoryItem[] = [];
        const data = invRes.data as Record<string, unknown>;

        console.log("[InventoryStore] response data:", data, "data.items:", data.items);

        if (Array.isArray(data)) {
          items = data as unknown as InventoryItem[];
          console.log("[InventoryStore] data is array, items count:", items.length);
        } else if (data.items && Array.isArray(data.items)) {
          items = data.items as InventoryItem[];
          console.log("[InventoryStore] data.items is array, items count:", items.length);
        } else if (data.data) {
          const inner = data.data as Record<string, unknown>;
          if (Array.isArray(inner)) {
            items = inner as unknown as InventoryItem[];
            console.log("[InventoryStore] data.data is array, items count:", items.length);
          } else if (inner.items && Array.isArray(inner.items)) {
            items = inner.items as InventoryItem[];
            console.log("[InventoryStore] data.data.items is array, items count:", items.length);
          }
        }

        console.log("[InventoryStore] before ensureSlotPositions:", items.length, items);
        items = ensureSlotPositions(items);
        console.log("[InventoryStore] after ensureSlotPositions:", items.length);

        // Defensive: filter out any rows that the server marks as equipped
        items = items.filter((it) => !it.is_equipped);
        console.log("[InventoryStore] after filter is_equipped=false, count:", items.length);

        // Kuşanılan itemleri işle (ayrı RPC'den)
        const equipped: Record<string, InventoryItem | null> = {};
        if (equippedRes.success && equippedRes.data) {
          const equippedData = equippedRes.data as Record<string, unknown>;
          let equippedItemsArr: InventoryItem[] = [];

          if (equippedData.items && Array.isArray(equippedData.items)) {
            equippedItemsArr = equippedData.items as InventoryItem[];
          }

          // Remove any duplicates from inventory list by row_id
          const equippedRowIds = new Set(equippedItemsArr.map((e) => e.row_id));
          if (equippedRowIds.size > 0) {
            items = items.filter((it) => !equippedRowIds.has(it.row_id));
          }

          equippedItemsArr.forEach((item) => {
            // Support both RPC shapes: `equip_slot` (get_equipped_items) and `equipped_slot` (get_inventory)
            const rawSlot = (item as any).equip_slot ?? (item as any).equipped_slot ?? null;
            if (rawSlot) {
              const key = String(rawSlot).toLowerCase();
              equipped[key] = item as InventoryItem;
            }
          });
          console.log("[InventoryStore] equipped items count:", equippedItemsArr.length, "mapped slots:", Object.keys(equipped));
        }

        set({ items, equippedItems: equipped, isLoading: false });
        console.log("[InventoryStore] state updated, items:", items.length, "equipped:", Object.keys(equipped).length);
      } else {
        console.warn("[InventoryStore] fetchInventory failed:", invRes.error, "success:", invRes.success);
        set({ isLoading: false, error: invRes.error || "Envanter yüklenemedi" });
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
  equipItem: async (rowId: string, slot: string) => {
    console.log("[InventoryStore] equipItem:", { rowId, slot });

    // Optimistic update: remove item from items list and add to equippedItems map
    let optimisticItem: InventoryItem | null = null;
    set((s) => {
      const items = s.items.filter((i) => {
        if (i.row_id === rowId) {
          optimisticItem = i;
          return false; // remove from visible inventory
        }
        return true;
      });
      const equipped = { ...s.equippedItems };
      if (optimisticItem) {
        equipped[String(slot).toLowerCase()] = { ...optimisticItem, is_equipped: true, equip_slot: slot } as InventoryItem;
      }
      return { items, equippedItems: equipped };
    });

    // Send to server
    const res = await api.rpc("equip_item", {
      p_row_id: rowId,
      p_slot: slot,
    });

    if (!res.success) {
      console.warn("[InventoryStore] equipItem failed:", res.error);
      set({ error: res.error || "Kuşanma başarısız" });
      // Revert by re-fetching authoritative state
      await get().fetchInventory();
      return false;
    }

    // On success reconcile with server
    console.log("[InventoryStore] equipItem success, refreshing inventory");
    await get().fetchInventory();
    return true;
  },

  // ── Unequip item and place into specific inventory slot (optimistic) ───
  unequipItemToSlot: async (rowId: string, slotName: string, targetSlot: number) => {
    console.log("[InventoryStore] unequipItemToSlot (optimistic):", { rowId, slotName, targetSlot });

    // Defensive targetSlot
    if (targetSlot < 0 || targetSlot >= INVENTORY_CAPACITY) {
      set({ error: `Geçersiz hedef slot: ${targetSlot}` });
      return false;
    }

    const key = String(slotName).toLowerCase();
    const state = get();
    const equipped = state.equippedItems[key];

    // Optimistic update: remove equipped and add to items with provided slot
    if (equipped && equipped.row_id === rowId) {
      set((s) => {
        const newEquipped = { ...s.equippedItems };
        delete newEquipped[key];
        const restored = { ...equipped, is_equipped: false, equip_slot: null, slot_position: targetSlot } as any;
        return { equippedItems: newEquipped, items: [...s.items, restored] };
      });
    } else {
      // If not present in equipped map, still ensure item exists in items list
      set((s) => {
        const exists = s.items.find((i) => i.row_id === rowId);
        if (!exists) {
          const restored = { row_id: rowId, item_id: '', quantity: 1, slot_position: targetSlot, is_equipped: false } as any;
          return { items: [...s.items, restored] };
        }
        return s;
      });
    }

    // Server calls: unequip first to clear equip state, then update positions.
    try {
      const unequipRes = await api.rpc("unequip_item", { p_slot: slotName });
      if (!unequipRes.success) {
        console.warn("[InventoryStore] unequip_item failed:", unequipRes.error);
        await get().fetchInventory();
        set({ error: unequipRes.error || "Kuşanma çıkarma başarısız" });
        return false;
      }

      const posRes = await api.rpc("update_item_positions", { p_updates: [{ row_id: rowId, slot_position: targetSlot }] });
      if (!posRes.success) {
        console.warn("[InventoryStore] update_item_positions failed:", posRes.error);
        await get().fetchInventory();
        set({ error: posRes.error || "Slot güncelleme başarısız" });
        return false;
      }

      await get().fetchInventory();
      return true;
    } catch (err) {
      console.warn("[InventoryStore] unequipItemToSlot errored:", err);
      await get().fetchInventory();
      set({ error: err instanceof Error ? err.message : String(err) });
      return false;
    }
  },

  // ── Unequip item ───────────────────────────────────────────
  unequipItem: async (slot: string) => {
    console.log("[InventoryStore] unequipItem (optimistic):", { slot });

    // Optimistic: find equipped item in current state and move it back into items
    const key = String(slot).toLowerCase();
    const state = get();
    const equipped = state.equippedItems[key];

    // If we have an equipped item locally, perform optimistic state update
    if (equipped) {
      // Remove from equipped map and add to items with tentative slot_position
      const tentativeSlot = state.findFirstEmptySlot();
      set((s) => {
        const newEquipped = { ...s.equippedItems };
        delete newEquipped[key];

        const restored: typeof equipped = {
          ...equipped,
          is_equipped: false,
          equip_slot: null,
          slot_position: tentativeSlot,
        } as any;

        return {
          equippedItems: newEquipped,
          items: [...s.items, restored],
        };
      });
    }

    // Call server RPC
    try {
      const res = await api.rpc("unequip_item", { p_slot: slot });

      if (!res.success) {
        console.warn("[InventoryStore] unequipItem RPC failed:", res.error);
        set({ error: res.error || "Kuşanma çıkarma başarısız" });
        // Re-fetch authoritative state to revert optimistic change
        await get().fetchInventory();
        return false;
      }

      // On success reconcile
      console.log("[InventoryStore] unequipItem success, refreshing inventory");
      await get().fetchInventory();
      return true;
    } catch (err) {
      console.warn("[InventoryStore] unequipItem errored:", err);
      set({ error: err instanceof Error ? err.message : String(err) });
      await get().fetchInventory();
      return false;
    }
  },

  // ── Swap slots ─────────────────────────────────────────────
  swapSlots: async (fromSlot: number, toSlot: number) => {
    // Prefer calling the dedicated RPC if available, but fall back to
    // `update_item_positions` when the RPC is not present (404) so the
    // client remains usable without server-side function parity during dev.
    try {
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

      // If RPC returned but was not successful, fallthrough to fallback below
      console.warn("swap_slots RPC failed, attempting fallback update_item_positions:", res.error);
    } catch (err) {
      console.warn("swap_slots RPC call errored — falling back to update_item_positions", err);
    }

    // Fallback: perform a batch positional update using row_ids for the two slots
    const state = get();
    const a = state.items.find((it) => it.slot_position === fromSlot);
    const b = state.items.find((it) => it.slot_position === toSlot);

    // If neither item exists at the slots, nothing to do
    if (!a && !b) return false;

    const updates: Array<{ row_id: string; slot_position: number }> = [];
    if (a) updates.push({ row_id: a.row_id, slot_position: toSlot });
    if (b) updates.push({ row_id: b.row_id, slot_position: fromSlot });

    const res2 = await api.rpc("update_item_positions", { p_updates: updates });
    if (res2.success) {
      set((s) => ({
        items: s.items.map((item) => {
          if (item.slot_position === fromSlot) return { ...item, slot_position: toSlot };
          if (item.slot_position === toSlot) return { ...item, slot_position: fromSlot };
          return item;
        }),
      }));
      return true;
    }

    set({ error: res2.error || "Swap failed" });
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

  // ── Move item to specific slot (drag-drop) ─────────────────
  moveItemToSlot: async (rowId: string, targetSlot: number) => {
    if (targetSlot < 0 || targetSlot >= INVENTORY_CAPACITY) {
      set({ error: `Geçersiz slot pozisyonu: ${targetSlot}` });
      return false;
    }

    const res = await api.rpc("update_item_positions", {
      p_updates: [{ row_id: rowId, slot_position: targetSlot }],
    });

    if (res.success) {
      set((s) => ({
        items: s.items.map((i) =>
          i.row_id === rowId ? { ...i, slot_position: targetSlot } : i
        ),
      }));
      return true;
    }
    set({ error: res.error || "Eşya taşıma başarısız" });
    return false;
  },

  // ── Split stack item ───────────────────────────────────────
  splitStack: async (rowId: string, splitQuantity: number) => {
    const item = get().getItemByRowId(rowId);
    if (!item) {
      set({ error: "Eşya bulunamadı" });
      return false;
    }

    if (!item.is_stackable || item.quantity <= 1) {
      set({ error: "Bu eşya bölünemez" });
      return false;
    }

    if (splitQuantity <= 0 || splitQuantity >= item.quantity) {
      set({ error: `Geçersiz bölme miktarı (1-${item.quantity - 1})` });
      return false;
    }

    // Find first empty slot for new stack
    const targetSlot = get().findFirstEmptySlot();
    if (targetSlot === -1) {
      set({ error: "Envanter dolu, bölme yapılamadı" });
      return false;
    }

    // Call RPC to split stack
    const res = await api.rpc("split_stack_item", {
      p_row_id: rowId,
      p_split_quantity: splitQuantity,
      p_target_slot: targetSlot,
    });

    if (res.success) {
      await get().fetchInventory();
      return true;
    }
    set({ error: res.error || "Stack bölme başarısız" });
    return false;
  },

  // ── Trash/Delete item ──────────────────────────────────────
  trashItem: async (rowId: string) => {
    const res = await api.rpc("trash_item", { p_row_id: rowId });

    if (res.success) {
      set((s) => ({
        items: s.items.filter((i) => i.row_id !== rowId),
      }));
      return true;
    }
    set({ error: res.error || "Eşya silinme başarısız" });
    return false;
  },

  // ── Toggle favorite ────────────────────────────────────────
  toggleFavorite: async (rowId: string) => {
    const item = get().getItemByRowId(rowId);
    if (!item) {
      set({ error: "Eşya bulunamadı" });
      return false;
    }

    const newFavoriteState = !item.is_favorite;
    
    const res = await api.rpc("toggle_item_favorite", {
      p_row_id: rowId,
      p_is_favorite: newFavoriteState,
    });

    if (res.success) {
      set((s) => ({
        items: s.items.map((i) =>
          i.row_id === rowId
            ? { ...i, is_favorite: newFavoriteState }
            : i
        ),
      }));
      return true;
    }
    set({ error: res.error || "Favori durumu değiştirilemiyor" });
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
