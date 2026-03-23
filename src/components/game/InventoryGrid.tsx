// ============================================================
// InventoryGrid — 5×4 slot grid using dnd-kit sortable
// - Grid-friendly rectSortingStrategy
// - Properly attaches useSortable attributes/listeners
// - Smooth layout transitions via Framer Motion
// ============================================================

"use client";

import { memo, useMemo } from "react";
import { motion } from "framer-motion";
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
}: {
  item: InventoryItem | null;
  index: number;
  onItemClick: (item: InventoryItem) => void;
  isSelected: boolean;
}) {
  // If there's no item, render a fixed placeholder (non-sortable) so it doesn't shift
  if (!item) {
    const droppableId = `empty-${index}`;
    const { isOver, setNodeRef } = useDroppable({ id: droppableId });

    return (
      <div
        ref={setNodeRef as any}
        key={`empty-${index}`}
        className={`flex justify-center items-center select-none transition ${
          isOver ? "scale-[1.04]" : ""
        }`}
        aria-hidden
      >
        <EmptySlot index={index} enhancementStyle />
      </div>
    );
  }

  const id = item.row_id;
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id,
  });

  const style = {
    transform: isDragging ? CSS.Translate.toString(transform) : undefined,
    transition: isDragging ? transition : undefined,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={`flex justify-center items-center select-none -webkit-user-drag-none ${
        isDragging ? "opacity-50" : "opacity-100"
      }`}
      {...attributes}
      {...listeners}
    >
      <ItemCard
        item={item}
        onClick={() => onItemClick(item)}
        isSelected={isSelected}
        isDragging={isDragging}
        compact={false}
        enhancementStyle
      />
    </div>
  );
});

SortableSlot.displayName = "SortableSlot";

const MemoizedSortableSlot = memo(SortableSlot);

export function InventoryGrid({
  items,
  onItemClick,
  selectedItemId,
  activeItemId,
}: InventoryGridProps) {
  const slotIds = useMemo(() => {
    const slots: (InventoryItem | null)[] = Array(INVENTORY_CAPACITY).fill(null);
    items.forEach((it) => {
      if (it.is_equipped) return;
      if (it.slot_position >= 0 && it.slot_position < INVENTORY_CAPACITY) {
        slots[it.slot_position] = it;
      }
    });
    return slots.map((it, idx) => it?.row_id || `empty-${idx}`);
  }, [items]);

  const slots = useMemo(() => {
    const s: (InventoryItem | null)[] = Array(INVENTORY_CAPACITY).fill(null);
    items.forEach((it) => {
      if (it.is_equipped) return;
      if (it.slot_position >= 0 && it.slot_position < INVENTORY_CAPACITY) {
        s[it.slot_position] = it;
      }
    });
    return s;
  }, [items]);

  return (
    <SortableContext items={slotIds} strategy={rectSortingStrategy}>
      <motion.div
        className="p-0"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
      >
        <div className="grid grid-cols-5 gap-1.5 justify-start">
          {slots.map((it, idx) => (
            <MemoizedSortableSlot
              key={it?.row_id || `empty-${idx}`}
              item={it}
              index={idx}
              onItemClick={onItemClick}
              isSelected={selectedItemId === it?.row_id}
            />
          ))}
        </div>
      </motion.div>
    </SortableContext>
  );
}
