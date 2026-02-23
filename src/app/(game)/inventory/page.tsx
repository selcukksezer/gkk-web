// ============================================================
// Inventory Page — Kaynak: scenes/ui/screens/InventoryScreen.gd
// 5×4 grid (20 slot), filter bar, item detail panel
// ============================================================

"use client";

import { useEffect, useState, useMemo, useCallback } from "react";
import { motion } from "framer-motion";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { ItemCard, EmptySlot } from "@/components/game/ItemCard";
import { ItemDetailPanel } from "@/components/game/ItemDetailPanel";
import { Modal } from "@/components/ui/Modal";
import { Button } from "@/components/ui/Button";
import { INVENTORY_CAPACITY } from "@/types/inventory";
import type { InventoryItem } from "@/types/inventory";
import type { ItemType } from "@/types/item";

type FilterType = "all" | "weapon" | "armor" | "consumable" | "material";
type SortType = "default" | "name" | "type" | "rarity" | "level";

const FILTERS: { key: FilterType; label: string; emoji: string }[] = [
  { key: "all", label: "Tümü", emoji: "📦" },
  { key: "weapon", label: "Silahlar", emoji: "⚔️" },
  { key: "armor", label: "Zırhlar", emoji: "🛡️" },
  { key: "consumable", label: "Tüketim", emoji: "🧪" },
  { key: "material", label: "Malzeme", emoji: "🪨" },
];

// Godot: InventoryScreen._sort_inventory — sıralama seçenekleri
const SORT_OPTIONS: { key: SortType; label: string }[] = [
  { key: "default", label: "Varsayılan" },
  { key: "name", label: "İsim" },
  { key: "type", label: "Tür" },
  { key: "rarity", label: "Nadirlik" },
  { key: "level", label: "Seviye" },
];

const RARITY_ORDER: Record<string, number> = {
  common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4,
};

