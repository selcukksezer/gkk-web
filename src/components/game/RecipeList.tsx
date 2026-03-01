// ============================================================
// RecipeList Component — Tarif Listesi Görünümü
// Filtreli tariflerin grid/scroll görünümü
// ============================================================

"use client";

import { useMemo } from "react";
import { motion } from "framer-motion";
import type { CraftRecipe } from "@/types/crafting";
import { RecipeCard } from "./RecipeCard";

interface RecipeListProps {
  recipes: CraftRecipe[];
  selectedTab: string;
  selectedRecipeId: string | null;
  onSelectRecipe: (recipeId: string) => void;
  isLoading: boolean;
}

export function RecipeList({
  recipes,
  selectedTab,
  selectedRecipeId,
  onSelectRecipe,
  isLoading,
}: RecipeListProps) {
  // Filter recipes by tab
  const filteredRecipes = useMemo(() => {
    if (selectedTab === "tumu") return recipes;
    return recipes.filter((r) => (r.item_type || r.recipe_type || "accessory") === selectedTab);
  }, [recipes, selectedTab]);

  const containerVariants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.05,
      },
    },
  };

  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="px-4 py-2 flex justify-between items-center">
        <h3 className="font-bold text-white">
          {selectedTab === "tumu" ? "Tümü" : "Tarifler"} ({filteredRecipes.length})
        </h3>
      </div>

      {/* Recipe List */}
      {isLoading ? (
        <div className="flex-1 flex items-center justify-center">
          <p className="text-white/50">Yükleniyor...</p>
        </div>
      ) : filteredRecipes.length === 0 ? (
        <div className="flex-1 flex items-center justify-center">
          <p className="text-center text-white/40 text-sm">Bu kategoride tarif bulunamadı</p>
        </div>
      ) : (
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="show"
          className="flex-1 overflow-y-auto space-y-2 px-4 pb-4"
        >
          {filteredRecipes.map((recipe, idx) => (
            <RecipeCard
              key={recipe.id}
              recipe={recipe}
              isSelected={selectedRecipeId === recipe.id}
              onClick={() => onSelectRecipe(recipe.id || recipe.recipe_id || "")}
              index={idx}
            />
          ))}
        </motion.div>
      )}
    </div>
  );
}
