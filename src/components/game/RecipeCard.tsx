// ============================================================
// RecipeCard Component — Tekil Tarif Kartı
// Tarif adı, çıktı malzeme görseli + adı, başarı oranı, malzeme sayısı
// ============================================================

"use client";

import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import type { CraftRecipe } from "@/types/crafting";
import { getRarityColor } from "@/types/item";
import type { Rarity } from "@/types/item";
import { getItemFromSupabase, type ItemMeta } from "@/lib/itemResolver";
import { ItemIcon } from "@/components/game/ItemIcon";

interface RecipeCardProps {
  recipe: CraftRecipe;
  isSelected: boolean;
  onClick: () => void;
  index: number;
}

export function RecipeCard({ recipe, isSelected, onClick, index }: RecipeCardProps) {
  const [outputItem, setOutputItem] = useState<ItemMeta | null>(null);

  // Fetch output item metadata
  useEffect(() => {
    const loadItem = async () => {
      const item = await getItemFromSupabase(recipe.output_item_id);
      setOutputItem(item);
    };
    loadItem();
  }, [recipe.output_item_id]);

  const successRate = recipe.success_rate
    ? Number(recipe.success_rate) > 1
      ? Number(recipe.success_rate) / 100
      : Number(recipe.success_rate)
    : 0.8;
  const outputRarity = (recipe.output_rarity || outputItem?.rarity || "common") as Rarity;
  const outputName = recipe.output_name || outputItem?.name || "Bilinmiyor";

  return (
    <motion.button
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.03 }}
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      className={`w-full text-left rounded-xl border-2 p-3 transition-all duration-200 relative ${
        isSelected
          ? "border-blue-500 bg-gradient-to-br from-blue-500/20 to-purple-500/20 shadow-lg shadow-blue-500/20"
          : "border-white/20 bg-white/5 hover:border-white/40 hover:bg-white/10"
      }`}
    >
      {/* Flex container: Icon + Info */}
      <div className="flex gap-3 items-start">
        {/* Output Item Icon */}
        <div className="flex-shrink-0 w-12 h-12">
          <ItemIcon
            icon={outputItem?.icon}
            itemType={outputItem?.type}
            itemId={recipe.output_item_id}
            className="w-full h-full"
          />
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          {/* Header: Name + Output Count */}
          <div className="flex justify-between items-start gap-2 mb-2">
            <div className="flex flex-col">
              <h3 className={`font-bold text-sm ${getRarityColor(outputRarity)} truncate`}>
                {outputName}
              </h3>
              {outputItem?.is_han_only && (
                <span className="text-[10px] text-orange-400 font-semibold mt-0.5">
                  🏪 Sadece Han
                </span>
              )}
            </div>
            <span className="text-xs font-bold text-cyan-300 bg-cyan-500/20 px-2 py-0.5 rounded flex-shrink-0">
              x{recipe.output_quantity}
            </span>
          </div>

          {/* Footer: Level + Ingredients + Time + Success Rate */}
          <div className="flex items-center justify-between text-xs text-white/60 gap-2 flex-wrap">
            <span className="bg-white/10 px-2 py-1 rounded">Sv{recipe.required_level}</span>
            <span>
              {recipe.ingredients?.length || 0} 🔧
            </span>
            <span>
              {recipe.success_rate ? `${Math.round(successRate * 100)}%` : "80%"}
            </span>
          </div>
        </div>
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
