// ============================================================
// InventoryDetailPanel — Item detail sidebar
// Displays selected item info: stats, description, action buttons
// ============================================================

"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useInventoryStore } from "@/stores/inventoryStore";
import type { InventoryItem } from "@/types/inventory";
import { getRarityLabel, getDisplayName } from "@/types/item";
import { cn } from "@/lib/utils/cn";

interface InventoryDetailPanelProps {
  item: InventoryItem | null;
  onClose: () => void;
  onUseClick?: () => void;
  onEquipClick?: () => void;
  onSellClick?: () => void;
  onSplitClick?: () => void;
  onTrashClick?: () => void;
  onFavoriteToggle?: () => void;
}

export function InventoryDetailPanel({
  item,
  onClose,
  onUseClick,
  onEquipClick,
  onSellClick,
  onSplitClick,
  onTrashClick,
  onFavoriteToggle,
}: InventoryDetailPanelProps) {
  if (!item) return null;

  const rarityLabel = getRarityLabel(item.rarity);
  const displayName = getDisplayName(item);

  // Determine rarity color
  const rarityColors: Record<string, string> = {
    common: "text-gray-400",
    uncommon: "text-green-400",
    rare: "text-blue-400",
    epic: "text-purple-400",
    legendary: "text-orange-400",
    mythic: "text-red-400",
  };

  const rarityClass = rarityColors[item.rarity] || "text-gray-400";
  const isMarketLocked = item.is_market_tradeable === false || item.is_han_only === true;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0, x: 350 }}
        animate={{ opacity: 1, x: 0 }}
        exit={{ opacity: 0, x: 350 }}
        className="fixed right-0 top-0 h-full w-80 bg-[var(--bg-card)] border-l border-[var(--border-default)] shadow-2xl z-40 flex flex-col"
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-[var(--border-subtle)]">
          <h2 className={cn("text-lg font-bold truncate", rarityClass)}>{displayName}</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-[var(--bg-darker)] rounded transition text-xl"
          >
            ✕
          </button>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {/* Basic Info */}
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-[var(--text-muted)]">Nadirlik:</span>
              <span className={rarityClass}>{rarityLabel}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-[var(--text-muted)]">Tip:</span>
              <span className="text-white capitalize">{item.item_type}</span>
            </div>
            {item.quantity > 1 && (
              <div className="flex justify-between">
                <span className="text-[var(--text-muted)]">Miktar:</span>
                <span className="text-white">{item.quantity}</span>
              </div>
            )}
          </div>

          {/* Description */}
          {item.description && (
            <div>
              <p className="text-xs text-[var(--text-muted)] mb-2">Açıklama</p>
              <p className="text-sm text-[var(--text-default)] bg-[var(--bg-darker)] p-3 rounded">
                {item.description}
              </p>
            </div>
          )}

          {/* Combat Stats */}
          {(item.attack > 0 || item.defense > 0 || item.health > 0 || item.power > 0) && (
            <div className="space-y-2 text-sm">
              <p className="text-xs font-bold text-[var(--text-muted)]">Savaş İstatistikleri</p>
              {item.attack > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Saldırı:</span>
                  <span className="text-red-400">+{item.attack}</span>
                </div>
              )}
              {item.defense > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Savunma:</span>
                  <span className="text-blue-400">+{item.defense}</span>
                </div>
              )}
              {item.health > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Can:</span>
                  <span className="text-green-400">+{item.health}</span>
                </div>
              )}
              {item.power > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Güç:</span>
                  <span className="text-purple-400">+{item.power}</span>
                </div>
              )}
            </div>
          )}

          {/* Enhancement */}
          {item.enhancement_level > 0 && item.can_enhance && (
            <div className="space-y-1 text-sm">
              <p className="text-xs font-bold text-[var(--text-muted)]">Geliştirme</p>
              <div className="flex justify-between">
                <span className="text-[var(--text-muted)]">Seviye:</span>
                <span className="text-yellow-400 font-bold">+{item.enhancement_level}</span>
              </div>
              {item.max_enhancement && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Maks:</span>
                  <span className="text-[var(--text-default)]">+{item.max_enhancement}</span>
                </div>
              )}
            </div>
          )}

          {/* Equipment Requirements */}
          {item.equip_slot !== "none" && (
            <div className="space-y-1 text-sm">
              <p className="text-xs font-bold text-[var(--text-muted)]">Gereksinimler</p>
              {item.required_level > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Seviye:</span>
                  <span className="text-white">{item.required_level}</span>
                </div>
              )}
            </div>
          )}

          {/* Potion Info */}
          {item.item_type === "potion" && (
            <div className="space-y-1 text-sm">
              <p className="text-xs font-bold text-[var(--text-muted)]">İksiriniz Etkileri</p>
              {item.health_restore > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Can İyileştir:</span>
                  <span className="text-green-400">+{item.health_restore}</span>
                </div>
              )}
              {item.energy_restore > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Enerji Geri:</span>
                  <span className="text-yellow-400">+{item.energy_restore}</span>
                </div>
              )}
            </div>
          )}

          {/* Price Info */}
          <div className="space-y-1 text-sm pt-2 border-t border-[var(--border-subtle)]">
            {item.base_price > 0 && (
              <div className="flex justify-between">
                <span className="text-[var(--text-muted)]">Fiyat:</span>
                <span className="text-yellow-400">{item.base_price} ⚔</span>
              </div>
            )}
            {item.vendor_sell_price > 0 && (
              <div className="flex justify-between">
                <span className="text-[var(--text-muted)]">Satış:</span>
                <span className="text-green-400">{item.vendor_sell_price} ⚔</span>
              </div>
            )}
          </div>
        </div>

        {/* Action Buttons */}
        <div className="p-4 border-t border-[var(--border-subtle)] space-y-2">
          {/* Use/Consume */}
          {(item.item_type === "potion" || item.item_type === "consumable") && (
            <button
              onClick={onUseClick}
              className="w-full px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded font-medium transition flex items-center justify-center gap-2"
            >
              <span>⚡</span>
              Kullan
            </button>
          )}

          {/* Equip */}
          {item.equip_slot !== "none" && !item.is_equipped && (
            <button
              onClick={onEquipClick}
              className="w-full px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded font-medium transition"
            >
              Kuşan
            </button>
          )}

          {/* Sell */}
          {item.is_tradeable && (
            <div className="space-y-1">
              <button
                onClick={onSellClick}
                disabled={isMarketLocked}
                className={cn(
                  "w-full px-4 py-2 text-white rounded font-medium transition",
                  isMarketLocked
                    ? "bg-amber-900/40 cursor-not-allowed opacity-70"
                    : "bg-amber-600 hover:bg-amber-700"
                )}
                title={isMarketLocked ? "Bu eşya pazarda satılamaz (Han-only)" : undefined}
              >
                Sat
              </button>
              {isMarketLocked && (
                <p className="text-[10px] text-[var(--color-warning)]">
                  Bu eşya pazarda satılamaz (Han-only)
                </p>
              )}
            </div>
          )}

          {/* Split Stack */}
          {item.quantity > 1 && item.is_stackable && (
            <button
              onClick={onSplitClick}
              className="w-full px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded font-medium transition flex items-center justify-center gap-2"
            >
              <span>✂️</span>
              Böl ({item.quantity})
            </button>
          )}

          {/* Favorite Toggle */}
          <button
            onClick={onFavoriteToggle}
            className={cn(
              "w-full px-4 py-2 rounded font-medium transition flex items-center justify-center gap-2",
              item.is_favorite
                ? "bg-yellow-600 hover:bg-yellow-700 text-white"
                : "bg-[var(--bg-darker)] hover:bg-[var(--bg-darker)]/80 text-[var(--text-muted)]"
            )}
          >
            <span>{item.is_favorite ? "⭐" : "☆"}</span>
            {item.is_favorite ? "Favorilerden Çıkar" : "Favori Ekle"}
          </button>

          {/* Trash */}
          <button
            onClick={onTrashClick}
            className="w-full px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded font-medium transition flex items-center justify-center gap-2"
          >
            <span>🗑️</span>
            Çöp
          </button>
        </div>
      </motion.div>
    </AnimatePresence>
  );
}
