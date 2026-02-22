// ============================================================
// RecipeCard — Crafting recipe display card
// ============================================================

"use client";

import { motion } from "framer-motion";
import type { Rarity } from "@/types/item";
import { getRarityColor } from "@/types/item";

interface RecipeIngredient {
  item_id: string;
  name: string;
  quantity: number;
  hasEnough?: boolean;
}

interface RecipeCardProps {
  name: string;
  description: string;
  rarity: string;
  craftTimeSeconds: number;
  ingredients: RecipeIngredient[];
  onClick: () => void;
  disabled?: boolean;
}

export function RecipeCard({
  name,
  description,
  rarity,
  craftTimeSeconds,
  ingredients,
  onClick,
  disabled,
}: RecipeCardProps) {
  return (
    <motion.button
      whileTap={{ scale: 0.98 }}
      className="w-full bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-3 text-left disabled:opacity-50"
      onClick={onClick}
      disabled={disabled}
    >
      <div className="flex justify-between items-start">
        <div>
          <p className="font-medium" style={{ color: getRarityColor(rarity as Rarity) }}>
            {name}
          </p>
          <p className="text-xs text-[var(--text-secondary)] mt-0.5">{description}</p>
        </div>
        <span className="text-xs text-[var(--text-secondary)]">
          {Math.ceil(craftTimeSeconds / 60)}dk
        </span>
      </div>
      <div className="flex gap-1 mt-2 flex-wrap">
        {ingredients.map((ing) => (
          <span
            key={ing.item_id}
            className={`text-[10px] px-2 py-0.5 rounded ${
              ing.hasEnough === false ? "bg-red-900/30 text-red-400" : "bg-[var(--surface)]"
            }`}
          >
            {ing.name} ×{ing.quantity}
          </span>
        ))}
      </div>
    </motion.button>
  );
}
