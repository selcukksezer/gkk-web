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
      <h3 className="text-lg font-bold text-white">Kuşanılmış Ekipmanlar</h3>

      {/* Equipment slots grid */}
      <div className="grid grid-cols-4 gap-3">
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
        "h-20 rounded-lg border-2 border-dashed flex items-center justify-center gap-3 cursor-pointer transition",
        isOver || isOverProp
          ? "border-red-500 bg-red-500/20 shadow-lg shadow-red-500/30"
          : "border-red-500/50 bg-red-500/5 hover:bg-red-500/10"
      )}
    >
      <span className="text-3xl">🗑️</span>
      <div>
        <p className="text-sm font-bold text-red-500">Çöp</p>
        <p className="text-xs text-red-400">Silmek için bırak</p>
      </div>
    </motion.div>
  );
}
