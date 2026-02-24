// ============================================================
// ItemSlot — Single inventory slot with rarity border
// ============================================================

"use client";

import { motion } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";
import type { Rarity } from "@/types/item";
import { getRarityColor, getDisplayName } from "@/types/item";
import { ItemIcon } from "./ItemIcon";

interface ItemSlotProps {
  item: InventoryItem | null;
  onClick?: () => void;
  size?: "sm" | "md" | "lg";
  showQuantity?: boolean;
}

const SIZE_MAP = { sm: "w-12 h-12", md: "w-16 h-16", lg: "w-20 h-20" };

export function ItemSlot({ item, onClick, size = "md", showQuantity = true }: ItemSlotProps) {
  if (!item) {
    return (
      <div
        className={`${SIZE_MAP[size]} rounded-lg border border-dashed border-[var(--border)] bg-[var(--surface)] flex items-center justify-center`}
      >
        <span className="text-[var(--text-secondary)] text-xs">+</span>
      </div>
    );
  }

  const rarityColor = getRarityColor(item.rarity as Rarity);

  return (
    <motion.button
      whileTap={{ scale: 0.95 }}
      className={`${SIZE_MAP[size]} rounded-lg border-2 bg-[var(--card-bg)] flex items-center justify-center relative cursor-pointer`}
      style={{ borderColor: rarityColor }}
      onClick={onClick}
      title={getDisplayName(item)}
    >
      <ItemIcon
        icon={item.icon}
        itemType={item.item_type}
        itemId={item.item_id}
        className="w-7 h-7 object-contain"
        alt={item.name}
      />
      {showQuantity && (item.quantity ?? 1) > 1 && (
        <span className="absolute bottom-0 right-0 text-[10px] bg-black/70 text-white px-1 rounded-tl">
          {item.quantity}
        </span>
      )}
      {(item.enhancement_level ?? 0) > 0 && (
        <span className="absolute top-0 right-0 text-[10px] text-[var(--gold)] font-bold">
          +{item.enhancement_level}
        </span>
      )}
    </motion.button>
  );
}
