// ============================================================
// useEnhancement — Ekipman geliştirme (upgrade) sistemi
// Kaynak: PLAN_05_ENHANCEMENT_SYSTEM.md
// Server-authoritative: enhance_item RPC çağrılır
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { GAME_CONFIG } from "@/data/GameConstants";
import { trackEnhancement } from "@/lib/telemetry";
import { supabase } from "@/lib/supabase";
import type { InventoryItem } from "@/types/inventory";

type RuneType = "none" | "basic" | "advanced" | "superior" | "legendary" | "protection" | "blessed";

interface RuneInfo {
  type: RuneType;
  successBonus: number;
  destructionReduction: number;
  cost: number;
}

const RUNES: Record<RuneType, RuneInfo> = {
  none: { type: "none", successBonus: 0, destructionReduction: 0, cost: 0 },
  basic: { type: "basic", successBonus: 0.05, destructionReduction: 0, cost: 50000 },
  advanced: { type: "advanced", successBonus: 0.1, destructionReduction: 0, cost: 200000 },
  superior: { type: "superior", successBonus: 0.15, destructionReduction: 0.5, cost: 500000 },
  legendary: { type: "legendary", successBonus: 0.25, destructionReduction: 0.75, cost: 1500000 },
  protection: { type: "protection", successBonus: 0, destructionReduction: 1.0, cost: 2500000 },
  blessed: { type: "blessed", successBonus: 0.2, destructionReduction: 0.5, cost: 5000000 },
};

const ENHANCEMENT_GOLD_COSTS = [
  100000, 200000, 300000, 500000, 1500000, 3500000, 7500000, 15000000, 50000000, 200000000, 1000000000
];

const RARITY_MULTIPLIER: Record<string, number> = {
  common: 1.0,
  uncommon: 1.5,
  rare: 2.5,
  epic: 4.0,
  legendary: 7.0,
  mythic: 12.0,
};

