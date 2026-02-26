// ============================================================
// Equipment Page — Kaynak: scenes/ui/screens/EquipmentScreen.gd
// Karakter paperdoll + 8 ekipman slotu
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useEnhancement } from "@/hooks/useEnhancement";
import type { InventoryItem } from "@/types/inventory";
import { ItemIcon } from "@/components/game/ItemIcon";
import type { EquipSlot, Rarity } from "@/types/item";
import { getDisplayName, getRarityColor } from "@/types/item";

const EQUIP_SLOTS: { slot: EquipSlot; label: string; icon: string }[] = [
  { slot: "weapon", label: "Silah", icon: "⚔️" },
  { slot: "head", label: "Kask", icon: "🪖" },
  { slot: "chest", label: "Zırh", icon: "🛡️" },
  { slot: "legs", label: "Bacak", icon: "🦿" },
  { slot: "boots", label: "Ayakkabı", icon: "👢" },
  { slot: "gloves", label: "Eldiven", icon: "🧤" },
  { slot: "ring", label: "Yüzük", icon: "💍" },
  { slot: "necklace", label: "Kolye", icon: "📿" },
];

export default function EquipmentPage() {
  const items = useInventoryStore((s) => s.items);
  const equippedItems = useInventoryStore((s) => s.equippedItems);
  const equipItem = useInventoryStore((s) => s.equipItem);
  const unequipItem = useInventoryStore((s) => s.unequipItem);
  const addToast = useUiStore((s) => s.addToast);
  const level = usePlayerStore((s) => s.level);
  const { getEnhancementInfo, enhanceItem, isEnhancing, lastResult } = useEnhancement();

  const [selectedSlot, setSelectedSlot] = useState<EquipSlot | null>(null);
  const [showItemPicker, setShowItemPicker] = useState(false);

  // Calculate total stats from equipped items
  const totalStats = {
    attack: 0,
    defense: 0,
    health: 0,
    power: 0,
  };
  Object.values(equippedItems).forEach((item) => {
    if (item) {
      const bonus = 1 + (item.enhancement_level ?? 0) * 0.1;
      totalStats.attack += Math.floor((item.attack ?? 0) * bonus);
      totalStats.defense += Math.floor((item.defense ?? 0) * bonus);
      totalStats.health += Math.floor((item.health ?? 0) * bonus);
      totalStats.power += Math.floor((item.power ?? 0) * bonus);
    }
  });

  // Items available for a slot
  const getSlotItems = useCallback(
    (slot: EquipSlot): InventoryItem[] =>
      items.filter(
        (i) =>
          i.equip_slot === slot &&
          i.required_level <= level &&
          !Object.values(equippedItems).some((e) => e?.item_id === i.item_id)
      ),
    [items, level, equippedItems]
  );

  const handleEquip = useCallback(
    async (item: InventoryItem) => {
      if (item.equip_slot === "none") return;
      await equipItem(item.item_id, item.equip_slot);
      setShowItemPicker(false);
      addToast(`${getDisplayName(item)} kuşanıldı!`, "success");
    },
    [equipItem, addToast]
  );

  const handleUnequip = useCallback(
    async (slot: EquipSlot) => {
      await unequipItem(slot);
      addToast("Eşya çıkarıldı", "info");
    },
    [unequipItem, addToast]
  );

  return (
    <div className="p-4 space-y-4 pb-24">
      {/* Header */}
      <h1 className="text-xl font-bold text-[var(--gold)]">Ekipman</h1>

      {/* Total Stats Summary */}
      <div className="grid grid-cols-4 gap-2 bg-[var(--card-bg)] rounded-xl p-3">
        {[
          { label: "Saldırı", value: totalStats.attack, color: "#ef4444" },
          { label: "Savunma", value: totalStats.defense, color: "#3b82f6" },
          { label: "Can", value: totalStats.health, color: "#22c55e" },
          { label: "Güç", value: totalStats.power, color: "#a855f7" },
        ].map((stat) => (
          <div key={stat.label} className="text-center">
            <p className="text-xs text-[var(--text-secondary)]">{stat.label}</p>
            <p className="font-bold" style={{ color: stat.color }}>
              {stat.value}
            </p>
          </div>
        ))}
      </div>

      {/* Equipment Grid — Paperdoll style */}
      <div className="grid grid-cols-2 gap-3">
        {EQUIP_SLOTS.map(({ slot, label, icon }) => {
          const equipped = equippedItems[slot] ?? null;
          return (
            <motion.div
              key={slot}
              whileTap={{ scale: 0.97 }}
              className="bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-3 text-left focus:outline-none"
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  if (equipped) {
                    setSelectedSlot(slot);
                  } else {
                    setSelectedSlot(slot);
                    setShowItemPicker(true);
                  }
                }
              }}
              onClick={() => {
                if (equipped) {
                  setSelectedSlot(slot);
                } else {
                  setSelectedSlot(slot);
                  setShowItemPicker(true);
                }
              }}
            >
              <div className="flex items-center gap-2 mb-1">
                <span className="text-lg">{icon}</span>
                <span className="text-xs text-[var(--text-secondary)]">{label}</span>
              </div>
              {equipped ? (
                <div>
                  <p
                    className="text-sm font-medium truncate"
                    style={{ color: getRarityColor(equipped.rarity as Rarity) }}
                  >
                    {getDisplayName(equipped)}
                  </p>
                  <div className="flex justify-between mt-1">
                    {/* enhancement badge is shown by ItemIcon; remove duplicate text under item */}
                    <button
                      className="text-xs text-red-400 hover:text-red-300"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleUnequip(slot);
                      }}
                    >
                      Çıkar
                    </button>
                  </div>
                </div>
              ) : (
                <p className="text-xs text-[var(--text-secondary)] italic">Boş</p>
              )}
            </motion.div>
          );
        })}
      </div>

      {/* Item Picker Modal */}
      <AnimatePresence>
        {showItemPicker && selectedSlot && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/70 z-50 flex items-end"
            onClick={() => setShowItemPicker(false)}
          >
            <motion.div
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              className="bg-[var(--surface)] rounded-t-2xl p-4 w-full max-h-[60vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <h2 className="text-lg font-bold mb-3">
                {EQUIP_SLOTS.find((s) => s.slot === selectedSlot)?.label} Seç
              </h2>
              {getSlotItems(selectedSlot).length === 0 ? (
                <p className="text-center text-[var(--text-secondary)] py-8">
                  Bu slot için uygun eşya yok
                </p>
              ) : (
                <div className="space-y-2">
                  {getSlotItems(selectedSlot).map((item) => (
                    <button
                      key={item.item_id}
                      className="w-full flex items-center gap-3 bg-[var(--card-bg)] rounded-lg p-3 hover:bg-[var(--border)]"
                      onClick={() => handleEquip(item)}
                    >
                      <ItemIcon icon={item.icon} itemType={item.item_type} itemId={item.item_id ?? item.row_id} className="text-2xl" />
                      <div className="flex-1 text-left">
                        <p
                          className="font-medium"
                          style={{ color: getRarityColor(item.rarity as Rarity) }}
                        >
                          {getDisplayName(item)}
                        </p>
                        <p className="text-xs text-[var(--text-secondary)]">
                          ATK:{item.attack ?? 0} DEF:{item.defense ?? 0} HP:
                          {item.health ?? 0}
                        </p>
                      </div>
                      <span className="text-xs text-[var(--text-secondary)]">
                        Lv.{item.required_level}
                      </span>
                    </button>
                  ))}
                </div>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
