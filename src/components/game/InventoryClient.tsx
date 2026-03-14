// ============================================================
// InventoryClient — Main inventory UI (Oyun Stili)
// Layout: Ekipman (Sol) | Karakter (Sağ) | Envanter Grid (Alt)
// Smooth drag-drop with visual feedback
// ============================================================

"use client";

import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { DndContext, DragEndEvent, DragStartEvent, DragCancelEvent, pointerWithin } from "@dnd-kit/core";
import { PointerSensor, useSensor, useSensors, KeyboardSensor } from "@dnd-kit/core";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import type { InventoryItem } from "@/types/inventory";
import { INVENTORY_CAPACITY } from "@/types/inventory";
import { InventoryGrid } from "./InventoryGrid";
import { InventoryDetailPanel } from "./InventoryDetailPanel";
import { EquipmentGrid } from "./EquipmentGrid";
import { InventoryDragOverlay } from "./InventoryDragOverlay";
import { SellDialog, SplitStackDialog, DeleteConfirmDialog } from "./InventoryDialogs";

export function InventoryClient() {
  const {
    items,
    equippedItems,
    isLoading,
    error,
    fetchInventory,
    equipItem,
    unequipItem,
    unequipItemToSlot,
    moveItemToSlot,
    swapSlots,
    sellItemByRow,
    trashItem,
    removeItemByRowId,
    splitStack,
    toggleFavorite,
    usePotion,
    useDetox,
  } = useInventoryStore();

  const player = usePlayerStore((s) => s.player);
  const tolerance = usePlayerStore((s) => s.tolerance);
  const level = usePlayerStore((s) => s.level);
  const xp = usePlayerStore((s) => s.xp);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const addToast = useUiStore((s) => s.addToast);

  // UI State
  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);

  // Dialog State
  const [activeSellDialog, setActiveSellDialog] = useState(false);
  const [activeSplitDialog, setActiveSplitDialog] = useState(false);
  const [activeDeleteDialog, setActiveDeleteDialog] = useState(false);
  const [potionConfirmOpen, setPotionConfirmOpen] = useState(false);
  const [detoxConfirmOpen, setDetoxConfirmOpen] = useState(false);

  // Drag-Drop State
  const [activeId, setActiveId] = useState<string | null>(null);
  const [activeItem, setActiveItem] = useState<InventoryItem | null>(null);
  const dragTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor)
  );

  // Fetch on mount
  // Detailed logging: clear console and show full state on mount
  const logFullInventory = () => {
    const state = useInventoryStore.getState();
    console.groupCollapsed('[InventoryClient] Full Inventory State');
    console.log('items count:', state.items.length);
    console.table(
      state.items.map((i) => ({
        row_id: i.row_id,
        item_id: i.item_id,
        name: i.name,
        slot_position: i.slot_position,
        is_equipped: i.is_equipped,
        equip_slot: (i as any).equip_slot ?? (i as any).equipped_slot ?? null,
        quantity: i.quantity,
      }))
    );
    console.log('equipped map:', state.equippedItems);
    console.groupEnd();
  };

  useEffect(() => {
    (async () => {
      console.clear();
      console.info('[InventoryClient] initializing — clearing logs');
      await fetchInventory();
      logFullInventory();
    })();
  }, [fetchInventory]);

  // =========== HANDLERS ===========

  const handleItemClick = (item: InventoryItem) => {
    setSelectedItem(item);
  };

  const handleSellItem = async (quantity: number) => {
    if (!selectedItem) return;
    try {
      const result = await sellItemByRow(selectedItem.row_id, quantity);
      if (result.success) {
        addToast(`Satış başarılı (+${result.goldEarned ?? 0} 🪙)`, "success");
        await usePlayerStore.getState().fetchProfile();
      } else {
        addToast(result.error || "Satış başarısız", "error");
      }
    } finally {
      setActiveSellDialog(false);
      setSelectedItem(null);
      await fetchInventory(true);
    }
  };

  const handleSplitStack = async (splitQuantity: number) => {
    if (!selectedItem) return;
    await splitStack(selectedItem.row_id, splitQuantity);
    setActiveSplitDialog(false);
    setSelectedItem(null);
    await fetchInventory(true);
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
      await fetchInventory(true);
    }
  };

  const handleToggleFavorite = async () => {
    if (!selectedItem) return;
    await toggleFavorite(selectedItem.row_id);
    setSelectedItem((prev) =>
      prev ? { ...prev, is_favorite: !prev.is_favorite } : null
    );
  };

  const handleUseItemClick = () => {
    if (!selectedItem) return;
    if (selectedItem.item_type === "potion" || selectedItem.item_type === "consumable") {
      if (selectedItem.item_id.includes("detox") || (selectedItem as any).sub_type === "detox") {
        setDetoxConfirmOpen(true);
      } else {
        setPotionConfirmOpen(true);
      }
    } else {
      // Handle other useables if needed
    }
  };

  const confirmUsePotion = async () => {
    if (!selectedItem) return;
    const res = await usePotion(selectedItem.row_id);
    setPotionConfirmOpen(false);
    if (res.success) {
      if (res.overdose) {
        addToast("Aşırı doz! Hastanelik oldunuz.", "error");
      } else {
        addToast("İksir kullanıldı!", "success");
      }
      setSelectedItem(null);
    } else {
      addToast(res.error || "İksir kullanılamadı.", "error");
    }
  };

  const confirmUseDetox = async () => {
    if (!selectedItem) return;
    const res = await useDetox(selectedItem.row_id);
    setDetoxConfirmOpen(false);
    if (res.success) {
      addToast("Detox kullanıldı! Tolerans düştü.", "success");
      setSelectedItem(null);
    } else {
      addToast(res.error || "Detox kullanılamadı.", "error");
    }
  };

  // =========== DND-KIT HANDLERS ===========

  const handleDragStart = (event: DragStartEvent) => {
    const id = String(event.active.id);
    setActiveId(id);
    if (id.startsWith("empty-")) {
      setActiveItem(null);
    } else {
      let it = items.find((x) => x.row_id === id) || null;
      // If not found in inventory items, check equipped items (allow dragging from equipment)
      if (!it) {
        const eq = Object.values(equippedItems).find((e) => e && e.row_id === id) || null;
        it = eq as InventoryItem | null;
      }
      console.log(`[dnd] start id=${id}`);
      console.log(`[dnd] activeItem row_id=${it?.row_id || "null"} name=${it?.name || "null"} slot=${it?.slot_position ?? (it?.equip_slot ?? "null")}`);
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

    // Snapshot before operation for detailed debugging
    console.log('[InventoryClient] Pre-op snapshot', {
      activeId: activeIdStr,
      overId: overIdStr,
      itemsCount: items.length,
      equippedKeys: Object.keys(equippedItems),
    });

    try {
      // Nothing changed
      if (!overIdStr || overIdStr === activeIdStr) {
        setActiveItem(null);
        return;
      }

      // Active item must exist to perform inventory operations
      let dragged = items.find((it) => it.row_id === activeIdStr) || null;
      if (!dragged) {
        const eq = Object.values(equippedItems).find((e) => e && e.row_id === activeIdStr) || null;
        dragged = eq as InventoryItem | null;
      }

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

      // Drop on equipment slot: equip or inventory<->equipped swap
      if (overIdStr.startsWith("equip-")) {
        const slotName = overIdStr.replace(/^equip-/, "");

        // Validate that the item can be equipped in this slot (case-insensitive)
        if (!dragged.equip_slot || String(dragged.equip_slot).toLowerCase() !== String(slotName).toLowerCase()) {
          setActiveItem(null);
          setSelectedItem(dragged);
          console.warn(`Cannot equip ${dragged.name} to slot ${slotName}`);
          return;
        }

        const normalizedSlot = String(slotName).toLowerCase();
        const equippedInTarget = equippedItems[normalizedSlot] ?? null;

        // If the target equipment slot is already occupied and dragged item comes
        // from inventory, use atomic server-side swap to avoid losing slot_position.
        if (!dragged.is_equipped && equippedInTarget && equippedInTarget.row_id !== dragged.row_id) {
          const swapSuccess = await useInventoryStore.getState().swapEquipWithSlot(normalizedSlot, dragged.slot_position);
          if (!swapSuccess) {
            const storeError = useInventoryStore.getState().error;
            if (storeError) addToast(storeError, "error");
            setActiveItem(null);
            await fetchInventory(true);
            return;
          }
        } else {
          await equipItem(dragged.row_id, normalizedSlot);
        }

        setActiveItem(null);
        await fetchInventory(true);
        return;
      }

      // Detect if dragged came from equipment (must be actually equipped)
      const draggedEquipSlot = dragged.is_equipped
        ? (dragged.equip_slot || dragged.equipped_slot || null)
        : null;

      // Drop on inventory slot (empty or occupied)
      if (overIdStr.startsWith("empty-")) {
        const idx = parseInt(overIdStr.replace(/^empty-/, ""), 10);
        if (!Number.isNaN(idx)) {
          // If dragging an equipped item back into an inventory slot, use unequipItemToSlot
          if (dragged.is_equipped && draggedEquipSlot) {
            const success = await unequipItemToSlot(dragged.row_id, draggedEquipSlot, idx);
            if (!success) {
              const storeError = useInventoryStore.getState().error;
              if (storeError) addToast(storeError, "error");
              setActiveItem(null);
              return;
            }
          } else {
            await moveItemToSlot(dragged.row_id, idx);
          }
          await fetchInventory(true);
        }
      } else {
        console.log(`[dnd] over is not empty - checking swap/equip over=${overIdStr}`);
        // over is another item id -> swap OR equip-swap when dragging from equipment
        const target = items.find((it) => it.row_id === overIdStr);
        if (target) {
          // If dragging an equipped item onto an occupied inventory slot,
          // equip the inventory target into the dragged equip slot, and move the previously equipped
          // item into the target slot.
          if (draggedEquipSlot && dragged.is_equipped) {
            // Atomically swap equipped item and inventory item on server
            console.log('[InventoryClient] calling swapEquipWithSlot', { draggedEquipSlot, targetSlot: target.slot_position, draggedRow: dragged.row_id, targetRow: target.row_id });
            const success = await useInventoryStore.getState().swapEquipWithSlot(draggedEquipSlot, target.slot_position);
            console.log('[InventoryClient] swapEquipWithSlot finished, success=', success, 'storeError=', useInventoryStore.getState().error);
            if (!success) {
              const storeError = useInventoryStore.getState().error;
              if (storeError) addToast(storeError, "error");
              setActiveItem(null);
              await fetchInventory(true);
              return;
            }
          } else {
            // Regular inventory <-> inventory swap
            console.log(`[dnd] Regular swap: dragged[${dragged.row_id}] slot=${dragged.slot_position} is_equipped=${dragged.is_equipped}, target[${target.row_id}] slot=${target.slot_position} is_equipped=${target.is_equipped}`);
            console.log('[InventoryClient] calling swapSlots', { from: dragged.slot_position, to: target.slot_position });
            const swapOk = await swapSlots(dragged.slot_position, target.slot_position);
            console.log('[InventoryClient] swapSlots result:', swapOk, 'storeError=', useInventoryStore.getState().error);
          }
          await fetchInventory(true);
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
        {/* Left Column: Equipment Grid */}
        <motion.div
          initial={{ x: -30, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ delay: 0.1 }}
          className="w-full lg:w-80 flex-shrink-0 bg-gradient-to-br from-[var(--bg-card)] to-[var(--bg-darker)] p-4 rounded-xl border border-[var(--border-subtle)] shadow-lg"
        >
          <p className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider mb-3">
            🛡️ Kuşanılan Eşyalar
          </p>
          <EquipmentGrid equippedItems={equippedItems} />
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
            onUseClick={handleUseItemClick}
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
          <p className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider">
            📦 Envanter - {items.length.toString().padStart(2, "0")}/{INVENTORY_CAPACITY} Slot
          </p>
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
              items={items}
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

      {/* Potion Use Confirm Dialog */}
      {potionConfirmOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <div className="bg-[var(--bg-card)] border border-[var(--border-subtle)] rounded-xl p-6 w-full max-w-sm">
            <h3 className="text-lg font-bold text-[var(--color-warning)] mb-2">İksir Kullan</h3>
            <p className="text-sm text-[var(--text-secondary)] mb-4">
              Mevcut Toleransınız: <span className="text-white font-bold">{tolerance}/100</span>
            </p>
            {tolerance > 50 && (
              <p className="text-xs text-[var(--color-error)] bg-[var(--color-error)]/10 p-2 rounded mb-4">
                ⚠️ Dikkat! Toleransınız yüksek. Overdose (aşırı doz) riski var! İksirin etkisi de düşük olacaktır.
              </p>
            )}
            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setPotionConfirmOpen(false)}
                className="flex-1 py-2 rounded-lg bg-[var(--bg-input)] hover:bg-[var(--bg-darker)] text-white transition"
              >
                İptal
              </button>
              <button
                onClick={confirmUsePotion}
                className="flex-1 py-2 rounded-lg bg-green-600 hover:bg-green-700 text-white transition font-bold"
              >
                Kullan
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Detox Use Confirm Dialog */}
      {detoxConfirmOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <div className="bg-[var(--bg-card)] border border-[var(--border-subtle)] rounded-xl p-6 w-full max-w-sm">
            <h3 className="text-lg font-bold text-[var(--color-success)] mb-2">Detox Kullan</h3>
            <p className="text-sm text-[var(--text-secondary)] mb-4">
              Detox kullanarak tolerans seviyenizi ve bağımlılığınızı düşürebilirsiniz. Kullanmak istediğinize emin misiniz?
            </p>
            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setDetoxConfirmOpen(false)}
                className="flex-1 py-2 rounded-lg bg-[var(--bg-input)] hover:bg-[var(--bg-darker)] text-white transition"
              >
                İptal
              </button>
              <button
                onClick={confirmUseDetox}
                className="flex-1 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition font-bold"
              >
                Detox Yap
              </button>
            </div>
          </div>
        </div>
      )}
    </motion.div>
  );
}
