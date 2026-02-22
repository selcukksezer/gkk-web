// ============================================================
// EquipmentSlot — Tek ekipman yuvası
// ============================================================

"use client";

import type { InventoryItem } from "@/types/inventory";

const RARITY_BORDER: Record<string, string> = {
  common: "#6b7280",
  uncommon: "#22c55e",
  rare: "#3b82f6",
  epic: "#a855f7",
  legendary: "#f59e0b",
};

interface EquipmentSlotProps {
  label: string;
  item: InventoryItem | null;
  onClick: () => void;
}

export function EquipmentSlot({ label, item, onClick }: EquipmentSlotProps) {
  const rarity = item?.rarity ?? "common";
  const borderColor = RARITY_BORDER[rarity] ?? RARITY_BORDER.common;
  const enhLvl = item?.enhancement_level ?? 0;

  return (
    <button
      onClick={onClick}
      className="relative w-[72px] h-[72px] rounded-lg flex flex-col items-center justify-center bg-[var(--surface)] hover:bg-[var(--surface-hover)] transition-colors"
      style={{ border: `2px solid ${item ? borderColor : "var(--border)"}` }}
    >
      {item ? (
        <>
          <span className="text-2xl">{item.icon ?? "🛡️"}</span>
          {enhLvl > 0 && (
            <span className="absolute top-0.5 right-1 text-[10px] text-[var(--gold)] font-bold">
              +{enhLvl}
            </span>
          )}
        </>
      ) : (
        <span className="text-[10px] text-[var(--text-secondary)] text-center leading-tight">
          {label}
        </span>
      )}
    </button>
  );
}
