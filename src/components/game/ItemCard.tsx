// ============================================================
// ItemCard — Envanter ızgara elemanı
// Rarity glow, stack badge, equipped indicator, long-press menu
// ============================================================

"use client";

import { motion } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";
import { getRarityColor } from "@/types/item";
import { cn } from "@/lib/utils/cn";
import { ItemIcon } from "./ItemIcon";

interface ItemCardProps {
  item: InventoryItem;
  isSelected?: boolean;
  isEquipped?: boolean;
  isDragging?: boolean;
  compact?: boolean;
  enhancementStyle?: boolean;
  onClick?: () => void;
  onDoubleClick?: () => void;
}

export function ItemCard({
  item,
  isSelected,
  isEquipped,
  isDragging,
  compact,
  enhancementStyle,
  onClick,
  onDoubleClick,
}: ItemCardProps) {
  const rarityColor = getRarityColor(item.rarity);
  const isScroll = item.item_type === "scroll" || item.item_id?.includes("scroll");
  const isRune = item.item_type === "rune" || item.item_id?.startsWith("rune_");
  const baseToneClass = isScroll
    ? "border-amber-400/40 bg-amber-900/20 hover:border-amber-400"
    : isRune
      ? "border-purple-400/40 bg-purple-900/20 hover:border-purple-400"
      : "border-[var(--border-default)] bg-[var(--bg-elevated)] hover:border-[var(--accent)]/50";

  return (
    <motion.button
      initial={false}
      animate={{
        scale: isDragging ? 1.05 : 1,
      }}
      transition={{ duration: 0.1 }}
      whileHover={{ scale: isDragging ? 1.05 : enhancementStyle ? 1.04 : 1.08 }}
      whileTap={{ scale: 0.95 }}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      className={cn(
        enhancementStyle
          ? "relative flex items-center justify-center rounded-lg border transition-all cursor-grab active:cursor-grabbing overflow-hidden"
          : "relative flex flex-col items-center justify-center rounded-xl border backdrop-blur-sm transition-all cursor-grab active:cursor-grabbing",
        compact ? "w-14 h-14" : enhancementStyle ? "w-[88px] h-[88px]" : "w-16 h-16",
        isSelected
          ? "border-[var(--accent)] bg-[var(--accent)]/20"
          : enhancementStyle
            ? baseToneClass
            : "border-white/15 bg-black/25",
        isEquipped && "ring-2 ring-[var(--color-success)]"
      )}
      style={{
        borderColor: isSelected ? "var(--accent)" : enhancementStyle ? `${rarityColor}40` : rarityColor,
        boxShadow: isDragging
          ? `0 20px 50px ${rarityColor}45, inset 0 0 18px ${rarityColor}22`
          : enhancementStyle
            ? undefined
            : `0 8px 20px rgba(0,0,0,0.32), inset 0 0 12px rgba(255,255,255,0.03)`,
        backgroundImage: enhancementStyle ? undefined : isSelected ? `linear-gradient(135deg, ${rarityColor}15, transparent)` : undefined,
      }}
      title={item.enhancement_level > 0 ? `${item.name} (+${item.enhancement_level})` : item.name}
    >
      <ItemIcon
        icon={item.icon}
        itemType={item.item_type}
        itemId={item.item_id}
        className={cn(
          compact
            ? "w-8 h-8 object-contain"
            : enhancementStyle
              ? "text-2xl leading-none"
              : "w-16 h-16 leading-none object-contain"
        )}
        alt={item.name}
        enhancementLevel={item.enhancement_level}
      />

      {/* Enhancement badge handled by ItemIcon */}

      {/* Stack quantity */}
      {item.quantity > 1 && (
        <span className={cn(
          "absolute bottom-0.5 right-0.5",
          enhancementStyle
            ? "text-[7px] bg-[var(--bg-card)] rounded px-0.5 text-[var(--text-muted)] leading-none"
            : "text-[9px] font-bold bg-black/70 text-white px-1 rounded"
        )}>
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
        className={cn(
          "absolute w-1.5 h-1.5 rounded-full",
          enhancementStyle ? "top-0.5 left-0.5" : "-bottom-0.5 left-1/2 -translate-x-1/2"
        )}
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
  enhancementStyle,
  onClick,
}: {
  index: number;
  compact?: boolean;
  enhancementStyle?: boolean;
  onClick?: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        enhancementStyle
          ? "rounded-lg border border-dashed border-[var(--border-default)] bg-[var(--bg-input)] opacity-40 flex items-center justify-center transition cursor-default"
          : "rounded-xl border border-dashed border-white/15 bg-black/20 flex items-center justify-center transition hover:bg-black/30",
        compact ? "w-14 h-14" : enhancementStyle ? "w-[88px] h-[88px]" : "w-16 h-16"
      )}
    >
      <span className="text-[10px] text-[var(--text-muted)]">{index + 1}</span>
    </button>
  );
}
