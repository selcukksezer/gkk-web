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

  return (
    <button
      ref={setNodeRef as any}
      onClick={onClick}
      className={`
        relative rounded-xl flex flex-col items-center justify-center transition-transform transform-gpu
        ${compact ? "w-14 h-14" : "w-[76px] h-[76px]"}
        backdrop-blur-sm bg-[var(--bg-card)]/55 border
        hover:scale-105 active:scale-98
      `}
      style={{
        borderColor: item ? borderColor : "var(--border)",
        boxShadow: item ? `0 10px 30px ${borderColor}22, inset 0 0 12px ${borderColor}10` : undefined,
      }}
    >
      {item ? (
        <>
          <span className={compact ? "text-lg" : "text-2xl"}>
            {item.icon ?? "🛡️"}
          </span>
          {enhLvl > 0 && (
            <span className="absolute top-0.5 right-1 text-[10px] text-[var(--gold)] font-bold">
              +{enhLvl}
            </span>
          )}
        </>
      ) : (
        <span className={`text-center leading-tight text-[var(--text-secondary)] ${compact ? "text-[8px]" : "text-[10px]"}`}>
          {displayLabel}
        </span>
      )}
    </button>
  );
}
