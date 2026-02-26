// ============================================================
// useEnhancement — Ekipman geliştirme (upgrade) sistemi
// Kaynak: EnhancementManager.gd (318 satır)
// Server-authoritative: upgrade_item_enhancement RPC çağrılır
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { GAME_CONFIG } from "@/data/GameConstants";
import { trackEnhancement } from "@/lib/telemetry";
import type { InventoryItem } from "@/types/inventory";

type RuneType = "none" | "basic" | "advanced" | "superior" | "legendary" | "protection";

interface RuneInfo {
  type: RuneType;
  successBonus: number;
  destructionReduction: number;
  cost: number;
}

const RUNES: Record<RuneType, RuneInfo> = {
  none: { type: "none", successBonus: 0, destructionReduction: 0, cost: 0 },
  basic: { type: "basic", successBonus: 0.05, destructionReduction: 0, cost: 500 },
  advanced: { type: "advanced", successBonus: 0.1, destructionReduction: 0, cost: 2000 },
  superior: { type: "superior", successBonus: 0.15, destructionReduction: 0.5, cost: 5000 },
  legendary: { type: "legendary", successBonus: 0.25, destructionReduction: 0.75, cost: 15000 },
  protection: { type: "protection", successBonus: 0, destructionReduction: 1.0, cost: 25000 },
};

const ENHANCEMENT_GOLD_COSTS = [100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200];

export function useEnhancement() {
  const [isEnhancing, setIsEnhancing] = useState(false);
  const [lastResult, setLastResult] = useState<{
    success: boolean;
    destroyed: boolean;
    newLevel: number;
  } | null>(null);

  const gold = usePlayerStore((s) => s.gold);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);
  const items = useInventoryStore((s) => s.items);
  const removeItem = useInventoryStore((s) => s.removeItem);
  const updateItemEnhancement = useInventoryStore((s) => s.updateItemEnhancement);
  const removeItemByRowId = useInventoryStore((s) => s.removeItemByRowId);

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
    (currentLevel: number, rune: RuneType = "none") => {
      const goldCost =
        ENHANCEMENT_GOLD_COSTS[currentLevel] ?? ENHANCEMENT_GOLD_COSTS[ENHANCEMENT_GOLD_COSTS.length - 1];
      const runeCost = RUNES[rune].cost;
      return { gold: goldCost, rune: runeCost, total: goldCost + runeCost };
    },
    []
  );

  /** Get required scroll ID by item rarity */
  const getRequiredScroll = useCallback(
    (rarity: string): string => {
      // Use same IDs as ItemDatabase (scroll_upgrade_low / scroll_upgrade_middle / scroll_upgrade_high)
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
    (currentLevel: number, rune: RuneType = "none") => {
      return {
        successRate: getSuccessRate(currentLevel, rune),
        destructionRate: getDestructionRate(currentLevel, rune),
        cost: getCost(currentLevel, rune),
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
      const currentLevel = item.enhancement_level ?? 0;
      const { total } = getCost(currentLevel, rune);

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

      setIsEnhancing(true);

      // Client-side roll (same logic as Godot — server validates via RPC)
      const successRate = getSuccessRate(currentLevel, rune);
      const destroyRate = getDestructionRate(currentLevel, rune);
      const roll = Math.random();
      const success = roll <= successRate;
      let destroyed = false;
      let newLevel = currentLevel;

      if (success) {
        newLevel = currentLevel + 1;
      } else {
        // Check destruction
        if (Math.random() < destroyRate) {
          destroyed = true;
        } else {
          // Level drops by 1 (minimum 0)
          newLevel = Math.max(0, currentLevel - 1);
        }
      }

      // Consume gold
      updateGold(gold - total);

      // Consume scroll (1 per attempt)
      await removeItem(scrollId, 1);

      // Persist to server via RPC
      if (destroyed) {
        // Remove the item entirely via server
        await removeItemByRowId(item.row_id);
        addToast("Geliştirme başarısız — eşya yok edildi!", "error");
      } else {
        // Update enhancement level on server
        const serverOk = await updateItemEnhancement(item.row_id, newLevel);
        if (!serverOk) {
          addToast("Sunucu hatası — geliştirme kaydedilemedi", "error");
          setIsEnhancing(false);
          return { success: false, destroyed: false, newLevel: currentLevel };
        }

        if (success) {
          addToast(`Geliştirme başarılı! +${newLevel}`, "success");
        } else {
          addToast(`Geliştirme başarısız! Seviye ${newLevel}'a düştü`, "warning");
        }
      }

      const result = { success, destroyed, newLevel };
      setLastResult(result);
      setIsEnhancing(false);

      trackEnhancement(
        item.item_id,
        currentLevel,
        destroyed ? "destroy" : success ? "success" : "fail"
      );

      // Sync player gold to server
      const playerStore = usePlayerStore.getState();
      playerStore.syncToSupabase?.();

      return result;
    },
    [gold, updateGold, getSuccessRate, getDestructionRate, getCost, getRequiredScroll, items, removeItem, removeItemByRowId, updateItemEnhancement, addToast]
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
