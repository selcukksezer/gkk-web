// ============================================================
// Crafting Page — Üretim Atölyesi (Stacked Layout)
// Top: Craft preview + batch selector (glassmorphism)
// Middle: 7 recipe tabs + recipe list (grid)
// Bottom: Queue management
// ============================================================

"use client";

import { useEffect, useMemo, useCallback } from "react";
import { motion } from "framer-motion";
import { useCraftingStore } from "@/stores/craftingStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import type { CraftRecipe } from "@/types/crafting";
import { CraftPreview } from "@/components/game/CraftPreview";
import { RecipeTabsBar } from "@/components/game/RecipeTabsBar";
import { RecipeList } from "@/components/game/RecipeList";
import { QueueSection } from "@/components/game/QueueSection";

export default function CraftingPage() {
  // Store subscriptions
  const recipes = useCraftingStore((s) => s.recipes);
  const queue = useCraftingStore((s) => s.queue);
  const selectedRecipeId = useCraftingStore((s) => s.selectedRecipeId);
  const selectedBatchCount = useCraftingStore((s) => s.selectedBatchCount);
  const selectedTab = useCraftingStore((s) => s.selectedTab);
  const isLoading = useCraftingStore((s) => s.isLoading);
  const isCrafting = useCraftingStore((s) => s.isCrafting);
  const error = useCraftingStore((s) => s.error);

  // Store actions
  const loadRecipes = useCraftingStore((s) => s.loadRecipes);
  const loadQueue = useCraftingStore((s) => s.loadQueue);
  const craftItem = useCraftingStore((s) => s.craftItem);
  const claimItem = useCraftingStore((s) => s.claimItem);
  const hasMaterials = useCraftingStore((s) => s.hasMaterials);
  const setSelectedRecipe = useCraftingStore((s) => s.setSelectedRecipe);
  const setBatchCount = useCraftingStore((s) => s.setBatchCount);
  const setSelectedTab = useCraftingStore((s) => s.setSelectedTab);

  // Player & UI
  const level = usePlayerStore((s) => s.level);
  const gems = usePlayerStore((s) => s.gems);
  const addToast = useUiStore((s) => s.addToast);

  // Load recipes & queue on mount
  useEffect(() => {
    loadRecipes();
    loadQueue();
  }, [loadRecipes, loadQueue]);

  // Categorize recipes by item_type
  const recipeCounts = useMemo(() => {
    const counts: Record<string, number> = { tumu: recipes.length };
    recipes.forEach((r) => {
      const key = r.item_type || r.recipe_type || "accessory";
      counts[key] = (counts[key] || 0) + 1;
    });
    return counts;
  }, [recipes]);

  // Find selected recipe
  const selectedRecipe = useMemo(
    () => recipes.find((r) => r.id === selectedRecipeId || r.recipe_id === selectedRecipeId) || null,
    [recipes, selectedRecipeId]
  );

  // Check if can craft
  const canCraft = useMemo(() => {
    if (!selectedRecipe) return false;
    if (selectedRecipe.required_level > level) return false;
    const gemCost = Math.max(0, selectedBatchCount - 1);
    if (gems < gemCost) return false;
    return true;
  }, [selectedRecipe, selectedBatchCount, level, gems]);

  // Handle craft
  const handleCraft = useCallback(async () => {
    if (!selectedRecipe) return;
    const recipeId = selectedRecipe.id || selectedRecipe.recipe_id || "";
    const success = await craftItem(recipeId, selectedBatchCount);
    if (success) {
      addToast(`✅ ${selectedBatchCount}x üretim sıraya eklendi!`, "success");
      await loadQueue();
    } else if (error) {
      addToast(`❌ ${error}`, "error");
    }
  }, [selectedRecipe, selectedBatchCount, craftItem, addToast, loadQueue, error]);

  // Handle claim
  const handleClaim = useCallback(
    async (queueItemId: string) => {
      const success = await claimItem(queueItemId);
      if (success) {
        addToast("✅ Ürün talep edildi!", "success");
        await loadQueue();
      } else {
        addToast("❌ Talep başarısız!", "error");
      }
    },
    [claimItem, addToast, loadQueue]
  );

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="flex flex-col h-screen bg-gradient-to-b from-slate-900 via-slate-900 to-slate-800 relative pb-20"
    >
      {/* Premium Background Orbs */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-40 -right-40 w-80 h-80 bg-blue-600/20 rounded-full blur-3xl opacity-30" />
        <div className="absolute -bottom-40 -left-40 w-80 h-80 bg-purple-600/20 rounded-full blur-3xl opacity-30" />
      </div>

      {/* Main Content */}
      <div className="relative z-10 flex flex-col h-full overflow-hidden">
        {/* Header */}
        <div className="px-4 pt-4 pb-2 flex-shrink-0">
          <h1 className="text-2xl font-bold bg-gradient-to-r from-amber-400 to-orange-500 bg-clip-text text-transparent">
            🔨 Üretim Atölyesi
          </h1>
        </div>

        {/* Stacked Layout Container */}
        <div className="flex-1 flex flex-col overflow-hidden px-4 pb-4 space-y-3">
          {/* Section 1: CraftPreview (Top) */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="flex-shrink-0"
          >
            <CraftPreview
              recipe={selectedRecipe}
              batchCount={selectedBatchCount}
              onBatchChange={setBatchCount}
              onCraft={handleCraft}
              canCraft={canCraft}
              isLoading={isCrafting}
              gems={gems}
              playerLevel={level}
              hasMaterials={selectedRecipe ? hasMaterials(selectedRecipe, selectedBatchCount) : false}
            />
          </motion.div>

          {/* Section 2: RecipeTabsBar (Middle-Top) */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.15 }}
            className="flex-shrink-0"
          >
            <RecipeTabsBar
              activeTab={selectedTab}
              onTabChange={setSelectedTab}
              counts={recipeCounts}
            />
          </motion.div>

          {/* Section 3: RecipeList (Middle/Flex) */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
            className="flex-1 overflow-hidden"
          >
            <RecipeList
              recipes={recipes}
              selectedTab={selectedTab}
              selectedRecipeId={selectedRecipeId}
              onSelectRecipe={setSelectedRecipe}
              isLoading={isLoading}
            />
          </motion.div>

          {/* Section 4: QueueSection (Bottom) */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.25 }}
            className="flex-shrink-0 max-h-48 overflow-y-auto"
          >
            <QueueSection queue={queue} onClaim={handleClaim} isClaiming={isCrafting} />
          </motion.div>
        </div>
      </div>
    </motion.div>
  );
}
