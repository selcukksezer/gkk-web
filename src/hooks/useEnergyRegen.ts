// ============================================================
// useEnergyRegen — Enerji yenilenme hook'u
// Kaynak: energy config → regen_interval: 180s
// ============================================================

"use client";

import { useEffect, useRef } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { GAME_CONFIG } from "@/data/GameConstants";

/**
 * Enerji yenilenme timer'ı. Her 180 saniyede +1 enerji.
 */
export function useEnergyRegen() {
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const updateEnergy = usePlayerStore((s) => s.updateEnergy);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    // Don't regen if at max
    if (energy >= maxEnergy) {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
      return;
    }

    intervalRef.current = setInterval(() => {
      const current = usePlayerStore.getState().energy;
      const max = usePlayerStore.getState().maxEnergy;
      if (current < max) {
        updateEnergy(
          Math.min(current + GAME_CONFIG.energy.regenRate, max)
        );
      }
    }, GAME_CONFIG.energy.regenInterval * 1000);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [energy, maxEnergy, updateEnergy]);
}
