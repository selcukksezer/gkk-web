// ============================================================
// Crafting Page — Kaynak: scenes/ui/screens/CraftingScreen.gd (389 satır)
// Kategori tabları, tarif listesi, detay paneli, batch 1-5, gem cost,
// malzeme kontrolü, başarı oranı, üretim kuyruğu
// ============================================================

"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useCraftingStore } from "@/stores/craftingStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useCountdown } from "@/hooks/useCountdown";
import { getRarityColor } from "@/types/item";
import type { Rarity } from "@/types/item";
import type { CraftRecipe } from "@/types/crafting";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";

// Godot: CraftingScreen.gd CATEGORIES
const CATEGORIES: { key: string; label: string }[] = [
  { key: "weapon", label: "⚔ Silahlar" },
  { key: "armor", label: "🛡 Zırhlar" },
  { key: "potion", label: "🧪 İksirler" },
  { key: "rune", label: "🔮 Rünler" },
  { key: "scroll", label: "📜 Scrolllar" },
  { key: "accessory", label: "💍 Aksesuarlar" },
];

const BATCH_MAX = 5; // Godot: const BATCH_MAX: int = 5

type CraftingTab = "recipes" | "queue";

/** Godot: _gem_cost — 1 adet → 0, 2 → 1, 3 → 2, ... */
function gemCost(qty: number): number {
  return Math.max(0, qty - 1);
}

/** Godot: _parse_rate — normalise to 0.0-1.0 */
function parseRate(value: number | undefined): number {
  if (!value) return 0.8;
  const f = Number(value);
  return f > 1 ? f / 100 : f;
}

