// ============================================================
// Item Detail Panel — Seçilen item bilgileri + aksiyonlar
// ============================================================

"use client";

import { motion, AnimatePresence } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";
import { getRarityColor, getRarityLabel, getDisplayName } from "@/types/item";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";

interface ItemDetailPanelProps {
  item: InventoryItem | null;
  isEquipped: boolean;
  onEquip: () => void;
  onUnequip: () => void;
  onUse: () => void;
  onSell: () => void;
  onClose: () => void;
}

const typeLabels: Record<string, string> = {
  weapon: "Silah",
  armor: "Zırh",
  accessory: "Aksesuar",
  consumable: "Tüketim",
  material: "Malzeme",
  potion: "İksir",
  scroll: "Tomarr",
  key_item: "Anahtar Eşya",
  quest_item: "Görev Eşyası",
  recipe: "Tarif",
};

export function ItemDetailPanel({
  item,
  isEquipped,
  onEquip,
  onUnequip,
  onUse,
  onSell,
  onClose,
}: ItemDetailPanelProps) {
  return (
    <AnimatePresence>
      {item && (
        <motion.div
          key={item.row_id}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 20 }}
          transition={{ duration: 0.2 }}
        >
          <Card variant="elevated">
            <div className="p-4">
              {/* Header */}
              <div className="flex items-start justify-between mb-3">
                <div>
                  <h3
                    className="font-bold text-base"
                    style={{ color: getRarityColor(item.rarity) }}
                  >
                    {getDisplayName(item)}
                  </h3>
                  <p className="text-xs text-[var(--text-muted)]">
                    {typeLabels[item.item_type] || item.item_type} •{" "}
                    {getRarityLabel(item.rarity)}
                  </p>
                </div>
                <button
                  onClick={onClose}
                  className="text-[var(--text-muted)] hover:text-[var(--text-primary)] text-lg"
                >
                  ✕
                </button>
              </div>

              {/* Stats */}
              <div className="space-y-1 mb-3 text-xs text-[var(--text-secondary)]">
                {item.attack > 0 && (
                  <p>⚔️ Saldırı: <span className="text-[var(--text-primary)]">+{item.attack}</span></p>
                )}
                {item.defense > 0 && (
                  <p>🛡️ Savunma: <span className="text-[var(--text-primary)]">+{item.defense}</span></p>
                )}
                {item.power > 0 && (
                  <p>✨ Güç: <span className="text-[var(--text-primary)]">+{item.power}</span></p>
                )}
                {item.health > 0 && (
                  <p>❤️ HP: <span className="text-[var(--text-primary)]">+{item.health}</span></p>
                )}
                {item.mana > 0 && (
                  <p>🔮 Mana: <span className="text-[var(--text-primary)]">+{item.mana}</span></p>
                )}
                {item.enhancement_level > 0 && (
                  <p>🔧 Geliştirme: <span className="text-[var(--accent-light)]">+{item.enhancement_level}</span></p>
                )}
                {item.required_level > 0 && (
                  <p>📊 Gerekli Seviye: {item.required_level}</p>
                )}
                {item.quantity > 1 && (
                  <p>📦 Adet: {item.quantity}</p>
                )}
              </div>

              {/* Description */}
              {item.description && (
                <p className="text-xs text-[var(--text-muted)] italic mb-3">
                  {item.description}
                </p>
              )}

              {/* Actions */}
              <div className="flex gap-2">
                {/* Equip / Unequip for equipment */}
                {(item.item_type === "weapon" ||
                  item.item_type === "armor" ||
                  item.equip_slot !== "none") && (
                  <>
                    {isEquipped ? (
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={onUnequip}
                        fullWidth
                      >
                        Çıkar
                      </Button>
                    ) : (
                      <Button
                        variant="primary"
                        size="sm"
                        onClick={onEquip}
                        fullWidth
                      >
                        Kuşan
                      </Button>
                    )}
                  </>
                )}

                {/* Use for consumables */}
                {(item.item_type === "consumable" ||
                  item.item_type === "potion") && (
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={onUse}
                    fullWidth
                  >
                    Kullan
                  </Button>
                )}

                {/* Sell */}
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={onSell}
                >
                  🪙 Sat
                </Button>
              </div>
            </div>
          </Card>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
