// ============================================================
// usePvP — PvP saldırı, liderlik tablosu, geçmiş
// Kaynak: PvpManager.gd (154 satır)
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { supabase } from "@/lib/supabase";
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
    const { data, error } = await supabase
      .from("users")
      .select("auth_id, username, level, pvp_rating")
      .neq("auth_id", player?.auth_id ?? "")
      .gte("level", 1)
      .order("pvp_rating", { ascending: false })
      .limit(20);
    if (!error && data) {
      setTargets(
        data.map((u) => ({
          id: u.auth_id,
          player_id: u.auth_id,
          username: u.username ?? "Bilinmeyen",
          level: u.level ?? 1,
          power: (u.level ?? 1) * 10,
          pvp_rating: u.pvp_rating ?? 1000,
          rating: u.pvp_rating ?? 1000,
          attack: 0,
          defense: 0,
          health: 100,
          estimated_gold: 0,
          guild_name: null,
        }) as PvPTarget)
      );
    }
    setIsLoading(false);
  }, [player?.auth_id]);

  /** Attack a target */
  const attackPlayer = useCallback(
    async (targetId: string, mekanId: string): Promise<PvPResult | null> => {
      if (energy < energyCost) {
        addToast(`Yetersiz enerji! (${energyCost} gerekli)`, "error");
        return null;
      }

      // Cooldown check
      const now = Date.now();
      if (now - lastAttackTime < 5000) {
        addToast("Çok hızlı saldırıyorsunuz!", "warning");
        return null;
      }

      if (!player?.auth_id) {
        addToast("Oturum bulunamadı!", "error");
        return null;
      }

      setIsLoading(true);
      const { data, error } = await supabase.rpc("pvp_attack", {
        p_attacker_id: player.auth_id,
        p_defender_id: targetId,
        p_mekan_id: mekanId,
      });
      setIsLoading(false);

      if (!error && data) {
        setLastAttackTime(now);
        consumeEnergy(energyCost);
        const rpcResult = data as {
          success: boolean;
          winner_id: string;
          gold_stolen: number;
          rep_change_winner: number;
          rep_change_loser: number;
          rating_change_attacker: number;
          hospital_triggered: boolean;
        };
        const won = rpcResult.winner_id === player.auth_id;
        const result: PvPResult = {
          success: rpcResult.success,
          won,
          opponent_name: "",
          attacker_damage: 0,
          defender_damage: 0,
          gold_stolen: rpcResult.gold_stolen,
          gold_change: won ? rpcResult.gold_stolen : -rpcResult.gold_stolen,
          rating_change: rpcResult.rating_change_attacker,
          is_critical: false,
          defender_hospitalized: rpcResult.hospital_triggered,
        };
        if (won) {
          addToast(`Zafer! +${result.gold_stolen} altın, +${result.rating_change} rating`, "success");
        } else {
          addToast(`Yenilgi! ${result.rating_change} rating`, "error");
        }
        trackPvPCompleted(won ? "win" : "loss", result.rating_change);
        fetchProfile();
        return result;
      }

      addToast("Saldırı başarısız", "error");
      return null;
    },
    [energy, energyCost, lastAttackTime, player?.auth_id, consumeEnergy, fetchProfile, addToast]
  );

  /** Revenge attack (from history) */
  const revengeAttack = useCallback(
    async (targetId: string, mekanId: string): Promise<PvPResult | null> => {
      if (energy < energyCost) {
        addToast(`Yetersiz enerji! (${energyCost} gerekli)`, "error");
        return null;
      }
      if (!player?.auth_id) {
        addToast("Oturum bulunamadı!", "error");
        return null;
      }
      setIsLoading(true);
      const { data, error } = await supabase.rpc("pvp_attack", {
        p_attacker_id: player.auth_id,
        p_defender_id: targetId,
        p_mekan_id: mekanId,
      });
      setIsLoading(false);

      if (!error && data) {
        consumeEnergy(energyCost);
        const rpcResult = data as {
          success: boolean;
          winner_id: string;
          gold_stolen: number;
          rating_change_attacker: number;
          hospital_triggered: boolean;
        };
        const won = rpcResult.winner_id === player.auth_id;
        const result: PvPResult = {
          success: rpcResult.success,
          won,
          opponent_name: "",
          attacker_damage: 0,
          defender_damage: 0,
          gold_stolen: rpcResult.gold_stolen,
          gold_change: won ? rpcResult.gold_stolen : -rpcResult.gold_stolen,
          rating_change: rpcResult.rating_change_attacker,
          is_critical: false,
          defender_hospitalized: rpcResult.hospital_triggered,
        };
        addToast(
          won ? `İntikam! +${result.gold_stolen} altın` : `İntikam başarısız! ${result.rating_change} rating`,
          won ? "success" : "error"
        );
        trackPvPCompleted(won ? "win" : "loss", result.rating_change);
        fetchProfile();
        return result;
      }
      addToast("İntikam saldırısı başarısız", "error");
      return null;
    },
    [energy, energyCost, player?.auth_id, consumeEnergy, fetchProfile, addToast]
  );

  /** Fetch PvP history */
  const fetchHistory = useCallback(async (limit = 20) => {
    const authId = player?.auth_id;
    if (!authId) return;
    const { data, error } = await supabase
      .from("pvp_matches")
      .select("id, attacker_id, defender_id, winner_id, gold_stolen, rep_change_winner, rep_change_loser, rating_change_attacker, created_at")
      .or(`attacker_id.eq.${authId},defender_id.eq.${authId}`)
      .order("created_at", { ascending: false })
      .limit(limit);
    if (!error && data) {
      setHistory(
        data.map((m) => {
          const isAttacker = m.attacker_id === authId;
          const won = m.winner_id === authId;
          return {
            id: m.id,
            opponent_id: isAttacker ? m.defender_id : m.attacker_id,
            opponent_name: "",
            opponent_username: "",
            is_attacker: isAttacker,
            won,
            result: won ? "win" : "loss",
            gold_change: won ? m.gold_stolen : -m.gold_stolen,
            rating_change: m.rating_change_attacker,
            timestamp: m.created_at,
            created_at: m.created_at,
            battle_log: [],
          } as PvPHistoryEntry;
        })
      );
    }
  }, [player?.auth_id]);

  /** Fetch leaderboard */
  const fetchLeaderboard = useCallback(async (limit = 50) => {
    const { data, error } = await supabase
      .from("users")
      .select("auth_id, username, level, pvp_rating")
      .order("pvp_rating", { ascending: false })
      .limit(limit);
    if (!error && data) {
      setLeaderboard(
        data.map((u) => ({
          id: u.auth_id,
          player_id: u.auth_id,
          username: u.username ?? "Bilinmeyen",
          level: u.level ?? 1,
          power: (u.level ?? 1) * 10,
          pvp_rating: u.pvp_rating ?? 1000,
          rating: u.pvp_rating ?? 1000,
          attack: 0,
          defense: 0,
          health: 100,
          estimated_gold: 0,
          guild_name: null,
        }) as PvPTarget)
      );
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
