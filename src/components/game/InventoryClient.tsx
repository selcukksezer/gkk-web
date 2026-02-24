// ============================================================
// InventoryClient — Main inventory UI (Oyun Stili)
// Layout: Ekipman (Sol) | Karakter (Sağ) | Envanter Grid (Alt)
// Smooth drag-drop with visual feedback
// ============================================================

"use client";

import { useState, useEffect, useRef, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { DndContext, DragEndEvent, DragStartEvent, DragCancelEvent, pointerWithin } from "@dnd-kit/core";
import { PointerSensor, useSensor, useSensors, KeyboardSensor } from "@dnd-kit/core";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import type { InventoryItem } from "@/types/inventory";
import { INVENTORY_CAPACITY } from "@/types/inventory";
import type { Rarity } from "@/types/item";
import { InventoryGrid } from "./InventoryGrid";
import { InventoryDetailPanel } from "./InventoryDetailPanel";
import { EquipmentGrid } from "./EquipmentGrid";
import { InventoryDragOverlay } from "./InventoryDragOverlay";
import { SellDialog, SplitStackDialog, DeleteConfirmDialog } from "./InventoryDialogs";
import { InventoryFilterBar, type FilterType } from "./InventoryFilterBar";
import { InventorySortControls, type SortType } from "./InventorySortControls";

const RARITY_ORDER: Rarity[] = ["common", "uncommon", "rare", "epic", "legendary", "mythic"];

export function InventoryClient() {
  const {
    items,
    equippedItems,
    isLoading,
    error,
    fetchInventory,
    equipItem,
    unequipItem,
    moveItemToSlot,
    swapSlots,
    trashItem,
    removeItemByRowId,
    splitStack,
    toggleFavorite,
    useItem,
  } = useInventoryStore();

  const level = usePlayerStore((s) => s.level);
  const addToast = useUiStore((s) => s.addToast);

  // UI State
  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);

  // Filter & Sort State — Godot: InventoryScreen._on_filter_button_pressed / _on_sort_button_pressed
  const [activeFilter, setActiveFilter] = useState<FilterType>("all");
  const [sortBy, setSortBy] = useState<SortType>("name");
  const [sortAscending, setSortAscending] = useState(true);

  // Dialog State
  const [activeSellDialog, setActiveSellDialog] = useState(false);
  const [activeSplitDialog, setActiveSplitDialog] = useState(false);
  const [activeDeleteDialog, setActiveDeleteDialog] = useState(false);

  // Drag-Drop State
  const [activeId, setActiveId] = useState<string | null>(null);
  const [activeItem, setActiveItem] = useState<InventoryItem | null>(null);
  const dragTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor)
  );

  // Fetch on mount
  useEffect(() => {
    fetchInventory();
  }, [fetchInventory]);

  // =========== COMPUTED VALUES ===========

  // Total stats from equipped items — Godot: EquipmentScreen stats_recalculated signal
  const totalStats = useMemo(() => {
    const stats = { attack: 0, defense: 0, health: 0, power: 0 };
    Object.values(equippedItems).forEach((item) => {
      if (item) {
        const bonus = 1 + (item.enhancement_level ?? 0) * 0.1;
        stats.attack += Math.floor((item.attack ?? 0) * bonus);
        stats.defense += Math.floor((item.defense ?? 0) * bonus);
        stats.health += Math.floor((item.health ?? 0) * bonus);
        stats.power += Math.floor((item.power ?? 0) * bonus);
      }
    });
    return stats;
  }, [equippedItems]);

  // Filtered items — Godot: InventoryScreen._on_filter_button_pressed
  const filteredItems = useMemo(() => {
    const nonEquipped = items.filter((i) => !i.is_equipped);
    if (activeFilter === "all") return nonEquipped;
    return nonEquipped.filter((i) => {
      if (activeFilter === "weapon") return i.item_type === "weapon";
      if (activeFilter === "armor") return i.item_type === "armor";
      if (activeFilter === "potion") return i.item_type === "potion" || i.item_type === "consumable";
      if (activeFilter === "material") return i.item_type === "material";
      return true;
    });
  }, [items, activeFilter]);

  // Sorted display items — Godot: InventoryScreen._on_sort_button_pressed
  const displayItems = useMemo(() => {
    const isSorted = sortBy !== "name" || !sortAscending;
    const isFiltered = activeFilter !== "all";
    if (!isSorted && !isFiltered) return items; // default: use original slot positions

    const sorted = [...filteredItems].sort((a, b) => {
      let cmp = 0;
      switch (sortBy) {
        case "name": cmp = a.name.localeCompare(b.name); break;
        case "rarity": cmp = RARITY_ORDER.indexOf(a.rarity) - RARITY_ORDER.indexOf(b.rarity); break;
        case "level": cmp = (a.required_level ?? 0) - (b.required_level ?? 0); break;
        case "type": cmp = a.item_type.localeCompare(b.item_type); break;
      }
      return sortAscending ? cmp : -cmp;
    });
    // Remap display positions for sorted/filtered view (visual only)
    return sorted.map((item, idx) => ({ ...item, slot_position: idx }));
  }, [items, filteredItems, sortBy, sortAscending, activeFilter]);

  // =========== HANDLERS ===========

  const handleItemClick = (item: InventoryItem) => {
    setSelectedItem(item);
  };

  // Use consumable/potion — Godot: InventoryScreen._on_use_button_pressed
  const handleUseItem = async () => {
    if (!selectedItem) return;
    const success = await useItem(selectedItem.item_id);
    if (success) {
      addToast(`${selectedItem.name} kullanıldı!`, "success");
      setSelectedItem(null);
      await fetchInventory();
    } else {
      addToast("Eşya kullanılamadı", "error");
    }
  };

  const handleSellItem = async (quantity: number) => {
    if (!selectedItem) return;
    await moveItemToSlot(selectedItem.row_id, -1);
    setActiveSellDialog(false);
    setSelectedItem(null);
    await fetchInventory();
  };

  const handleSplitStack = async (splitQuantity: number) => {
    if (!selectedItem) return;
    await splitStack(selectedItem.row_id, splitQuantity);
    setActiveSplitDialog(false);
    setSelectedItem(null);
    await fetchInventory();
  };

  const handleTrashItem = async (quantity: number) => {
    if (!selectedItem) return;
    try {
      // Use removeItemByRowId which supports quantity deletion server-side
      const success = await removeItemByRowId(selectedItem.row_id, quantity);
      if (!success) {
        console.error("Failed to delete item");
      }
    } catch (err) {
      console.error("Error deleting item:", err);
    } finally {
      setActiveDeleteDialog(false);
      setSelectedItem(null);
      await fetchInventory();
    }
  };

  const handleToggleFavorite = async () => {
    if (!selectedItem) return;
    await toggleFavorite(selectedItem.row_id);
    setSelectedItem((prev) =>
      prev ? { ...prev, is_favorite: !prev.is_favorite } : null
    );
  };

  // =========== DND-KIT HANDLERS ===========

  const handleDragStart = (event: DragStartEvent) => {
    const id = String(event.active.id);
    setActiveId(id);
    if (id.startsWith("empty-")) {
      setActiveItem(null);
    } else {
      const it = items.find((x) => x.row_id === id) || null;
      console.log(`[dnd] start id=${id}`);
      console.log(`[dnd] activeItem row_id=${it?.row_id || "null"} name=${it?.name || "null"} slot=${it?.slot_position ?? "null"}`);
      setActiveItem(it);
    }
  };

  const handleDragCancel = (_event: DragCancelEvent) => {
    setActiveId(null);
    setActiveItem(null);
  };

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event;
    setActiveId(null);
    if (!active) {
      console.log("[dnd] end - no active");
      return setActiveItem(null);
    }

    const activeIdStr = String(active.id);
    const overIdStr = over ? String(over.id) : null;
    console.log(`[dnd] end active=${activeIdStr} over=${overIdStr}`);

    try {
      // Nothing changed
      if (!overIdStr || overIdStr === activeIdStr) {
        setActiveItem(null);
        return;
      }

      // Active item must exist to perform inventory operations
      const dragged = items.find((it) => it.row_id === activeIdStr);
      if (!dragged) {
        setActiveItem(null);
        return;
      }

      // Drop on trash
      if (overIdStr === "trash") {
        setSelectedItem(dragged);
        setActiveDeleteDialog(true);
        setActiveItem(null);
        return;
      }

      // Drop on equipment slot: equip
      if (overIdStr.startsWith("equip-")) {
        const slotName = overIdStr.replace(/^equip-/, "");

        // Validate that the item can be equipped in this slot
        if (dragged.equip_slot !== slotName) {
          setActiveItem(null);
          setSelectedItem(dragged);
          console.warn(`Cannot equip ${dragged.name} to slot ${slotName}`);
          return;
        }

        await equipItem(dragged.row_id, slotName);
        setActiveItem(null);
        return;
      }

      // Drop on inventory slot (empty or occupied)
      if (overIdStr.startsWith("empty-")) {
        const idx = parseInt(overIdStr.replace(/^empty-/, ""), 10);
        if (!Number.isNaN(idx)) {
          // If dragging an equipped item back into an inventory slot, first unequip it
          if (dragged.is_equipped && dragged.equipped_slot) {
            await unequipItem(dragged.equipped_slot);
            await new Promise((r) => setTimeout(r, 80));
          }

          await moveItemToSlot(dragged.row_id, idx);
          await new Promise((r) => setTimeout(r, 120));
          await fetchInventory();
        }
      } else {
        console.log(`[dnd] over is not empty - checking swap/equip over=${overIdStr}`);
        // over is another item id -> swap
        const target = items.find((it) => it.row_id === overIdStr);
        if (target) {
          await swapSlots(dragged.slot_position, target.slot_position);
          await new Promise((r) => setTimeout(r, 120));
          await fetchInventory();
        }
      }
    } catch (err) {
      console.error("dnd end error:", err);
    } finally {
      setActiveItem(null);
    }
  };

  return (
    <motion.div 
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="min-h-screen w-full bg-gradient-to-br from-[var(--bg-darker)] via-[var(--bg-card)] to-[var(--bg-darker)] space-y-4 p-4 md:p-6 pb-20 overflow-x-hidden"
    >
        {/* Header removed as requested */}

      {/* Error Banner */}
      <AnimatePresence>
        {error && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="p-3 bg-red-600/20 border border-red-500/50 rounded-lg text-red-300 text-sm backdrop-blur-sm"
          >
            ⚠️ {error}
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Layout: Equipment (Left) + Character (Right) - Flex for better control */}
      <DndContext
        sensors={sensors}
        collisionDetection={pointerWithin}
        onDragStart={handleDragStart}
        onDragEnd={handleDragEnd}
        onDragCancel={handleDragCancel}
      >
      <div className="flex flex-col lg:flex-row gap-4 w-full items-stretch">
        {/* Left Column: Equipment Grid + Total Stats */}
        <motion.div
          initial={{ x: -30, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ delay: 0.1 }}
          className="w-full lg:w-80 flex-shrink-0 bg-gradient-to-br from-[var(--bg-card)] to-[var(--bg-darker)] p-4 rounded-xl border border-[var(--border-subtle)] shadow-lg space-y-4"
        >
          <p className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider">
            🛡️ Kuşanılan Eşyalar
          </p>
          <EquipmentGrid equippedItems={equippedItems} />

          {/* Total Stats Panel — Godot: EquipmentScreen stats_recalculated */}
          <div className="pt-2 border-t border-[var(--border-subtle)]">
            <p className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider mb-2">
              📊 Toplam İstatistik
            </p>
            <div className="grid grid-cols-2 gap-2 text-xs">
              <div className="flex justify-between bg-[var(--bg-darker)] rounded px-2 py-1">
                <span className="text-[var(--text-muted)]">⚔️ Saldırı</span>
                <span className="text-red-400 font-bold">+{totalStats.attack}</span>
              </div>
              <div className="flex justify-between bg-[var(--bg-darker)] rounded px-2 py-1">
                <span className="text-[var(--text-muted)]">🛡️ Savunma</span>
                <span className="text-blue-400 font-bold">+{totalStats.defense}</span>
              </div>
              <div className="flex justify-between bg-[var(--bg-darker)] rounded px-2 py-1">
                <span className="text-[var(--text-muted)]">❤️ Can</span>
                <span className="text-green-400 font-bold">+{totalStats.health}</span>
              </div>
              <div className="flex justify-between bg-[var(--bg-darker)] rounded px-2 py-1">
                <span className="text-[var(--text-muted)]">💥 Güç</span>
                <span className="text-purple-400 font-bold">+{totalStats.power}</span>
              </div>
            </div>
          </div>
        </motion.div>

        {/* Right Column: Character Stats / Detail Panel */}
        <motion.div
          initial={{ x: 30, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ delay: 0.1 }}
          className="w-full lg:flex-1 flex-shrink"
        >
          <InventoryDetailPanel
            item={selectedItem}
            onClose={() => setSelectedItem(null)}
            onUseClick={handleUseItem}
            onEquipClick={() => {
              if (selectedItem && selectedItem.equip_slot !== "none" && !selectedItem.is_equipped) {
                equipItem(selectedItem.row_id, selectedItem.equip_slot);
              }
            }}
            onSellClick={() => setActiveSellDialog(true)}
            onTrashClick={() => setActiveDeleteDialog(true)}
            onSplitClick={() => setActiveSplitDialog(true)}
            onFavoriteToggle={handleToggleFavorite}
          />
        </motion.div>
      </div>

      {/* Bottom: Inventory Grid (Full Width) */}
      <motion.div
        initial={{ y: 30, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.2 }}
        className="bg-gradient-to-br from-[var(--bg-card)] to-[var(--bg-darker)] p-6 rounded-xl border border-[var(--border-subtle)] shadow-lg"
      >
        <div className="mb-4">
          <p className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider mb-3">
            📦 Envanter - {items.filter((i) => !i.is_equipped).length.toString().padStart(2, "0")}/{INVENTORY_CAPACITY} Slot
          </p>
          {/* Filter & Sort Controls — Godot: InventoryScreen filter/sort buttons */}
          <InventoryFilterBar activeFilter={activeFilter} onFilterChange={setActiveFilter} />
          <div className="mt-2">
            <InventorySortControls
              sortBy={sortBy}
              isAscending={sortAscending}
              onSortChange={setSortBy}
              onToggleOrder={() => setSortAscending((v) => !v)}
            />
          </div>
        </div>

        {isLoading ? (
          <div className="flex justify-center items-center h-60">
            <div className="relative w-12 h-12">
              <motion.div
                animate={{ rotate: 360 }}
                transition={{ duration: 1.5, repeat: Infinity, ease: "linear" }}
                className="absolute inset-0 border-4 border-transparent border-t-[var(--accent)] rounded-full"
              />
            </div>
          </div>
        ) : (
          <>
            <InventoryGrid
              items={displayItems}
              selectedItemId={selectedItem?.row_id}
              activeItemId={activeId}
              onItemClick={handleItemClick}
            />

            <InventoryDragOverlay activeItem={activeItem} isDragging={!!activeId} />
          </>
        )}
      </motion.div>

      {/* Close DnD scope so equipment droppables are included */}
      </DndContext>

      {/* Dialogs */}
      <SellDialog
        item={activeSellDialog ? selectedItem : null}
        onConfirm={handleSellItem}
        onCancel={() => setActiveSellDialog(false)}
      />
      <SplitStackDialog
        item={activeSplitDialog ? selectedItem : null}
        onConfirm={handleSplitStack}
        onCancel={() => setActiveSplitDialog(false)}
      />

      <DeleteConfirmDialog
        item={activeDeleteDialog ? selectedItem : null}
        onConfirm={handleTrashItem}
        onCancel={() => setActiveDeleteDialog(false)}
      />
    </motion.div>
  );
}
