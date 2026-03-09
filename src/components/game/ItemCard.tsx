// ============================================================
// ItemCard — Envanter ızgara elemanı
// Rarity glow, stack badge, equipped indicator, long-press menu
// ============================================================

"use client";

import { motion } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";
import { getRarityColor, getRarityLabel } from "@/types/item";
import { cn } from "@/lib/utils/cn";
import { ItemIcon } from "./ItemIcon";

interface ItemCardProps {
  item: InventoryItem;
  isSelected?: boolean;
  isEquipped?: boolean;
  isDragging?: boolean;
  compact?: boolean;
  onClick?: () => void;
  onDoubleClick?: () => void;
}

export function ItemCard({
  item,
  isSelected,
  isEquipped,
  isDragging,
  compact,
  onClick,
  onDoubleClick,
}: ItemCardProps) {
  const rarityColor = getRarityColor(item.rarity);
  const rarityGlowClass =
    item.rarity === "legendary"
      ? "rarity-legendary"
      : item.rarity === "epic"
      ? "rarity-epic"
      : item.rarity === "mythic"
      ? "rarity-mythic"
      : "";

  return (
    <motion.button
      initial={false}
      animate={{
        scale: isDragging ? 1.05 : 1,
      }}
      transition={{ duration: 0.1 }}
      whileHover={{ scale: isDragging ? 1.05 : 1.08 }}
      whileTap={{ scale: 0.95 }}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      className={cn(
        "relative flex flex-col items-center justify-center rounded-xl border backdrop-blur-sm transition-all cursor-grab active:cursor-grabbing",
        compact ? "w-14 h-14" : "w-18 h-18",
        isSelected
          ? "border-[var(--accent)] bg-[var(--accent)]/15"
          : "border-[var(--border-default)] bg-[var(--bg-card)]/50",
        isEquipped && "ring-2 ring-[var(--color-success)]"
      )}
      style={{
        borderColor: isSelected ? "var(--accent)" : rarityColor,
        boxShadow: isDragging
          ? `0 20px 50px ${rarityColor}40, inset 0 0 18px ${rarityColor}20`
          : `0 6px 18px rgba(0,0,0,0.35)`,
        backgroundImage: isSelected ? `linear-gradient(135deg, ${rarityColor}15, transparent)` : undefined,
      }}
    >
      <ItemIcon
        icon={item.icon}
        itemType={item.item_type}
        itemId={item.item_id}
        className={cn("leading-none object-contain", compact ? "w-7 h-7" : "w-8 h-8")}
        alt={item.name}
      />

      {/* Enhancement badge handled by ItemIcon */}

      {/* Stack quantity */}
      {item.quantity > 1 && (
        <span className="absolute bottom-0.5 right-0.5 text-[9px] font-bold bg-black/60 text-white px-1 rounded">
          {item.quantity}
        </span>
      )}

      {/* Equipped badge */}
      {isEquipped && (
        <span className="absolute top-0.5 left-0.5 text-[9px]">✅</span>
      )}
      
      {/* Han-only badge */}
      {item.is_han_only && (
        <span className="absolute top-0.5 right-0.5 text-[9px] bg-amber-500/90 px-1.5 rounded text-white font-bold">
          HAN
        </span>
      )}

      {/* Rarity dot */}
      <span
        className="absolute -bottom-0.5 left-1/2 -translate-x-1/2 w-1.5 h-1.5 rounded-full"
        style={{ backgroundColor: rarityColor }}
      />
    </motion.button>
  );
}

// ============================================================
// Empty Slot
// ============================================================

export function EmptySlot({
  index,
  compact,
  onClick,
}: {
  index: number;
  compact?: boolean;
  onClick?: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "rounded-lg border border-dashed border-[var(--border-subtle)] bg-[var(--bg-darker)]/50 flex items-center justify-center",
        compact ? "w-14 h-14" : "w-16 h-16"
      )}
    >
      <span className="text-[10px] text-[var(--text-muted)]">{index + 1}</span>
    </button>
  );
}
