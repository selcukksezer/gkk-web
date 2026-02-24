// ============================================================
// InventoryGrid — 5×4 slot grid using dnd-kit sortable
// - Grid-friendly rectSortingStrategy
// - Properly attaches useSortable attributes/listeners
// - Smooth layout transitions via Framer Motion
// ============================================================

"use client";

import { memo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  SortableContext,
  useSortable,
  rectSortingStrategy,
} from "@dnd-kit/sortable";
import { useDroppable } from "@dnd-kit/core";
import { CSS } from "@dnd-kit/utilities";
import { ItemCard, EmptySlot } from "@/components/game/ItemCard";
import { INVENTORY_CAPACITY } from "@/types/inventory";
import type { InventoryItem } from "@/types/inventory";

interface InventoryGridProps {
  items: InventoryItem[];
  onItemClick: (item: InventoryItem) => void;
  selectedItemId?: string | null;
  activeItemId?: string | null;
}

const SortableSlot = memo(function SortableSlot({
  item,
  index,
  onItemClick,
  isSelected,
  isActive,
}: {
  item: InventoryItem | null;
  index: number;
  onItemClick: (item: InventoryItem) => void;
  isSelected: boolean;
  isActive: boolean;
}) {
  // If there's no item, render a fixed placeholder (non-sortable) so it doesn't shift
  if (!item) {
    const droppableId = `empty-${index}`;
    const { isOver, setNodeRef } = useDroppable({ id: droppableId });

    return (
      <div
        ref={setNodeRef as any}
        key={`empty-${index}`}
        className={`flex justify-center items-center select-none inventory-slot w-18 h-18 transition ${
          isOver ? "scale-105" : ""
        }`}
        aria-hidden
      >
        <EmptySlot index={index} />
      </div>
    );
  }

  const id = item.row_id;
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id,
  });

  const style = {
    transform: CSS.Translate.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <motion.div
      ref={setNodeRef}
      style={style as any}
      layout
      layoutId={id}
      initial={false}
      animate={{ opacity: isDragging ? 0.5 : 1 }}
      transition={{ type: "spring", stiffness: 300, damping: 30 }}
      className="flex justify-center items-center select-none -webkit-user-drag-none inventory-slot"
      {...attributes}
      {...listeners}
    >
      <ItemCard
        item={item}
        onClick={() => onItemClick(item)}
        isSelected={isSelected}
        isDragging={isActive || isDragging}
        compact={false}
      />
    </motion.div>
  );
});

SortableSlot.displayName = "SortableSlot";

export function InventoryGrid({
  items,
  onItemClick,
  selectedItemId,
  activeItemId,
}: InventoryGridProps) {
  const slots: (InventoryItem | null)[] = Array(INVENTORY_CAPACITY).fill(null);
  // Place only non-equipped items into the grid slots; equipped items are shown in EquipmentGrid
  items.forEach((it) => {
    if (it.is_equipped) return;
    if (it.slot_position >= 0 && it.slot_position < INVENTORY_CAPACITY) slots[it.slot_position] = it;
  });

  const slotIds = slots.map((it, idx) => it?.row_id || `empty-${idx}`);

  return (
    <SortableContext items={slotIds} strategy={rectSortingStrategy}>
      <motion.div
        className="p-4 rounded-2xl backdrop-blur-md bg-[var(--bg-card)]/60 border border-[var(--border-subtle)]"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
      >
        <div className="mb-3 flex items-center justify-between">
          <h4 className="text-sm font-semibold text-[var(--text-muted)]">Envanter</h4>
          <div className="text-xs text-[var(--text-muted)]">Oyun Stili - 5×4</div>
        </div>

        <div className="grid grid-cols-5 gap-3 p-2">
          <AnimatePresence mode="sync">
            {slots.map((it, idx) => (
              <SortableSlot
                key={it?.row_id || `empty-${idx}`}
                item={it}
                index={idx}
                onItemClick={onItemClick}
                isSelected={selectedItemId === it?.row_id}
                isActive={activeItemId === it?.row_id}
              />
            ))}
          </AnimatePresence>
        </div>
      </motion.div>
    </SortableContext>
  );
}
