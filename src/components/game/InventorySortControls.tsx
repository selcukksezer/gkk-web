// ============================================================
// InventorySortControls — Sorting options for inventory
// ============================================================

"use client";

import { motion } from "framer-motion";
import { cn } from "@/lib/utils/cn";

export type SortType = "name" | "type" | "rarity" | "level";

interface InventorySortControlsProps {
  sortBy: SortType;
  isAscending: boolean;
  onSortChange: (sortType: SortType) => void;
  onToggleOrder: () => void;
}

export function InventorySortControls({
  sortBy,
  isAscending,
  onSortChange,
  onToggleOrder,
}: InventorySortControlsProps) {
  const sortOptions: Array<{ id: SortType; label: string }> = [
    { id: "name", label: "Ad" },
    { id: "type", label: "Tip" },
    { id: "rarity", label: "Nadirlik" },
    { id: "level", label: "Seviye" },
  ];

  return (
    <div className="flex gap-2 p-4 bg-[var(--bg-darker)] rounded-lg border border-[var(--border-subtle)] items-center flex-wrap">
      <span className="text-sm text-[var(--text-muted)]">Sırala:</span>
      
      <div className="flex gap-1">
        {sortOptions.map((option) => (
          <motion.button
            key={option.id}
            whileTap={{ scale: 0.95 }}
            onClick={() => onSortChange(option.id)}
            className={cn(
              "px-3 py-2 rounded-lg font-medium text-sm transition",
              sortBy === option.id
                ? "bg-[var(--accent)] text-white"
                : "bg-[var(--bg-card)] text-[var(--text-muted)] hover:bg-[var(--bg-card)]/80"
            )}
          >
            {option.label}
          </motion.button>
        ))}
      </div>

      {/* Toggle ascending/descending */}
      <motion.button
        whileTap={{ scale: 0.95 }}
        onClick={onToggleOrder}
        className="ml-auto px-3 py-2 rounded-lg bg-[var(--bg-card)] text-[var(--text-muted)] hover:bg-[var(--bg-card)]/80 transition flex items-center gap-1"
        title={isAscending ? "Azalan sıraya geçmek için tıklayın" : "Artan sıraya geçmek için tıklayın"}
      >
        {isAscending ? (
          <>
            <span>↑</span>
            <span className="text-xs">A→Z</span>
          </>
        ) : (
          <>
            <span>↓</span>
            <span className="text-xs">Z→A</span>
          </>
        )}
      </motion.button>
    </div>
  );
}
