// ============================================================
// ItemDetailPopup — Full item detail modal with actions
// ============================================================

"use client";

import { motion, AnimatePresence } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";
import type { Rarity } from "@/types/item";
import { getDisplayName, getRarityColor, getRarityLabel } from "@/types/item";

interface ItemDetailPopupProps {
  item: InventoryItem | null;
  isOpen: boolean;
  onClose: () => void;
  onEquip?: (item: InventoryItem) => void;
  onUse?: (item: InventoryItem) => void;
  onDrop?: (item: InventoryItem) => void;
  onEnhance?: (item: InventoryItem) => void;
}

export function ItemDetailPopup({
  item,
  isOpen,
  onClose,
  onEquip,
  onUse,
  onDrop,
  onEnhance,
}: ItemDetailPopupProps) {
  if (!item) return null;

  const rarityColor = getRarityColor(item.rarity as Rarity);
  const isEquippable = item.equip_slot && item.equip_slot !== "none";
  const isConsumable = item.item_type === "consumable" || item.item_type === "potion";
  const canEnhance = item.can_enhance && (item.enhancement_level ?? 0) < (item.max_enhancement ?? 10);

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4"
          onClick={onClose}
        >
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.9, opacity: 0 }}
            className="bg-[var(--surface)] rounded-2xl p-5 w-full max-w-sm"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center gap-3 mb-4">
              <span className="text-3xl">{item.icon ?? "📦"}</span>
              <div>
                <h2 className="font-bold" style={{ color: rarityColor }}>
                  {getDisplayName(item)}
                </h2>
                <p className="text-xs" style={{ color: rarityColor }}>
                  {getRarityLabel(item.rarity as Rarity)}
                </p>
              </div>
            </div>

            {/* Description */}
            <p className="text-sm text-[var(--text-secondary)] mb-4">
              {item.description ?? "Açıklama yok"}
            </p>

            {/* Stats */}
            <div className="grid grid-cols-2 gap-2 mb-4">
              {item.attack > 0 && (
                <Stat label="Saldırı" value={item.attack} color="#ef4444" />
              )}
              {item.defense > 0 && (
                <Stat label="Savunma" value={item.defense} color="#3b82f6" />
              )}
              {item.health > 0 && (
                <Stat label="Can" value={item.health} color="#22c55e" />
              )}
              {item.power > 0 && (
                <Stat label="Güç" value={item.power} color="#a855f7" />
              )}
              {item.energy_restore > 0 && (
                <Stat label="Enerji" value={`+${item.energy_restore}`} color="#eab308" />
              )}
            </div>

            {/* Meta */}
            <div className="text-xs text-[var(--text-secondary)] space-y-1 mb-4">
              {item.required_level > 0 && <p>Gerekli Seviye: {item.required_level}</p>}
              {item.base_price > 0 && <p>Değer: {item.base_price} 🪙</p>}
              {(item.quantity ?? 1) > 1 && <p>Miktar: {item.quantity}</p>}
            </div>

            {/* Actions */}
            <div className="flex gap-2">
              {isEquippable && onEquip && (
                <button
                  className="flex-1 py-2 rounded-lg bg-blue-600 text-white text-sm font-medium"
                  onClick={() => onEquip(item)}
                >
                  Kuşan
                </button>
              )}
              {isConsumable && onUse && (
                <button
                  className="flex-1 py-2 rounded-lg bg-green-600 text-white text-sm font-medium"
                  onClick={() => onUse(item)}
                >
                  Kullan
                </button>
              )}
              {canEnhance && onEnhance && (
                <button
                  className="flex-1 py-2 rounded-lg bg-purple-600 text-white text-sm font-medium"
                  onClick={() => onEnhance(item)}
                >
                  Geliştir
                </button>
              )}
              {onDrop && (
                <button
                  className="py-2 px-3 rounded-lg bg-red-600/20 text-red-400 text-sm"
                  onClick={() => onDrop(item)}
                >
                  At
                </button>
              )}
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function Stat({ label, value, color }: { label: string; value: number | string; color: string }) {
  return (
    <div className="bg-[var(--card-bg)] rounded-lg p-2 text-center">
      <p className="text-[10px] text-[var(--text-secondary)]">{label}</p>
      <p className="font-bold text-sm" style={{ color }}>
        {value}
      </p>
    </div>
  );
}