export function useEnhancement() {
  const [isEnhancing, setIsEnhancing] = useState(false);
  const [lastResult, setLastResult] = useState<{
    success: boolean;
    destroyed: boolean;
    newLevel: number;
  } | null>(null);

  const authId = usePlayerStore((s) => s.profile?.auth_id ?? null);
  const gold = usePlayerStore((s) => s.gold);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);
  const items = useInventoryStore((s) => s.items);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);

  const config = GAME_CONFIG.enhancement;

  /** Get success rate for a level + rune combination */
  const getSuccessRate = useCallback(
    (currentLevel: number, rune: RuneType = "none"): number => {
      const baseRate = config.successRates[currentLevel] ?? 0.05;
      const runeBonus = RUNES[rune].successBonus;
      return Math.min(1.0, baseRate + runeBonus);
    },
    [config]
  );

  /** Get destruction rate for a level + rune combination */
  const getDestructionRate = useCallback(
    (currentLevel: number, rune: RuneType = "none"): number => {
      const baseRate = config.destructionRates[currentLevel] ?? 0;
      const reduction = RUNES[rune].destructionReduction;
      return Math.max(0, baseRate * (1 - reduction));
    },
    [config]
  );

  /** Calculate total cost (gold + rune) */
  const getCost = useCallback(
    (currentLevel: number, rune: RuneType = "none", rarity: string = "common") => {
      const baseGold =
        ENHANCEMENT_GOLD_COSTS[currentLevel] ?? ENHANCEMENT_GOLD_COSTS[ENHANCEMENT_GOLD_COSTS.length - 1];
      const rarityMult = RARITY_MULTIPLIER[rarity] || 1.0;
      const goldCost = Math.floor(baseGold * rarityMult);
      const runeCost = RUNES[rune].cost;
      return { gold: goldCost, rune: runeCost, total: goldCost };
    },
    []
  );

  /** Get required scroll ID by item rarity */
  const getRequiredScroll = useCallback(
    (rarity: string): string => {
      if (["common", "uncommon"].includes(rarity)) return "scroll_upgrade_low";
      if (["rare", "epic"].includes(rarity)) return "scroll_upgrade_middle";
      return "scroll_upgrade_high";
    },
    []
  );

  /** Check if player has required scroll */
  const hasRequiredScroll = useCallback(
    (rarity: string): boolean => {
      const scrollId = getRequiredScroll(rarity);
      return items.some((i) => i.item_id === scrollId && (i.quantity ?? 1) > 0);
    },
    [items, getRequiredScroll]
  );

  /** Full enhancement info display */
  const getEnhancementInfo = useCallback(
    (currentLevel: number, rune: RuneType = "none", rarity: string = "common") => {
      return {
        successRate: getSuccessRate(currentLevel, rune),
        destructionRate: getDestructionRate(currentLevel, rune),
        cost: getCost(currentLevel, rune, rarity),
        maxLevel: config.successRates.length - 1,
        statBonusPerLevel: config.statBonusPerLevel,
        currentLevel,
        rune: RUNES[rune],
      };
    },
    [getSuccessRate, getDestructionRate, getCost, config]
  );

  /** Perform enhancement attempt — SERVER-AUTHORITATIVE */
  const enhanceItem = useCallback(
    async (
      item: InventoryItem,
      rune: RuneType = "none"
    ): Promise<{ success: boolean; destroyed: boolean; newLevel: number }> => {
      if (!authId) {
        addToast("Oturum bulunamadı!", "error");
        return { success: false, destroyed: false, newLevel: item.enhancement_level ?? 0 };
      }

      const currentLevel = item.enhancement_level ?? 0;
      const { total } = getCost(currentLevel, rune, item.rarity);

      // Gold check
      if (gold < total) {
        addToast(`Yetersiz altın! (${total} gerekli)`, "error");
        return { success: false, destroyed: false, newLevel: currentLevel };
      }

      // Scroll check
      const scrollId = getRequiredScroll(item.rarity);
      const scrollItem = items.find((i) => i.item_id === scrollId && (i.quantity ?? 1) > 0);
      if (!scrollItem) {
        addToast("Geliştirme parşömeni gerekli!", "error");
        return { success: false, destroyed: false, newLevel: currentLevel };
      }
      
      // Rune check
      if (rune !== "none") {
        const runeItem = items.find((i) => i.item_id === "rune_" + rune && (i.quantity ?? 1) > 0);
        if (!runeItem) {
          addToast("Seçilen rune envanterde yok!", "error");
          return { success: false, destroyed: false, newLevel: currentLevel };
        }
      }

      setIsEnhancing(true);

      // Call RPC
      const { data, error } = await supabase.rpc("enhance_item", {
        p_player_id: authId,
        p_row_id: item.row_id,
        p_rune_type: rune
      });

      if (error || !data) {
        console.error("Enhancement failed:", error);
        addToast(error?.message || "Geliştirme sırasında sunucu hatası!", "error");
        setIsEnhancing(false);
        return { success: false, destroyed: false, newLevel: currentLevel };
      }

      const result = data as {
        success: boolean;
        destroyed: boolean;
        new_level: number;
        gold_spent: number;
        success_rate: number;
        error?: string;
      };

      if (result.error) {
        addToast(`Hata: ${result.error}`, "error");
        setIsEnhancing(false);
        return { success: false, destroyed: false, newLevel: currentLevel };
      }

      // Re-fetch inventory
      await fetchInventory();
      // Deduct gold locally (or re-fetch player data, but local deduct is fine)
      updateGold(gold - result.gold_spent);

      if (result.destroyed) {
        addToast("Geliştirme başarısız — eşya yok edildi!", "error");
      } else if (result.success) {
        addToast(`Geliştirme başarılı! +${result.new_level}`, "success");
      } else {
        addToast(`Geliştirme başarısız! Seviye ${result.new_level}'a düştü`, "warning");
      }

      setLastResult({
        success: result.success,
        destroyed: result.destroyed,
        newLevel: result.new_level
      });
      setIsEnhancing(false);

      trackEnhancement(
        item.item_id,
        currentLevel,
        result.destroyed ? "destroy" : result.success ? "success" : "fail"
      );

      // Sync player gold to server
      const playerStore = usePlayerStore.getState();
      playerStore.syncToSupabase?.();

      return {
        success: result.success,
        destroyed: result.destroyed,
        newLevel: result.new_level
      };
    },
    [authId, gold, updateGold, getCost, getRequiredScroll, items, fetchInventory, addToast]
  );

  return {
    isEnhancing,
    lastResult,
    getSuccessRate,
    getDestructionRate,
    getCost,
    getRequiredScroll,
    hasRequiredScroll,
    getEnhancementInfo,
    enhanceItem,
    RUNES,
    ENHANCEMENT_GOLD_COSTS,
  };
}
