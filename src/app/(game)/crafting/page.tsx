// ============================================================
// Crafting Page — Üretim Atölyesi (Stacked Layout)
// Top: Craft preview + batch selector (glassmorphism)
// Middle: 7 recipe tabs + recipe list (grid)
// Bottom: Queue management
// ============================================================

"use client";

import { useEffect, useMemo, useCallback, useState } from "react";
import { supabase } from "@/lib/supabase";
import { motion } from "framer-motion";
import { useCraftingStore } from "@/stores/craftingStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import type { CraftRecipe } from "@/types/crafting";
import { CraftPreview } from "@/components/game/CraftPreview";
import { RecipeTabsBar } from "@/components/game/RecipeTabsBar";
import { RecipeList } from "@/components/game/RecipeList";
import { QueueSection } from "@/components/game/QueueSection";

export default function CraftingPage() {
  const [queueCollapsed, setQueueCollapsed] = useState(false);
  const [showPreview, setShowPreview] = useState(true);
  
  // Store subscriptions
  const recipes = useCraftingStore((s) => s.recipes);
  const queue = useCraftingStore((s) => s.queue);
  const selectedRecipeId = useCraftingStore((s) => s.selectedRecipeId);
  const selectedBatchCount = useCraftingStore((s) => s.selectedBatchCount);
  const selectedTab = useCraftingStore((s) => s.selectedTab);
  const isLoading = useCraftingStore((s) => s.isLoading);
  const isCrafting = useCraftingStore((s) => s.isCrafting);
  const isCancelling = useCraftingStore((s) => s.isCancelling);
  const error = useCraftingStore((s) => s.error);

  // Store actions
  const loadRecipes = useCraftingStore((s) => s.loadRecipes);
  const loadQueue = useCraftingStore((s) => s.loadQueue);
  const craftItem = useCraftingStore((s) => s.craftItem);
  const claimItem = useCraftingStore((s) => s.claimItem);
  const cancelItem = useCraftingStore((s) => s.cancelItem);
  const hasMaterials = useCraftingStore((s) => s.hasMaterials);
  const setSelectedRecipe = useCraftingStore((s) => s.setSelectedRecipe);
  const setBatchCount = useCraftingStore((s) => s.setBatchCount);
  const setSelectedTab = useCraftingStore((s) => s.setSelectedTab);

  // Player & UI
  const level = usePlayerStore((s) => s.level);
  const gems = usePlayerStore((s) => s.gems);
  const addToast = useUiStore((s) => s.addToast);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);

  // Load recipes & queue on mount
  useEffect(() => {
    loadRecipes();
    loadQueue();
    // Ensure inventory is loaded so material checks are accurate
    fetchInventory();
  }, [loadRecipes, loadQueue]);

  // Auto-show preview when a recipe is selected
  useEffect(() => {
    if (selectedRecipeId) setShowPreview(true);
  }, [selectedRecipeId]);

  // Categorize recipes by item_type (now properly populated from RPC)
  const recipeCounts = useMemo(() => {
    const counts: Record<string, number> = { tumu: recipes.length };
    recipes.forEach((r) => {
      // Use item_type first (preferred), fallback to recipe_type, then accessory
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
      // Close preview and reset selection when craft successfully started
      setShowPreview(false);
      setSelectedRecipe(null);
      setBatchCount(1);
      addToast(`✅ ${selectedBatchCount}x üretim sıraya eklendi!`, "success");
      await loadQueue();
    } else if (error) {
      addToast(`❌ ${error}`, "error");
    }
  }, [selectedRecipe, selectedBatchCount, craftItem, addToast, loadQueue, error]);

  // Handle claim
  const handleClaim = useCallback(
    async (queueItemId: string) => {
      const res = await claimItem(queueItemId);
      if (res.success) {
        addToast("✅ Ürün talep edildi!", "success");
        if (res.xp_awarded && res.xp_awarded > 0) {
          addToast(`✨ +${res.xp_awarded} XP`, "success");
        }
        await loadQueue();
      } else {
        // Başarısız üretimler için toast gösterme, kuyrukta gösterilecek
        // Sadece envanter dolu gibi diğer hatalar için toast göster
        if (res.message && res.message !== 'Üretim başarısız') {
          addToast(`❌ ${res.message}`, "error");
        }
        await loadQueue();
      }
    },
    [claimItem, addToast, loadQueue]
  );

  // Handle cancel
  const handleCancel = useCallback(
    async (queueItemId: string) => {
      const success = await cancelItem(queueItemId);
      if (success) {
        addToast("✅ Üretim iptal edildi (Ödül verilmedi)", "success");
        await loadQueue();
      } else {
        addToast("❌ İptal başarısız!", "error");
      }
    },
    [cancelItem, addToast, loadQueue]
  );

    // Finalize: run server-side success/failure once completes_at passed
    const handleFinalize = useCallback(
      async (queueItemId: string) => {
        try {
          const res = await supabase.rpc("finalize_crafted_item", { p_queue_item_id: queueItemId });
          // Supabase returns rows for table-returning functions
          // Log server-side success_rate and roll to console for diagnostics
          // `res` shape can be { data, error } or array depending on client version; handle both
          // @ts-ignore
          const rows = res?.data ?? res;
          if (rows && Array.isArray(rows) && rows.length > 0) {
            const row = rows[0];
            console.info(`[finalize] queue=${queueItemId} success=${row.success} success_rate=${row.success_rate} roll=${row.roll}`);
          } else if (rows && rows.success !== undefined) {
            // single object
            // @ts-ignore
            console.info(`[finalize] queue=${queueItemId} success=${rows.success} success_rate=${rows.success_rate} roll=${rows.roll}`);
          }
        } catch (e) {
          console.error("finalize_crafted_item error", e);
        } finally {
          await loadQueue();
        }
      },
      [loadQueue]
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
          {/* Section 1: CraftPreview (Top) - moved into overlay below so it doesn't reduce RecipeList height */}

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

          {/* Middle area: recipe list fills remaining space; preview and queue are overlays so they don't shrink the list */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.25 }}
            className="flex-1 min-h-0 relative"
          >
            {/* Recipe list occupies full area and is scrollable */}
            <div className="absolute inset-0 overflow-auto">
              <RecipeList
                recipes={recipes}
                selectedTab={selectedTab}
                selectedRecipeId={selectedRecipeId}
                onSelectRecipe={setSelectedRecipe}
                isLoading={isLoading}
              />
            </div>

            {/* Overlay: Queue removed from here and placed at root to avoid transform clipping */}

            {/* Overlay: CraftPreview (top, centered) */}
            {showPreview && selectedRecipe && (
              <div className="fixed left-0 right-0 z-50" style={{ top: "calc(3rem + env(safe-area-inset-top))" }}>
                <div className="flex justify-center px-4 pointer-events-none">
                  <div className="pointer-events-auto">
                    <CraftPreview
                  recipe={selectedRecipe}
                  batchCount={selectedBatchCount}
                  onBatchChange={setBatchCount}
                  onCraft={handleCraft}
                  canCraft={canCraft}
                  isLoading={isCrafting}
                  gems={gems}
                  playerLevel={level}
                  onClose={() => {
                    setSelectedRecipe(null);
                    setBatchCount(1);
                    setShowPreview(false);
                  }}
                    />
                  </div>
                </div>
              </div>
            )}
          </motion.div>
        </div>
      </div>
      {/* Fixed QueueSection anchored to viewport (outside transformed containers) */}
      {queue && queue.length > 0 && (
        <div className="fixed z-50 right-4 bottom-16">
          <div className="w-full max-w-md md:w-72">
            <QueueSection
              queue={queue}
              onClaim={handleClaim}
              onAcknowledge={async (id: string) => {
                const success = await useCraftingStore.getState().acknowledgeItem(id);
                if (success) await loadQueue();
              }}
              onFinalize={handleFinalize}
              onCancel={handleCancel}
              isClaiming={isCrafting}
              isCancelling={isCancelling}
            />
          </div>
        </div>
      )}
    </motion.div>
  );
}
