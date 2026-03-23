// ============================================================
// InventoryDetailPanel — Item detail sidebar
// Displays selected item info: stats, description, action buttons
// ============================================================

"use client";

import { motion, AnimatePresence } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";
import { getRarityLabel, getDisplayName } from "@/types/item";
import { cn } from "@/lib/utils/cn";
import { ItemIcon } from "./ItemIcon";

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
  const typeLabel = item.item_type ? item.item_type.toUpperCase() : "ITEM";

  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={item.row_id}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 flex items-center justify-center bg-black/65 p-4"
      >
        <motion.div
          initial={{ opacity: 0, y: 24, scale: 0.96 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 14, scale: 0.96 }}
          className="max-h-[90vh] w-full max-w-lg overflow-auto rounded-3xl border border-white/10 bg-[linear-gradient(160deg,rgba(22,29,40,0.97),rgba(10,14,22,0.97))] p-5 shadow-[0_24px_60px_rgba(0,0,0,0.45)]"
        >
        <div className="flex items-start justify-between gap-3 border-b border-white/10 pb-4">
          <div className="flex items-center gap-3">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl border border-white/15 bg-black/25">
              <ItemIcon
                icon={item.icon}
                itemType={item.item_type}
                itemId={item.item_id}
                className="h-8 w-8"
                alt={item.name}
              />
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-[0.18em] text-[var(--text-muted)]">{typeLabel}</p>
              <h2 className={cn("max-w-[180px] truncate text-lg font-black", rarityClass)}>{displayName}</h2>
              <p className={cn("text-xs font-semibold", rarityClass)}>{rarityLabel}</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="rounded-xl border border-white/10 px-2 py-1 text-xs text-[var(--text-muted)] transition hover:border-white/20 hover:text-white"
          >
            Kapat
          </button>
        </div>

        <div className="mt-4 space-y-4 text-sm">
          <div className="grid grid-cols-2 gap-2">
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted)]">Tip</p>
              <p className="mt-1 font-semibold text-white capitalize">{item.item_type}</p>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted)]">Miktar</p>
              <p className="mt-1 font-semibold text-white">{item.quantity}</p>
            </div>
          </div>

          {item.description && (
            <div className="rounded-xl border border-white/10 bg-black/20 p-3">
              <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted)]">Açıklama</p>
              <p className="mt-1 text-sm text-[var(--text-default)]">
                {item.description}
              </p>
            </div>
          )}

          {(item.attack > 0 || item.defense > 0 || item.health > 0 || item.power > 0) && (
            <div className="rounded-xl border border-white/10 bg-black/20 p-3">
              <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted)]">Savaş İstatistikleri</p>
              <div className="mt-2 space-y-1">
              {item.attack > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Saldırı</span>
                  <span className="text-red-400">+{item.attack}</span>
                </div>
              )}
              {item.defense > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Savunma</span>
                  <span className="text-blue-400">+{item.defense}</span>
                </div>
              )}
              {item.health > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Can</span>
                  <span className="text-green-400">+{item.health}</span>
                </div>
              )}
              {item.power > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Güç</span>
                  <span className="text-purple-400">+{item.power}</span>
                </div>
              )}
              </div>
            </div>
          )}

          {item.enhancement_level > 0 && item.can_enhance && (
            <div className="rounded-xl border border-white/10 bg-black/20 p-3 space-y-1">
              <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted)]">Geliştirme</p>
              <div className="flex justify-between">
                <span className="text-[var(--text-muted)]">Seviye</span>
                <span className="text-yellow-400 font-bold">+{item.enhancement_level}</span>
              </div>
              {item.max_enhancement && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Maks</span>
                  <span className="text-[var(--text-default)]">+{item.max_enhancement}</span>
                </div>
              )}
            </div>
          )}

          {item.equip_slot !== "none" && (
            <div className="rounded-xl border border-white/10 bg-black/20 p-3 space-y-1">
              <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted)]">Gereksinimler</p>
              {item.required_level > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Seviye</span>
                  <span className="text-white">{item.required_level}</span>
                </div>
              )}
            </div>
          )}

          {item.item_type === "potion" && (
            <div className="rounded-xl border border-white/10 bg-black/20 p-3 space-y-1">
              <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted)]">İksir Etkileri</p>
              {item.health_restore > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Can</span>
                  <span className="text-green-400">+{item.health_restore}</span>
                </div>
              )}
              {item.energy_restore > 0 && (
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Enerji</span>
                  <span className="text-yellow-400">+{item.energy_restore}</span>
                </div>
              )}
            </div>
          )}

          <div className="rounded-xl border border-white/10 bg-black/20 p-3 space-y-1 text-sm">
            <p className="text-[10px] uppercase tracking-wide text-[var(--text-muted)]">Ekonomi</p>
            {item.base_price > 0 && (
              <div className="flex justify-between">
                <span className="text-[var(--text-muted)]">Fiyat</span>
                <span className="text-yellow-400">{item.base_price} ⚔</span>
              </div>
            )}
            {item.vendor_sell_price > 0 && (
              <div className="flex justify-between">
                <span className="text-[var(--text-muted)]">Satış</span>
                <span className="text-green-400">{item.vendor_sell_price} ⚔</span>
              </div>
            )}
          </div>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-2">
          {(item.item_type === "potion" || item.item_type === "consumable") && (
            <button
              onClick={onUseClick}
              className="col-span-2 rounded-xl bg-emerald-600 px-4 py-2 font-semibold text-white transition hover:bg-emerald-700"
            >
              Kullan
            </button>
          )}

          {item.equip_slot !== "none" && !item.is_equipped && (
            <button
              onClick={onEquipClick}
              className="col-span-2 rounded-xl bg-blue-600 px-4 py-2 font-semibold text-white transition hover:bg-blue-700"
            >
              Kuşan
            </button>
          )}

          {item.is_tradeable && (
            <div className="col-span-2 space-y-1">
              <button
                onClick={onSellClick}
                disabled={isMarketLocked}
                className={cn(
                  "w-full rounded-xl px-4 py-2 font-semibold text-white transition",
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

          {item.quantity > 1 && item.is_stackable && (
            <button
              onClick={onSplitClick}
              className="col-span-2 rounded-xl bg-fuchsia-700 px-4 py-2 font-semibold text-white transition hover:bg-fuchsia-800"
            >
              Böl ({item.quantity})
            </button>
          )}

          <button
            onClick={onFavoriteToggle}
            className={cn(
              "rounded-xl px-4 py-2 font-semibold transition",
              item.is_favorite
                ? "bg-yellow-600 text-white hover:bg-yellow-700"
                : "bg-[var(--bg-darker)] text-[var(--text-muted)] hover:bg-[var(--bg-darker)]/80"
            )}
          >
            {item.is_favorite ? "Favoriden Çıkar" : "Favoriye Ekle"}
          </button>

          <button
            onClick={onTrashClick}
            className="rounded-xl bg-red-600 px-4 py-2 font-semibold text-white transition hover:bg-red-700"
          >
            Çöp
          </button>
        </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}
