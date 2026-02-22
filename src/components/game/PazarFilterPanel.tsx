// ============================================================
// PazarFilterPanel — Market filter controls
// ============================================================

"use client";

import type { ItemType, Rarity } from "@/types/item";

interface PazarFilterPanelProps {
  selectedType: ItemType | "all";
  selectedRarity: Rarity | "all";
  sortBy: "price_asc" | "price_desc" | "newest";
  onTypeChange: (type: ItemType | "all") => void;
  onRarityChange: (rarity: Rarity | "all") => void;
  onSortChange: (sort: "price_asc" | "price_desc" | "newest") => void;
}

const ITEM_TYPES: { key: ItemType | "all"; label: string }[] = [
  { key: "all", label: "Tümü" },
  { key: "weapon", label: "Silah" },
  { key: "armor", label: "Zırh" },
  { key: "potion", label: "İksir" },
  { key: "material", label: "Malzeme" },
  { key: "rune", label: "Rün" },
];

const RARITIES: { key: Rarity | "all"; label: string; color: string }[] = [
  { key: "all", label: "Tümü", color: "#9ca3af" },
  { key: "common", label: "Sıradan", color: "#9ca3af" },
  { key: "uncommon", label: "Nadir", color: "#22c55e" },
  { key: "rare", label: "Ender", color: "#3b82f6" },
  { key: "epic", label: "Destansı", color: "#a855f7" },
  { key: "legendary", label: "Efsanevi", color: "#eab308" },
];

export function PazarFilterPanel({
  selectedType,
  selectedRarity,
  sortBy,
  onTypeChange,
  onRarityChange,
  onSortChange,
}: PazarFilterPanelProps) {
  return (
    <div className="space-y-3">
      {/* Type filter */}
      <div className="flex gap-1 flex-wrap">
        {ITEM_TYPES.map((t) => (
          <button
            key={t.key}
            className={`px-2 py-1 rounded text-xs ${
              selectedType === t.key
                ? "bg-[var(--primary)] text-white"
                : "bg-[var(--surface)] text-[var(--text-secondary)]"
            }`}
            onClick={() => onTypeChange(t.key)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Rarity filter */}
      <div className="flex gap-1 flex-wrap">
        {RARITIES.map((r) => (
          <button
            key={r.key}
            className={`px-2 py-1 rounded text-xs border ${
              selectedRarity === r.key
                ? "border-current"
                : "border-transparent bg-[var(--surface)]"
            }`}
            style={{ color: selectedRarity === r.key ? r.color : undefined }}
            onClick={() => onRarityChange(r.key)}
          >
            {r.label}
          </button>
        ))}
      </div>

      {/* Sort */}
      <select
        value={sortBy}
        onChange={(e) => onSortChange(e.target.value as typeof sortBy)}
        className="bg-[var(--surface)] border border-[var(--border)] rounded-lg px-2 py-1 text-xs"
      >
        <option value="newest">En Yeni</option>
        <option value="price_asc">Fiyat ↑</option>
        <option value="price_desc">Fiyat ↓</option>
      </select>
    </div>
  );
}
