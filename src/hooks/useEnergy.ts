// ============================================================
// useEnergy — Enerji yönetimi hook'u
// Kaynak: EnergyManager.gd (139 satır)
// ============================================================

"use client";

import { useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";
import { trackEvent } from "@/lib/telemetry";

export function useEnergy() {
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const updateEnergy = usePlayerStore((s) => s.updateEnergy);
  const gems = usePlayerStore((s) => s.gems);
  const updateGems = usePlayerStore((s) => s.updateGems);
  const syncToSupabase = usePlayerStore((s) => s.syncToSupabase);
  const addToast = useUiStore((s) => s.addToast);

  /** Fetch authoritative energy from server */
  const fetchEnergyStatus = useCallback(async () => {
    const res = await api.get<{ energy: number; max_energy: number }>(
      APIEndpoints.ENERGY_STATUS
    );
    if (res.success && res.data) {
      updateEnergy(res.data.energy, res.data.max_energy);
    }
  }, [updateEnergy]);

  const hasEnergy = useCallback(
    (amount: number) => energy >= amount,
    [energy]
  );

  const consumeEnergy = useCallback(
    (amount: number, reason?: string): boolean => {
      if (energy < amount) {
        addToast("Yetersiz enerji!", "error");
        return false;
      }
      updateEnergy(energy - amount);
      trackEvent("energy_consume", { reason: reason ?? "unknown", amount });
      // Sync to server after local update
      syncToSupabase();
      return true;
    },
    [energy, updateEnergy, syncToSupabase, addToast]
  );

  const addEnergy = useCallback(
    (amount: number, reason?: string) => {
      const newEnergy = Math.min(energy + amount, maxEnergy);
      updateEnergy(newEnergy);
      trackEvent("energy_add", { reason: reason ?? "regen", amount });
    },
    [energy, maxEnergy, updateEnergy]
  );

  const refillEnergy = useCallback(async (): Promise<boolean> => {
    const cost = GAME_CONFIG.energy.refillCostGems;
    if (gems < cost) {
      addToast("Yetersiz gem!", "error");
      return false;
    }
    const res = await api.post(APIEndpoints.ENERGY_REFILL);
    if (res.success) {
      updateEnergy(maxEnergy);
      updateGems(gems - cost);
      addToast("Enerji dolduruldu!", "success");
      return true;
    }
    addToast(res.error ?? "Enerji doldurulamadı", "error");
    return false;
  }, [gems, maxEnergy, updateEnergy, updateGems, addToast]);

  const timeToNextRegen = useCallback(() => {
    if (energy >= maxEnergy) return 0;
    return GAME_CONFIG.energy.regenInterval;
  }, [energy, maxEnergy]);

  const energyPercent = maxEnergy > 0 ? (energy / maxEnergy) * 100 : 0;

  return {
    energy,
    maxEnergy,
    energyPercent,
    hasEnergy,
    consumeEnergy,
    addEnergy,
    refillEnergy,
    timeToNextRegen,
    regenInterval: GAME_CONFIG.energy.regenInterval,
    refillCost: GAME_CONFIG.energy.refillCostGems,
  };
}
