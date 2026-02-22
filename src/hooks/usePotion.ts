// ============================================================
// usePotion — İksir kullanımı + tolerans sistemi
// Kaynak: PotionManager.gd (165 satır)
// ============================================================

"use client";

import { useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";
import { trackPotionUsage } from "@/lib/telemetry";
import type { ItemData } from "@/types/item";

export interface PotionResult {
  success: boolean;
  energyRestored: number;
  overdosed: boolean;
  toleranceIncrease: number;
  message: string;
}

export function usePotion() {
  const tolerance = usePlayerStore((s) => s.tolerance);
  const updateTolerance = usePlayerStore((s) => s.updateTolerance);
  const updateEnergy = usePlayerStore((s) => s.updateEnergy);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const addToast = useUiStore((s) => s.addToast);
  const removeItem = useInventoryStore((s) => s.removeItem);

  const { maxTolerance, overdoseBaseRisk } = GAME_CONFIG.potion;

  /** Potion effectiveness multiplier (0.5 – 1.0) based on tolerance */
  const getEffectiveness = useCallback((): number => {
    return 1 - (tolerance / maxTolerance) * 0.5;
  }, [tolerance, maxTolerance]);

  /** Tolerance tier: 0-4 (Düşük → Kritik) */
  const getToleranceTier = useCallback((): { tier: number; name: string; color: string } => {
    const pct = tolerance / maxTolerance;
    if (pct < 0.25) return { tier: 0, name: "Düşük", color: "#4ade80" };
    if (pct < 0.5) return { tier: 1, name: "Orta", color: "#facc15" };
    if (pct < 0.75) return { tier: 2, name: "Yüksek", color: "#f97316" };
    if (pct < 0.9) return { tier: 3, name: "Tehlikeli", color: "#ef4444" };
    return { tier: 4, name: "Kritik", color: "#dc2626" };
  }, [tolerance, maxTolerance]);

  const tolerancePercent = (tolerance / maxTolerance) * 100;

  /** Overdose risk check */
  const checkOverdose = useCallback(
    (baseRisk: number): boolean => {
      const finalRisk = baseRisk * (1 + tolerance / maxTolerance);
      return Math.random() < finalRisk;
    },
    [tolerance, maxTolerance]
  );

  /** Consume a potion item */
  const consumePotion = useCallback(
    async (potion: ItemData): Promise<PotionResult> => {
      const baseEnergy = potion.energy_restore ?? 0;
      const toleranceInc = potion.tolerance_increase ?? 5;
      const overdoseRisk = potion.overdose_risk ?? overdoseBaseRisk;

      // Check overdose
      if (checkOverdose(overdoseRisk)) {
        // Overdose → hospital
        const res = await api.post(APIEndpoints.HOSPITAL_ADMIT, {
          p_reason: "overdose",
          p_duration_minutes: 120,
        });
        if (res.success) {
          updateTolerance(Math.min(tolerance + toleranceInc * 2, maxTolerance));
        }
        addToast("Doz aşımı! Hastaneye kaldırıldınız!", "error");
        trackPotionUsage(potion.item_id, "overdose");
        return {
          success: false,
          energyRestored: 0,
          overdosed: true,
          toleranceIncrease: toleranceInc * 2,
          message: "Doz aşımı! Hastaneye kaldırıldınız!",
        };
      }

      // Normal consumption
      const effectiveness = getEffectiveness();
      const effectiveEnergy = Math.floor(baseEnergy * effectiveness);
      const newEnergy = Math.min(energy + effectiveEnergy, maxEnergy);

      const res = await api.post(APIEndpoints.POTION_USE, {
        item_id: potion.item_id,
      });

      if (res.success) {
        updateEnergy(newEnergy);
        updateTolerance(Math.min(tolerance + toleranceInc, maxTolerance));
        removeItem(potion.item_id);
        addToast(`+${effectiveEnergy} enerji (${Math.round(effectiveness * 100)}% etkinlik)`, "success");
        trackPotionUsage(potion.item_id, "success");
      } else {
        addToast(res.error ?? "İksir kullanılamadı", "error");
      }

      return {
        success: res.success,
        energyRestored: effectiveEnergy,
        overdosed: false,
        toleranceIncrease: toleranceInc,
        message: res.success
          ? `+${effectiveEnergy} enerji`
          : (res.error ?? "Hata"),
      };
    },
    [
      tolerance,
      maxTolerance,
      energy,
      maxEnergy,
      overdoseBaseRisk,
      checkOverdose,
      getEffectiveness,
      updateEnergy,
      updateTolerance,
      removeItem,
      addToast,
    ]
  );

  return {
    tolerance,
    maxTolerance,
    tolerancePercent,
    getEffectiveness,
    getToleranceTier,
    consumePotion,
    checkOverdose,
  };
}
