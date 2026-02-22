// ============================================================
// InventoryGrid — 5×4 slot grid for inventory display
// ============================================================

"use client";

import { motion } from "framer-motion";
import { ItemCard, EmptySlot } from "@/components/game/ItemCard";
import { INVENTORY_CAPACITY } from "@/types/inventory";
import type { InventoryItem } from "@/types/inventory";

interface InventoryGridProps {
  items: InventoryItem[];
  onItemClick: (item: InventoryItem) => void;
  selectedItemId?: string | null;
}

export function InventoryGrid({ items, onItemClick, selectedItemId }: InventoryGridProps) {
  const slots = Array.from({ length: INVENTORY_CAPACITY }, (_, i) => items[i] ?? null);

  return (
    <motion.div
      className="grid grid-cols-5 gap-2"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    >
      {slots.map((item, idx) =>
        item ? (
          <ItemCard
            key={item.row_id ?? item.item_id}
            item={item}
            onClick={() => onItemClick(item)}
            isSelected={selectedItemId === item.item_id}
          />
        ) : (
          <EmptySlot key={`empty-${idx}`} index={idx} />
        )
      )}
    </motion.div>
  );
}
