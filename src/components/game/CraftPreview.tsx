// ============================================================
// CraftPreview Component — Üretim Ön İzlemesi (Top Section)
// Seçili tarifin görsel malzeme slotları, batch selector, düğmeler
// ============================================================

"use client";

import { useMemo, useEffect, useState } from "react";
import { motion } from "framer-motion";
import type { CraftRecipe } from "@/types/crafting";
import { getRarityColor } from "@/types/item";
import type { Rarity } from "@/types/item";
import { getItemFromSupabase, getItemsFromSupabase, type ItemMeta } from "@/lib/itemResolver";
import { ItemIcon } from "@/components/game/ItemIcon";
import { Button } from "@/components/ui/Button";
import { useInventoryStore } from "@/stores/inventoryStore";

interface CraftPreviewProps {
  recipe: CraftRecipe | null;
  batchCount: number;
  onBatchChange: (count: number) => void;
  onCraft: () => void;
  canCraft: boolean;
  isLoading: boolean;
  gems: number;
  playerLevel: number;
  onClose?: () => void;
}

const BATCH_LIMIT = 5;

function formatTime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}sa ${m}dk`;
  if (m > 0) return `${m}dk ${s}sn`;
  return `${s}sn`;
}

function gemCost(qty: number): number {
  return Math.max(0, qty - 1);
}

function parseRate(value: number | undefined): number {
  if (!value) return 0.8;
  const f = Number(value);
  return f > 1 ? f / 100 : f;
}

export function CraftPreview({
  recipe,
  batchCount,
  onBatchChange,
  onCraft,
  canCraft,
  isLoading,
  gems,
  playerLevel,
  onClose,
}: CraftPreviewProps) {
  const [outputItem, setOutputItem] = useState<ItemMeta | null>(null);
  const [ingredientItems, setIngredientItems] = useState<Map<string, ItemMeta>>(new Map());
  
  // Envanter güncellendikçe recompute etmek için subscribe et
  const getItemQuantity = useInventoryStore((s) => s.getItemQuantity);

  // Supabase'den item metadata çek
  useEffect(() => {
    if (!recipe) {
      setOutputItem(null);
      setIngredientItems(new Map());
      return;
    }

    const loadItems = async () => {
      // Output item çek
      const output = await getItemFromSupabase(recipe.output_item_id);
      setOutputItem(output);

      // Ingredients için batch çek
      if (recipe.ingredients && recipe.ingredients.length > 0) {
        const ingredientIds = recipe.ingredients.map((ing) => ing.item_id);
        const items = await getItemsFromSupabase(ingredientIds);
        setIngredientItems(items);
      }
    };

    loadItems();
  }, [recipe]);

  if (!recipe) {
    return (
      <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/8 to-white/[0.02] backdrop-blur-2xl p-8">
        <p className="text-center text-white/50">Tarif seçin</p>
      </div>
    );
  }

  const outputRarity = (recipe.output_rarity || outputItem?.rarity || "common") as Rarity;
  const costGems = gemCost(batchCount);
  const successRate = parseRate(recipe.success_rate);
  const craftTime = recipe.production_time_seconds || 0;
  const totalTime = craftTime * batchCount;
  const levelTooHigh = recipe.required_level > playerLevel;
  const gemsInsufficient = costGems > gems;

  // Compute materials availability reactively using inventory selector
  const localHasMaterials = recipe.ingredients
    ? recipe.ingredients.every((ing) => {
        const required = (ing.quantity ?? 1) * batchCount;
        const owned = getItemQuantity(ing.item_id);
        return owned >= required;
      })
    : true;

  return (
    <motion.div
      key={recipe.id}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/8 to-white/[0.02] backdrop-blur-2xl p-6 overflow-hidden"
    >
      {/* Background Accent */}
      <div className="absolute inset-0 bg-gradient-to-r from-blue-600/0 via-purple-600/5 to-blue-600/0 pointer-events-none" />

      <div className="relative z-10 space-y-4">
        {/* Header: Item Name & Rarity */}
        <div className="flex items-start justify-between">
          <div>
            <h2 className={`text-lg font-bold ${getRarityColor(outputRarity)}`}>
              {recipe.output_name || recipe.name}
            </h2>
            <p className="text-xs text-white/40 mt-1">Üretim Ön İzlemesi</p>
          </div>
          <div className="flex items-center gap-2">
            {/* removed top quantity badge as requested */}
          </div>
        </div>

        {/* Production Output - Üretilecek Malzeme */}
        <div className="space-y-2">
          <p className="text-xs font-semibold text-white/60 uppercase tracking-wide">Üretilecek Malzeme</p>
          <div className="rounded-lg border-2 border-cyan-500/50 bg-gradient-to-br from-cyan-500/20 to-blue-500/10 p-3">
            <div className="flex items-center gap-4">
              <div className="flex-shrink-0">
                <ItemIcon
                  icon={outputItem?.icon}
                  itemType={outputItem?.type}
                  itemId={recipe.output_item_id}
                  className="w-14 h-14"
                />
              </div>
              <div className="flex-1">
                <div className={`text-sm font-bold ${getRarityColor(outputRarity)}`}>
                  {recipe.output_name || outputItem?.name || "Bilinmiyor"}
                </div>
                <div className="text-xs text-cyan-300 mt-1">
                  Miktar: <span className="font-semibold">x{recipe.output_quantity * batchCount}</span>
                </div>
                {outputItem?.description && (
                  <div className="text-xs text-white/50 mt-2 line-clamp-2">
                    {outputItem.description}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Material Slots Grid - Visual Representation */}
        <div className="space-y-2">
          <p className="text-xs font-semibold text-white/60 uppercase tracking-wide">Gerekli Malzemeler</p>
          <div className="grid grid-cols-3 gap-2">
            {recipe.ingredients && recipe.ingredients.length > 0 ? (
              recipe.ingredients.map((ing, idx) => {
                const item = ingredientItems.get(ing.item_id);
                const itemRarity = (item?.rarity || "common") as Rarity;
                const rarityColor = getRarityColor(itemRarity);
                // Get live inventory quantity through selector (reactive)
                const owned = getItemQuantity(ing.item_id);
                const required = (ing.quantity ?? 1) * batchCount;
                const enough = owned >= required;

                return (
                  <motion.div
                    key={ing.item_id + "-" + idx}
                    initial={{ scale: 0.8, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    transition={{ delay: idx * 0.05 }}
                    className={`rounded-lg border-2 p-2 text-center text-xs font-medium ${
                      enough ? "border-green-500/50 bg-green-500/10" : "border-red-500/50 bg-red-500/10"
                    }`}
                  >
                    <div className="flex flex-col items-center">
                      <ItemIcon icon={item?.icon} itemType={item?.type} itemId={ing.item_id} className="w-10 h-10" />
                      <div className={`mt-1 text-[11px] font-semibold ${rarityColor}`}>
                        {ing.item_name || item?.name || "Bilinmiyor"}
                      </div>
                    </div>
                    <div className={`text-white/60 text-xs mt-1 ${enough ? "text-green-200" : "text-red-200"}`}>
                      {owned} / {required}
                    </div>
                  </motion.div>
                );
              })
            ) : (
              <p className="col-span-3 text-center text-white/40 text-xs py-4">Malzeme gerekmiyor</p>
            )}
          </div>
        </div>

        {/* Recipe Info Grid */}
        <div className="grid grid-cols-2 gap-3">
          <div className="rounded-lg bg-white/5 border border-white/10 p-3">
            <p className="text-xs text-white/50 uppercase tracking-wide">Seviye Gereksinimi</p>
            <p className={`text-sm font-bold mt-1 ${levelTooHigh ? "text-red-400" : "text-cyan-300"}`}>
              Sv{recipe.required_level}
            </p>
          </div>
          <div className="rounded-lg bg-white/5 border border-white/10 p-3">
            <p className="text-xs text-white/50 uppercase tracking-wide">Başarı Oranı</p>
            <p className="text-sm font-bold text-yellow-300 mt-1">{Math.round(successRate * 100)}%</p>
          </div>
          <div className="rounded-lg bg-white/5 border border-white/10 p-3">
            <p className="text-xs text-white/50 uppercase tracking-wide">Elmas Maliyeti</p>
            <p className={`text-sm font-bold mt-1 ${gemsInsufficient ? "text-red-400" : "text-purple-300"}`}>
              {costGems} 💎
            </p>
          </div>
          <div className="rounded-lg bg-white/5 border border-white/10 p-3">
            <p className="text-xs text-white/50 uppercase tracking-wide">Üretim Süresi</p>
            <p className="text-sm font-bold text-orange-300 mt-1">{formatTime(totalTime)}</p>
          </div>
        </div>

        {/* Batch Selector */}
        <div className="rounded-lg bg-white/5 border border-white/10 p-3">
          <p className="text-xs font-semibold text-white/60 uppercase tracking-wide mb-2">Batch Sayısı</p>
          <div className="flex items-center justify-between gap-3">
            <button
              onClick={() => onBatchChange(Math.max(1, batchCount - 1))}
              className="w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 transition-colors text-sm font-bold"
            >
              −
            </button>
            <input
              type="number"
              min="1"
              max={BATCH_LIMIT}
              value={batchCount}
              onChange={(e) => onBatchChange(Math.max(1, Math.min(BATCH_LIMIT, Number(e.target.value))))}
              className="flex-1 text-center rounded-lg bg-white/10 border border-white/20 text-white font-bold py-2 px-3"
            />
            <button
              onClick={() => onBatchChange(Math.min(BATCH_LIMIT, batchCount + 1))}
              className="w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 transition-colors text-sm font-bold"
            >
              +
            </button>
          </div>
          <p className="text-xs text-white/40 mt-2 text-center">Max: {BATCH_LIMIT}</p>
        </div>

        {/* Error Messages */}
        {levelTooHigh && (
          <div className="rounded-lg bg-red-500/10 border border-red-500/30 p-2 text-xs text-red-300">
            ⚠️ Seviye gereksinimi yetersiz
          </div>
        )}
        {gemsInsufficient && costGems > 0 && (
          <div className="rounded-lg bg-red-500/10 border border-red-500/30 p-2 text-xs text-red-300">
            ⚠️ Elmas yetersiz ({gems}/{costGems})
          </div>
        )}
        {!localHasMaterials && (
          <div className="rounded-lg bg-red-500/10 border border-red-500/30 p-2 text-xs text-red-300">
            ⚠️ Malzeme yetersiz
          </div>
        )}

        {/* Action Buttons: Cancel + Start */}
        <div className="flex items-center gap-3">
          {onClose && (
            <Button
              onClick={onClose}
              className="flex-1 py-3 bg-red-600/20 hover:bg-red-600/30 text-sm font-semibold"
            >
              İptal
            </Button>
          )}
          <Button
            onClick={onCraft}
            disabled={!canCraft || isLoading}
            className="flex-1 py-3 bg-gradient-to-r from-amber-600 to-amber-700 hover:from-amber-700 hover:to-amber-800 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isLoading ? "Üretiliyor..." : `🔨 Üretimi Başlat (${batchCount}x)`}
          </Button>
        </div>
      </div>
    </motion.div>
  );
}