/** Godot: _fmt_time */
function fmtTime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}sa ${m}dk`;
  if (m > 0) return `${m}dk ${s}sn`;
  return `${s}sn`;
}

export default function CraftingPage() {
  const recipes = useCraftingStore((s) => s.recipes);
  const queue = useCraftingStore((s) => s.queue);
  const fetchRecipes = useCraftingStore((s) => s.loadRecipes);
  const fetchQueue = useCraftingStore((s) => s.loadQueue);
  const startCraft = useCraftingStore((s) => s.craftItem);
  const claimCraft = useCraftingStore((s) => s.claimItem);
  const isLoading = useCraftingStore((s) => s.isLoading);
  const isCrafting = useCraftingStore((s) => s.isCrafting);
  const level = usePlayerStore((s) => s.level);
  const gems = usePlayerStore((s) => s.gems);
  const addToast = useUiStore((s) => s.addToast);

  const [activeTab, setActiveTab] = useState<CraftingTab>("recipes");
  const [currentCategory, setCurrentCategory] = useState("weapon");
  const [selectedRecipe, setSelectedRecipe] = useState<CraftRecipe | null>(null);
  const [batchCount, setBatchCount] = useState(1);

  useEffect(() => {
    fetchRecipes();
    fetchQueue();
  }, [fetchRecipes, fetchQueue]);

  // Godot: _categorize_recipes — group by item_type, unknown → accessory
  const categorized = useMemo(() => {
    const map: Record<string, CraftRecipe[]> = {};
    for (const c of CATEGORIES) map[c.key] = [];
    for (const r of recipes) {
      const key = r.item_type || r.recipe_type || "accessory";
      if (map[key]) {
        map[key].push(r);
      } else {
        map["accessory"].push(r);
      }
    }
    return map;
  }, [recipes]);

  const currentRecipes = categorized[currentCategory] || [];

  const handleCraft = useCallback(async () => {
    if (!selectedRecipe) return;
    const success = await startCraft(selectedRecipe.id || selectedRecipe.recipe_id || "", batchCount);
    if (success) {
      addToast(`✅ ${batchCount}x üretim sıraya eklendi!`, "success");
      setSelectedRecipe(null);
      setBatchCount(1);
      fetchQueue();
      fetchRecipes(); // Refresh materials
    }
  }, [selectedRecipe, batchCount, startCraft, fetchQueue, fetchRecipes, addToast]);

  const handleClaim = useCallback(
    async (queueId: string) => {
      await claimCraft(queueId);
      fetchQueue();
    },
    [claimCraft, fetchQueue]
  );

  // Godot: _can_craft validation
  const canCraft = useMemo(() => {
    if (!selectedRecipe) return false;
    if (selectedRecipe.required_level > level) return false;
    const cost = gemCost(batchCount);
    if (gems < cost) return false;
    return true;
  }, [selectedRecipe, batchCount, level, gems]);

  const currentGemCost = selectedRecipe ? gemCost(batchCount) : 0;

  return (
    <div className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🔨 Üretim Atölyesi</h1>

      {/* Tab Bar: Recipes / Queue */}
      <div className="flex gap-2">
        <button
          className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
            activeTab === "recipes" ? "bg-[var(--accent)] text-white" : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
          }`}
          onClick={() => setActiveTab("recipes")}
        >
          Tarifler ({recipes.length})
        </button>
        <button
          className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
            activeTab === "queue" ? "bg-[var(--accent)] text-white" : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
          }`}
          onClick={() => setActiveTab("queue")}
        >
          Kuyruk ({queue.length})
        </button>
      </div>

      {/* Recipes Tab */}
      {activeTab === "recipes" && (
        <>
          {/* Category Tabs — Godot: _build_category_tabs */}
          <div className="flex gap-1 overflow-x-auto no-scrollbar">
            {CATEGORIES.map((c) => (
              <button
                key={c.key}
                onClick={() => { setCurrentCategory(c.key); setSelectedRecipe(null); setBatchCount(1); }}
                className={`flex-shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                  currentCategory === c.key
                    ? "bg-[var(--accent)] text-white"
                    : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
                }`}
              >
                {c.label} ({(categorized[c.key] || []).length})
              </button>
            ))}
          </div>

          {/* Recipe List — Godot: _populate_recipe_list */}
          <div className="space-y-2">
            {isLoading ? (
              <p className="text-center text-[var(--text-muted)] py-8 text-sm">Yükleniyor...</p>
            ) : currentRecipes.length === 0 ? (
              <p className="text-center text-[var(--text-muted)] py-8 text-sm">Bu kategoride tarif bulunamadı</p>
            ) : (
              currentRecipes.map((recipe) => {
                const rate = parseRate(recipe.success_rate);
                const timeSec = recipe.craft_time_seconds || recipe.production_time_seconds || 0;
                return (
                  <motion.button
                    key={recipe.id}
                    whileTap={{ scale: 0.98 }}
                    className={`w-full bg-[var(--card-bg)] border rounded-xl p-3 text-left transition-colors ${
                      selectedRecipe?.id === recipe.id ? "border-[var(--accent)]" : "border-[var(--border-default)]"
                    }`}
                    onClick={() => { setSelectedRecipe(recipe); setBatchCount(1); }}
                  >
                    <div className="flex justify-between items-start">
                      <p className="font-medium text-sm" style={{ color: getRarityColor(recipe.output_rarity as Rarity) }}>
                        {recipe.output_name || recipe.name}
                      </p>
                      <span className="text-xs text-[var(--text-muted)]">
                        [Sv{recipe.required_level}] {fmtTime(timeSec)} %{Math.round(rate * 100)}
                      </span>
                    </div>
                    <div className="flex gap-1 mt-1.5 flex-wrap">
                      {recipe.ingredients.map((ing) => (
                        <span key={ing.item_id} className="text-[10px] bg-[var(--bg-input)] px-1.5 py-0.5 rounded text-[var(--text-secondary)]">
                          {ing.item_name} ×{ing.quantity}
                        </span>
                      ))}
                    </div>
                  </motion.button>
                );
              })
            )}
          </div>
        </>
      )}

      {/* Queue Tab — Godot: craft queue with countdown */}
      {activeTab === "queue" && (
        <div className="space-y-2">
          {queue.length === 0 ? (
            <p className="text-center text-[var(--text-muted)] py-8 text-sm">Üretim kuyruğu boş</p>
          ) : (
            queue.map((item) => (
              <QueueItemRow key={item.id} item={item} onClaim={() => handleClaim(item.id)} />
            ))
          )}
        </div>
      )}

      {/* Recipe Detail Modal — Godot: _update_detail_panel */}
      <AnimatePresence>
        {selectedRecipe && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4"
            onClick={() => setSelectedRecipe(null)}
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="bg-[var(--bg-surface)] rounded-2xl p-5 w-full max-w-sm border border-[var(--border-default)]"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Header */}
              <h2 className="text-lg font-bold mb-1" style={{ color: getRarityColor(selectedRecipe.output_rarity as Rarity) }}>
                {selectedRecipe.output_name || selectedRecipe.name}
              </h2>
              <p className="text-xs text-[var(--text-muted)] mb-3">
                ⏱ {fmtTime((selectedRecipe.craft_time_seconds || selectedRecipe.production_time_seconds || 0))}
                {" • "}
                %{Math.round(parseRate(selectedRecipe.success_rate) * 100)} başarı
              </p>

              {/* Batch Quantity — Godot: _on_increase_pressed / _on_decrease_pressed, BATCH_MAX=5 */}
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm text-[var(--text-primary)]">Miktar:</span>
                <div className="flex items-center gap-3">
                  <button
                    className="w-8 h-8 rounded-full bg-[var(--bg-card)] flex items-center justify-center text-[var(--text-primary)]"
                    onClick={() => setBatchCount(Math.max(1, batchCount - 1))}
                    disabled={batchCount <= 1}
                  >−</button>
                  <span className="font-bold w-8 text-center text-[var(--text-primary)]">{batchCount}</span>
                  <button
                    className="w-8 h-8 rounded-full bg-[var(--bg-card)] flex items-center justify-center text-[var(--text-primary)]"
                    onClick={() => setBatchCount(Math.min(BATCH_MAX, batchCount + 1))}
                    disabled={batchCount >= BATCH_MAX}
                  >+</button>
                </div>
              </div>

              {/* Product Info — Godot: _update_quantity_display */}
              <p className={`text-xs mb-3 ${currentGemCost === 0 ? "text-green-400" : gems >= currentGemCost ? "text-yellow-400" : "text-red-400"}`}>
                {batchCount}x {selectedRecipe.output_name || selectedRecipe.name}
                {" | "}
                {currentGemCost === 0 ? "💎 Ücretsiz" : `💎 ${currentGemCost} elmas${gems < currentGemCost ? " (YETERSİZ!)" : ""}`}
                {" | "}
                ⏱ {fmtTime((selectedRecipe.craft_time_seconds || selectedRecipe.production_time_seconds || 0) * batchCount)}
              </p>

              {/* Ingredients — Godot: _update_materials_list */}
              <div className="mb-4">
                <h3 className="text-xs font-medium text-[var(--text-secondary)] mb-2">Malzemeler</h3>
                {selectedRecipe.ingredients.map((ing) => {
                  const required = ing.quantity * batchCount;
                  return (
                    <div key={ing.item_id} className="flex justify-between text-sm py-0.5">
                      <span className="text-[var(--text-primary)]">{ing.item_name}</span>
                      <span className="text-[var(--text-muted)]">? / {required}</span>
                    </div>
                  );
                })}
              </div>

              {/* Actions */}
              <div className="flex gap-2">
                <button
                  className="flex-1 py-2 rounded-lg bg-[var(--bg-card)] text-[var(--text-secondary)] text-sm"
                  onClick={() => setSelectedRecipe(null)}
                >
                  İptal
                </button>
                <button
                  className={`flex-1 py-2 rounded-lg text-white font-medium text-sm ${
                    canCraft ? "bg-[var(--accent)]" : "bg-gray-600 opacity-50"
                  }`}
                  onClick={handleCraft}
                  disabled={!canCraft || isCrafting}
                >
                  {isCrafting ? "Üretiliyor..." : currentGemCost === 0 ? "ÜRETİMİ BAŞLAT (Ücretsiz)" : `ÜRETİMİ BAŞLAT (💎 ${currentGemCost})`}
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

/** Queue item row with countdown */
function QueueItemRow({
  item,
  onClaim,
}: {
  item: { id: string; recipe_name?: string; completes_at?: string; status?: string };
  onClaim: () => void;
}) {
  const { formatted, isComplete } = useCountdown({
    targetDate: item.completes_at ?? null,
  });

  return (
    <Card>
      <div className="p-3 flex items-center justify-between">
        <div>
          <p className="font-medium text-sm text-[var(--text-primary)]">{item.recipe_name ?? "Üretim"}</p>
          <p className="text-xs text-[var(--text-muted)]">
            {isComplete ? "✅ Hazır!" : formatted}
          </p>
        </div>
        {isComplete ? (
          <Button variant="primary" size="sm" onClick={onClaim}>Topla</Button>
        ) : (
          <span className="text-xs text-[var(--text-muted)]">{item.status ?? "Üretiliyor..."}</span>
        )}
      </div>
    </Card>
  );
}
