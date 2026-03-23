// ============================================================
// EquipmentGrid — Grid of 8 equipment slots + trash slot
// ============================================================

"use client";

import { motion } from "framer-motion";
import { useDroppable } from "@dnd-kit/core";
import { EquipmentSlot } from "./EquipmentSlot";
import type { InventoryItem } from "@/types/inventory";
import { cn } from "@/lib/utils/cn";

interface EquipmentGridProps {
  equippedItems: Record<string, InventoryItem | null>;
  onTrashDrop?: (e: React.DragEvent) => void;
  onTrashDragOver?: (e: React.DragEvent) => void;
  onTrashDragLeave?: (e: React.DragEvent) => void;
  dragOverTrash?: boolean;
}

const equipmentSlots = [
  "weapon",
  "head",
  "chest",
  "gloves",
  "legs",
  "boots",
  "ring",
  "necklace",
];

export function EquipmentGrid({
  equippedItems,
  onTrashDrop,
  onTrashDragOver,
  onTrashDragLeave,
  dragOverTrash,
}: EquipmentGridProps) {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-black uppercase tracking-[0.16em] text-[var(--text-muted)]">Ekipman</h3>
        <span className="text-[10px] text-[var(--text-muted)]">8 Slot</span>
      </div>

      {/* Equipment slots grid */}
      <div className="grid grid-cols-4 gap-2.5 rounded-2xl border border-white/10 bg-black/20 p-3">
        {equipmentSlots.map((slot) => (
          <EquipmentSlot
            key={slot}
            slotName={slot}
            item={equippedItems[slot] ?? null}
          />
        ))}
      </div>

      {/* Trash slot (dnd-kit droppable) */}
      <TrashSlot isOverProp={dragOverTrash} />
    </div>
  );
}

function TrashSlot({ isOverProp }: { isOverProp?: boolean }) {
  const { isOver, setNodeRef } = useDroppable({ id: "trash" });

  return (
    <motion.div
      ref={setNodeRef as any}
      className={cn(
        "h-16 rounded-xl border border-dashed flex items-center justify-center gap-2 cursor-pointer transition",
        isOver || isOverProp
          ? "border-red-500 bg-red-500/20 shadow-lg shadow-red-500/30"
          : "border-red-500/50 bg-red-500/10 hover:bg-red-500/15"
      )}
    >
      <span className="text-2xl">🗑️</span>
      <div>
        <p className="text-xs font-bold uppercase tracking-wider text-red-300">Çöp Alanı</p>
        <p className="text-[10px] text-red-400">Silmek için buraya bırak</p>
      </div>
    </motion.div>
  );
}
