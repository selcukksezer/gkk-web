// ============================================================
// EquipmentSlot — Tek ekipman yuvası
// ============================================================

"use client";

import type { InventoryItem } from "@/types/inventory";
import { useDroppable } from "@dnd-kit/core";

const RARITY_BORDER: Record<string, string> = {
  common: "#6b7280",
  uncommon: "#22c55e",
  rare: "#3b82f6",
  epic: "#a855f7",
  legendary: "#f59e0b",
};

interface EquipmentSlotProps {
  label?: string;
  slotName?: string;
  item: InventoryItem | null;
  onClick?: () => void;
  onDragOver?: (e: React.DragEvent) => void;
  onDrop?: (e: React.DragEvent) => void;
  isDragOver?: boolean;
  compact?: boolean;
}

import { useDraggable } from "@dnd-kit/core";
import { ItemCard } from "./ItemCard";

export function EquipmentSlot({
  label,
  slotName,
  item,
  onClick,
  onDragOver,
  onDrop,
  isDragOver,
  compact,
}: EquipmentSlotProps) {
  const rarity = item?.rarity ?? "common";
  const borderColor = RARITY_BORDER[rarity] ?? RARITY_BORDER.common;
  const enhLvl = item?.enhancement_level ?? 0;
  const displayLabel = label ?? slotName ?? "?";

  const droppableId = `equip-${slotName}`;
  const { isOver, setNodeRef } = useDroppable({ id: droppableId });

  // Make the equipped item draggable (hook must be called unconditionally)
  const draggable = useDraggable({ id: item?.row_id ?? `equip-${slotName}`, disabled: !item });

  const dragAttributes = draggable.attributes;
  const dragListeners = draggable.listeners;
  const setDragNodeRef = draggable.setNodeRef;
  const transform = draggable.transform;
  const transition = draggable.transition;

  const style: any = transform
    ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)`, transition }
    : undefined;

  return (
    <div
      ref={setNodeRef as any}
      className={`relative rounded-xl ${compact ? "w-14 h-14" : "w-[76px] h-[76px]"} flex items-center justify-center`}
    >
      {item ? (
        <div ref={setDragNodeRef as any} style={style} {...(dragAttributes ?? {})} {...(dragListeners ?? {})}>
          <ItemCard
            item={item}
            isSelected={false}
            isEquipped={true}
            isDragging={false}
            compact={compact}
            onClick={onClick}
          />
        </div>
      ) : (
        <button
          onClick={onClick}
          className={`
            relative rounded-xl flex flex-col items-center justify-center transition-transform transform-gpu
            ${compact ? "w-14 h-14" : "w-[76px] h-[76px]"}
            backdrop-blur-sm bg-[var(--bg-card)]/55 border
            hover:scale-105 active:scale-98
          `}
          style={{
            borderColor: "var(--border)",
          }}
        >
          <span className={`text-center leading-tight text-[var(--text-secondary)] ${compact ? "text-[8px]" : "text-[10px]"}`}>
            {displayLabel}
          </span>
        </button>
      )}
    </div>
  );
}
