// ============================================================
// RecipeCard Component — Tekil Tarif Kartı
// Tarif adı, çıktı, başarı oranı, malzeme sayısı, seçim durumu
// ============================================================

"use client";

import { motion } from "framer-motion";
import type { CraftRecipe } from "@/types/crafting";
import { getRarityColor } from "@/types/item";
import type { Rarity } from "@/types/item";

interface RecipeCardProps {
  recipe: CraftRecipe;
  isSelected: boolean;
  onClick: () => void;
  index: number;
}

export function RecipeCard({ recipe, isSelected, onClick, index }: RecipeCardProps) {
  const successRate = recipe.success_rate
    ? Number(recipe.success_rate) > 1
      ? Number(recipe.success_rate) / 100
      : Number(recipe.success_rate)
    : 0.8;
  const outputRarity = (recipe.output_rarity || "common") as Rarity;

  return (
    <motion.button
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.03 }}
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      className={`w-full text-left rounded-xl border-2 p-4 transition-all duration-200 relative ${
        isSelected
          ? "border-blue-500 bg-gradient-to-br from-blue-500/20 to-purple-500/20 shadow-lg shadow-blue-500/20"
          : "border-white/20 bg-white/5 hover:border-white/40 hover:bg-white/10"
      }`}
    >
      {/* Header: Name + Output Count */}
      <div className="flex justify-between items-start mb-2">
        <h3 className={`font-bold text-sm ${getRarityColor(outputRarity)}`}>
          {recipe.output_name || recipe.name}
        </h3>
        <span className="text-xs font-bold text-cyan-300 bg-cyan-500/20 px-2 py-0.5 rounded">
          x{recipe.output_quantity}
        </span>
      </div>

      {/* Footer: Level + Ingredients + Time + Success Rate */}
      <div className="flex items-center justify-between text-xs text-white/60 gap-2">
        <span className="bg-white/10 px-2 py-1 rounded">Sv{recipe.required_level}</span>
        <span>
          {recipe.ingredients?.length || 0} 🔧
        </span>
        <span>
          {recipe.success_rate ? `${Math.round(successRate * 100)}%` : "80%"}
        </span>
      </div>

      {/* Selection Indicator */}
      {isSelected && (
        <motion.div
          layoutId="selectedRecipe"
          className="absolute inset-0 rounded-xl border-2 border-blue-400 pointer-events-none"
          initial={false}
        />
      )}
    </motion.button>
  );
}
