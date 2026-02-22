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
import { INVENTORY_CAPACITY } from "@/types/inventory";
import type { InventoryItem } from "@/types/inventory";
import type { ItemType } from "@/types/item";

type FilterType = "all" | "weapon" | "armor" | "consumable" | "material";

const FILTERS: { key: FilterType; label: string; emoji: string }[] = [
  { key: "all", label: "Tümü", emoji: "📦" },
  { key: "weapon", label: "Silahlar", emoji: "⚔️" },
  { key: "armor", label: "Zırhlar", emoji: "🛡️" },
  { key: "consumable", label: "Tüketim", emoji: "🧪" },
  { key: "material", label: "Malzeme", emoji: "🪨" },
];

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
  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);

  useEffect(() => {
    fetchInventory();
  }, [fetchInventory]);

  // Filter items
  const filteredItems = useMemo(() => {
    if (activeFilter === "all") return items;
    const typeMap: Record<FilterType, ItemType[]> = {
      all: [],
      weapon: ["weapon"],
      armor: ["armor"],
      consumable: ["consumable", "potion"],
      material: ["material"],
    };
    const types = typeMap[activeFilter];
    return items.filter((i) => types.includes(i.item_type));
  }, [items, activeFilter]);

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

      {/* Inventory count */}
      <div className="flex items-center justify-between">
        <p className="text-xs text-[var(--text-muted)]">
          {items.length} / {INVENTORY_CAPACITY} slot
        </p>
        <p className="text-xs text-[var(--text-muted)]">
          Kuşanılan: {Object.values(equippedItems).filter(Boolean).length}
        </p>
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
    </div>
  );
}
