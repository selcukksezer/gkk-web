// ============================================================
// EquipmentSlot — Tek ekipman yuvası
// ============================================================

"use client";

import type { InventoryItem } from "@/types/inventory";
import { useDroppable } from "@dnd-kit/core";

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
  const displayLabel = label ?? slotName ?? "?";

  const droppableId = `equip-${slotName}`;
  const { isOver, setNodeRef } = useDroppable({ id: droppableId });

  // Make the equipped item draggable (hook must be called unconditionally)
  const draggable = useDraggable({ id: item?.row_id ?? `equip-${slotName}`, disabled: !item });

  const dragAttributes = draggable.attributes;
  const dragListeners = draggable.listeners;
  const setDragNodeRef = draggable.setNodeRef;
  const transform = draggable.transform;
  // transition may not be present on the Draggable API typings in this dnd-kit version
  const transition = (draggable as any).transition;

  const style: any = transform
    ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)`, transition }
    : undefined;

  return (
    <div
      ref={setNodeRef as any}
      className={`relative rounded-lg ${compact ? "w-14 h-14" : "w-[88px] h-[88px]"} flex items-center justify-center ${isOver ? "scale-[1.03]" : ""}`}
    >
      {item ? (
        <div ref={setDragNodeRef as any} style={style} {...(dragAttributes ?? {})} {...(dragListeners ?? {})}>
          <ItemCard
            item={item}
            isSelected={false}
            isEquipped={true}
            isDragging={false}
            compact={compact}
            enhancementStyle
            onClick={onClick}
          />
        </div>
      ) : (
        <button
          onClick={onClick}
          className={`
            relative rounded-lg flex flex-col items-center justify-center transition-transform transform-gpu
            ${compact ? "w-14 h-14" : "w-[88px] h-[88px]"}
            backdrop-blur-sm border border-white/15 bg-black/20
            hover:scale-105 hover:bg-black/30 active:scale-98
          `}
        >
          <span className={`text-center leading-tight text-[var(--text-secondary)] ${compact ? "text-[8px]" : "text-[10px]"}`}>
            {displayLabel}
          </span>
        </button>
      )}
    </div>
  );
}
