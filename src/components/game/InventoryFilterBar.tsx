// ============================================================
// InventoryFilterBar — Filter buttons for inventory display
// ============================================================

"use client";

import { motion } from "framer-motion";
import type { ItemType } from "@/types/item";
import { cn } from "@/lib/utils/cn";

export type FilterType = "all" | "weapon" | "armor" | "potion" | "material";

interface InventoryFilterBarProps {
  activeFilter: FilterType;
  onFilterChange: (filter: FilterType) => void;
}

export function InventoryFilterBar({ activeFilter, onFilterChange }: InventoryFilterBarProps) {
  const filters: Array<{ id: FilterType; label: string; emoji: string }> = [
    { id: "all", label: "Hepsi", emoji: "📦" },
    { id: "weapon", label: "Silahlar", emoji: "⚔️" },
    { id: "armor", label: "Zırh", emoji: "🛡️" },
    { id: "potion", label: "İksirler", emoji: "🧪" },
    { id: "material", label: "Malzeme", emoji: "🪨" },
  ];

  return (
    <div className="flex gap-2 p-4 bg-[var(--bg-darker)] rounded-lg border border-[var(--border-subtle)] flex-wrap">
      {filters.map((filter) => (
        <motion.button
          key={filter.id}
          whileTap={{ scale: 0.95 }}
          onClick={() => onFilterChange(filter.id)}
          className={cn(
            "px-3 py-2 rounded-lg font-medium text-sm transition flex items-center gap-2",
            activeFilter === filter.id
              ? "bg-[var(--accent)] text-white"
              : "bg-[var(--bg-card)] text-[var(--text-muted)] hover:bg-[var(--bg-card)]/80"
          )}
        >
          <span>{filter.emoji}</span>
          {filter.label}
        </motion.button>
      ))}
    </div>
  );
}
