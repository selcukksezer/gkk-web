// ============================================================
// ItemCard — Envanter ızgara elemanı
// Rarity glow, stack badge, equipped indicator, long-press menu
// ============================================================

"use client";

import { motion } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";
import { getRarityColor, getRarityLabel } from "@/types/item";
import { cn } from "@/lib/utils/cn";

interface ItemCardProps {
  item: InventoryItem;
  isSelected?: boolean;
  isEquipped?: boolean;
  compact?: boolean;
  onClick?: () => void;
  onDoubleClick?: () => void;
}

const typeEmoji: Record<string, string> = {
  weapon: "⚔️",
  armor: "🛡️",
  accessory: "💍",
  consumable: "🧪",
  material: "🪨",
  potion: "🧪",
  scroll: "📜",
  key_item: "🔑",
  quest_item: "📋",
  recipe: "📖",
};

export function ItemCard({
  item,
  isSelected,
  isEquipped,
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
      whileTap={{ scale: 0.93 }}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      className={cn(
        "relative flex flex-col items-center justify-center rounded-lg border transition-all",
        compact ? "w-14 h-14" : "w-16 h-16",
        isSelected
          ? "border-[var(--accent)] bg-[var(--accent)]/15"
          : "border-[var(--border-default)] bg-[var(--bg-card)]",
        isEquipped && "ring-2 ring-[var(--color-success)]",
        rarityGlowClass
      )}
      style={{
        borderColor: isSelected ? "var(--accent)" : rarityColor,
      }}
    >
      {/* Type emoji */}
      <span className={cn("leading-none", compact ? "text-lg" : "text-xl")}>
        {typeEmoji[item.item_type] || "❓"}
      </span>

      {/* Enhancement level */}
      {item.enhancement_level > 0 && (
        <span className="absolute top-0.5 right-0.5 text-[9px] font-bold text-[var(--accent-light)]">
          +{item.enhancement_level}
        </span>
      )}

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
