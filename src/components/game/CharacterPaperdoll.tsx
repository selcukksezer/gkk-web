// ============================================================
// CharacterPaperdoll — Karakter ekipman görseli (8 slot düzeni)
// ============================================================

"use client";

import { EquipmentSlot } from "./EquipmentSlot";
import type { InventoryItem } from "@/types/inventory";

export type SlotType =
  | "head"
  | "chest"
  | "legs"
  | "feet"
  | "main_hand"
  | "off_hand"
  | "ring"
  | "necklace";

const SLOT_LAYOUT: { slot: SlotType; label: string; gridArea: string }[] = [
  { slot: "head", label: "Kask", gridArea: "1 / 2 / 2 / 3" },
  { slot: "necklace", label: "Kolye", gridArea: "1 / 3 / 2 / 4" },
  { slot: "chest", label: "Zırh", gridArea: "2 / 2 / 3 / 3" },
  { slot: "main_hand", label: "Ana El", gridArea: "2 / 1 / 3 / 2" },
  { slot: "off_hand", label: "Yardım El", gridArea: "2 / 3 / 3 / 4" },
  { slot: "ring", label: "Yüzük", gridArea: "3 / 1 / 4 / 2" },
  { slot: "legs", label: "Pantolon", gridArea: "3 / 2 / 4 / 3" },
  { slot: "feet", label: "Ayak", gridArea: "4 / 2 / 5 / 3" },
];

interface CharacterPaperdollProps {
  equipped: Partial<Record<SlotType, InventoryItem | null>>;
  onSlotClick: (slot: SlotType, item: InventoryItem | null) => void;
}

export function CharacterPaperdoll({ equipped, onSlotClick }: CharacterPaperdollProps) {
  return (
    <div
      className="grid gap-2 mx-auto"
      style={{
        gridTemplateColumns: "repeat(3, 72px)",
        gridTemplateRows: "repeat(4, 72px)",
        justifyContent: "center",
      }}
    >
      {SLOT_LAYOUT.map(({ slot, label, gridArea }) => {
        const item = equipped[slot] ?? null;
        return (
          <div key={slot} style={{ gridArea }}>
            <EquipmentSlot
              label={label}
              item={item}
              onClick={() => onSlotClick(slot, item)}
            />
          </div>
        );
      })}
    </div>
  );
}