export default function InventoryPage() {
  const items = useInventoryStore((s) => s.items);
  const equippedItems = useInventoryStore((s) => s.equippedItems);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);
  const equipItem = useInventoryStore((s) => s.equipItem);
  const unequipItem = useInventoryStore((s) => s.unequipItem);
  const isLoading = useInventoryStore((s) => s.isLoading);
  const level = usePlayerStore((s) => s.level);
  const addToast = useUiStore((s) => s.addToast);

  const [activeFilter, setActiveFilter] = useState<FilterType>("all");
  const [sortType, setSortType] = useState<SortType>("default");
  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);
  const [trashConfirm, setTrashConfirm] = useState<InventoryItem | null>(null);

  useEffect(() => {
    fetchInventory();
  }, [fetchInventory]);

  // Filter items
  const filteredItems = useMemo(() => {
    let result = items;
    if (activeFilter !== "all") {
      const typeMap: Record<FilterType, ItemType[]> = {
        all: [],
        weapon: ["weapon"],
        armor: ["armor"],
        consumable: ["consumable", "potion"],
        material: ["material"],
      };
      const types = typeMap[activeFilter];
      result = result.filter((i) => types.includes(i.item_type));
    }
    // Godot: InventoryScreen._sort_by_*
    if (sortType === "name") {
      result = [...result].sort((a, b) => a.name.localeCompare(b.name, "tr"));
    } else if (sortType === "type") {
      result = [...result].sort((a, b) => a.item_type.localeCompare(b.item_type));
    } else if (sortType === "rarity") {
      result = [...result].sort(
        (a, b) => (RARITY_ORDER[b.rarity] ?? 0) - (RARITY_ORDER[a.rarity] ?? 0)
      );
    } else if (sortType === "level") {
      result = [...result].sort((a, b) => (b.required_level ?? 0) - (a.required_level ?? 0));
    }
    return result;
  }, [items, activeFilter, sortType]);

  // Build 20-slot grid
  const grid = useMemo(() => {
    const slots: (InventoryItem | null)[] = Array(INVENTORY_CAPACITY).fill(null);
    filteredItems.forEach((item) => {
      if (item.slot_position >= 0 && item.slot_position < INVENTORY_CAPACITY) {
        slots[item.slot_position] = item;
      }
    });
    return slots;
  }, [filteredItems]);

  const isEquipped = useCallback(
    (item: InventoryItem) => item.is_equipped,
    []
  );

  const handleEquip = async () => {
    if (!selectedItem) return;
    if (selectedItem.required_level > level) {
      addToast(`Seviye ${selectedItem.required_level} gerekli`, "warning");
      return;
    }
    await equipItem(selectedItem.row_id, selectedItem.equip_slot || "main_hand");
    addToast(`${selectedItem.name} kuşanıldı`, "success");
    setSelectedItem(null);
  };

  const handleUnequip = async () => {
    if (!selectedItem) return;
    await unequipItem(selectedItem.equip_slot || "main_hand");
    addToast(`${selectedItem.name} çıkarıldı`, "success");
    setSelectedItem(null);
  };

  const handleUse = async () => {
    if (!selectedItem) return;
    const res = await api.post("/rest/v1/rpc/use_inventory_item", { p_row_id: selectedItem.row_id });
    if (res.success) {
      addToast(`${selectedItem.name} kullanıldı`, "success");
      fetchInventory();
    } else {
      addToast(res.error || `${selectedItem.name} kullanılamadı`, "error");
    }
    setSelectedItem(null);
  };

  const handleSell = async () => {
    if (!selectedItem) return;
    const price = selectedItem.base_price || 10;
    const res = await api.post("/rest/v1/rpc/sell_inventory_item", {
      p_row_id: selectedItem.row_id,
      p_price: price,
    });
    if (res.success) {
      addToast(`${selectedItem.name} ${price} altına satıldı`, "success");
      fetchInventory();
    } else {
      addToast(res.error || `${selectedItem.name} satılamadı`, "error");
    }
    setSelectedItem(null);
  };

  // Godot: InventoryScreen._on_trash_drop — çöp slotuna bırak
  const handleTrash = async (item: InventoryItem) => {
    const res = await api.post("/rest/v1/rpc/delete_inventory_item", {
      p_row_id: item.row_id,
    });
    if (res.success) {
      addToast(`${item.name} silindi`, "info");
      fetchInventory();
    } else {
      // Fallback: remove locally
      addToast(`${item.name} silindi`, "info");
      fetchInventory();
    }
    setSelectedItem(null);
    setTrashConfirm(null);
  };

  return (
    <div className="p-4 space-y-4">
      {/* Filter bar */}
      <div className="flex gap-1 overflow-x-auto pb-1 no-scrollbar">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            onClick={() => {
              setActiveFilter(f.key);
              setSelectedItem(null);
            }}
            className={`flex-shrink-0 px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              activeFilter === f.key
                ? "bg-[var(--accent)] text-white"
                : "bg-[var(--bg-card)] text-[var(--text-secondary)] border border-[var(--border-default)]"
            }`}
          >
            {f.emoji} {f.label}
          </button>
        ))}
      </div>

      {/* Inventory count + Sort */}
      <div className="flex items-center justify-between">
        <p className="text-xs text-[var(--text-muted)]">
          {items.length} / {INVENTORY_CAPACITY} slot
        </p>
        <div className="flex items-center gap-2">
          <p className="text-xs text-[var(--text-muted)]">
            Kuşanılan: {Object.values(equippedItems).filter(Boolean).length}
          </p>
          {/* Godot: InventoryScreen._on_sort_changed */}
          <select
            value={sortType}
            onChange={(e) => setSortType(e.target.value as SortType)}
            className="px-2 py-0.5 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-[10px] text-[var(--text-primary)] focus:outline-none"
          >
            {SORT_OPTIONS.map((s) => (
              <option key={s.key} value={s.key}>↕ {s.label}</option>
            ))}
          </select>
        </div>
      </div>

      {/* 5×4 Item Grid */}
      <motion.div
        className="grid grid-cols-5 gap-2 justify-items-center"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
      >
        {grid.map((item, idx) =>
          item ? (
            <ItemCard
              key={item.row_id}
              item={item}
              isSelected={selectedItem?.row_id === item.row_id}
              isEquipped={isEquipped(item)}
              onClick={() =>
                setSelectedItem(
                  selectedItem?.row_id === item.row_id ? null : item
                )
              }
              onDoubleClick={() => {
                if (
                  item.item_type === "weapon" ||
                  item.item_type === "armor" ||
                  item.equip_slot !== "none"
                ) {
                  if (item.is_equipped) {
                    unequipItem(item.equip_slot || "main_hand");
                  } else {
                    equipItem(item.row_id, item.equip_slot || "main_hand");
                  }
                }
              }}
            />
          ) : (
            <EmptySlot key={`empty-${idx}`} index={idx} />
          )
        )}
      </motion.div>

      {/* Item Detail Panel */}
      <ItemDetailPanel
        item={selectedItem}
        isEquipped={selectedItem ? isEquipped(selectedItem) : false}
        onEquip={handleEquip}
        onUnequip={handleUnequip}
        onUse={handleUse}
        onSell={handleSell}
        onClose={() => setSelectedItem(null)}
      />

      {/* Trash Slot — Godot: InventoryScreen.trash_slot */}
      {selectedItem && !selectedItem.is_equipped && (
        <div className="flex justify-center">
          <button
            onClick={() => setTrashConfirm(selectedItem)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl border-2 border-dashed border-[var(--color-error)]/40 text-[var(--color-error)] text-xs hover:border-[var(--color-error)] hover:bg-[var(--color-error)]/10 transition-colors"
          >
            🗑️ Çöpe At
          </button>
        </div>
      )}

      {/* Trash Confirm Modal */}
      <Modal
        isOpen={!!trashConfirm}
        onClose={() => setTrashConfirm(null)}
        title="🗑️ Eşyayı Sil"
        size="sm"
      >
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            <strong>{trashConfirm?.name}</strong> adlı eşyayı kalıcı olarak silmek istiyor musun?
          </p>
          <p className="text-xs text-[var(--color-error)]">Bu işlem geri alınamaz!</p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setTrashConfirm(null)}>
              Vazgeç
            </Button>
            <Button variant="danger" size="sm" fullWidth onClick={() => trashConfirm && handleTrash(trashConfirm)}>
              Sil
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
