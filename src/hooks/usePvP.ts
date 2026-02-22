// ============================================================
// usePvP — PvP saldırı, liderlik tablosu, geçmiş
// Kaynak: PvpManager.gd (154 satır)
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";
import { trackPvPCompleted } from "@/lib/telemetry";
import type { PvPTarget, PvPResult, PvPHistoryEntry } from "@/types/pvp";

const REPUTATION_TIERS = [
  { min: -Infinity, max: -50, name: "Kötü Şöhretli", color: "#dc2626" },
  { min: -50, max: -20, name: "Haydut", color: "#ef4444" },
  { min: -20, max: 0, name: "Şüpheli", color: "#f97316" },
  { min: 0, max: 50, name: "Vatandaş", color: "#9ca3af" },
  { min: 50, max: 200, name: "Saygın", color: "#3b82f6" },
  { min: 200, max: 1000, name: "Kahraman", color: "#a855f7" },
  { min: 1000, max: Infinity, name: "Efsanevi", color: "#eab308" },
];

export function usePvP() {
  const [targets, setTargets] = useState<PvPTarget[]>([]);
  const [history, setHistory] = useState<PvPHistoryEntry[]>([]);
  const [leaderboard, setLeaderboard] = useState<PvPTarget[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [lastAttackTime, setLastAttackTime] = useState<number>(0);

  const player = usePlayerStore((s) => s.player);
  const energy = usePlayerStore((s) => s.energy);
  const pvpRating = usePlayerStore((s) => s.pvpRating);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);
  const addToast = useUiStore((s) => s.addToast);

  const { energyCost, goldStealPercentage } = GAME_CONFIG.pvp;

  /** Win chance preview (client-side estimate) */
  const calculateWinChance = useCallback(
    (targetPower: number): number => {
      const myPower = (player?.level ?? 1) * 10;
      const diff = myPower - targetPower;
      const base = 0.5;
      const factor = 0.005;
      return Math.max(0.05, Math.min(0.95, base + diff * factor));
    },
    [player]
  );

  /** Reputation tier */
  const getReputationTier = useCallback(
    (reputation?: number) => {
      const rep = reputation ?? (player as unknown as Record<string, unknown>)?.reputation as number ?? 0;
      return REPUTATION_TIERS.find((t) => rep >= t.min && rep < t.max) ?? REPUTATION_TIERS[3];
    },
    [player]
  );

  /** Fetch PvP targets */
  const fetchTargets = useCallback(async () => {
    setIsLoading(true);
    const res = await api.get<PvPTarget[]>(APIEndpoints.PVP_LIST_TARGETS);
    if (res.success && res.data) {
      setTargets(res.data);
    }
    setIsLoading(false);
  }, []);

  /** Attack a target */
  const attackPlayer = useCallback(
    async (targetId: string): Promise<PvPResult | null> => {
      if (energy < energyCost) {
        addToast(`Yetersiz enerji! (${energyCost} gerekli)`, "error");
        return null;
      }

      // Cooldown check
      const cooldown = GAME_CONFIG.pvp.maxAttacksPerDay; // simplified
      const now = Date.now();
      if (now - lastAttackTime < 5000) {
        addToast("Çok hızlı saldırıyorsunuz!", "warning");
        return null;
      }

      setIsLoading(true);
      const res = await api.post<PvPResult>(APIEndpoints.PVP_ATTACK, {
        target_player_id: targetId,
      });
      setIsLoading(false);

      if (res.success && res.data) {
        setLastAttackTime(now);
        consumeEnergy(energyCost);
        const result = res.data;
        if (result.won) {
          addToast(
            `Zafer! +${result.gold_stolen} altın, +${result.rating_change} rating`,
            "success"
          );
        } else {
          addToast(
            `Yenilgi! ${result.rating_change} rating`,
            "error"
          );
        }
        trackPvPCompleted(result.won ? "win" : "loss", result.rating_change);
        // Refresh player profile from server (gold, rating updates)
        fetchProfile();
        return result;
      }

      addToast(res.error ?? "Saldırı başarısız", "error");
      return null;
    },
    [energy, energyCost, lastAttackTime, consumeEnergy, fetchProfile, addToast]
  );

  /** Revenge attack (from history) */
  const revengeAttack = useCallback(
    async (targetId: string): Promise<PvPResult | null> => {
      if (energy < energyCost) {
        addToast(`Yetersiz enerji! (${energyCost} gerekli)`, "error");
        return null;
      }
      setIsLoading(true);
      const res = await api.post<PvPResult>(APIEndpoints.PVP_REVENGE, {
        target_player_id: targetId,
      });
      setIsLoading(false);

      if (res.success && res.data) {
        consumeEnergy(energyCost);
        const result = res.data;
        addToast(
          result.won
            ? `İntikam! +${result.gold_stolen} altın`
            : `İntikam başarısız! ${result.rating_change} rating`,
          result.won ? "success" : "error"
        );
        trackPvPCompleted(result.won ? "win" : "loss", result.rating_change);
        fetchProfile();
        return result;
      }
      addToast(res.error ?? "İntikam saldırısı başarısız", "error");
      return null;
    },
    [energy, energyCost, consumeEnergy, fetchProfile, addToast]
  );

  /** Fetch PvP history */
  const fetchHistory = useCallback(async (limit = 20) => {
    const res = await api.get<PvPHistoryEntry[]>(
      `${APIEndpoints.PVP_HISTORY}?limit=${limit}`
    );
    if (res.success && res.data) {
      setHistory(res.data);
    }
  }, []);

  /** Fetch leaderboard */
  const fetchLeaderboard = useCallback(async (limit = 50) => {
    const res = await api.get<PvPTarget[]>(
      `${APIEndpoints.PVP_LEADERBOARD}?limit=${limit}`
    );
    if (res.success && res.data) {
      setLeaderboard(res.data);
    }
  }, []);

  return {
    targets,
    history,
    leaderboard,
    isLoading,
    pvpRating,
    energyCost,
    goldStealPercentage,
    calculateWinChance,
    getReputationTier,
    fetchTargets,
    attackPlayer,
    revengeAttack,
    fetchHistory,
    fetchLeaderboard,
  };
}
