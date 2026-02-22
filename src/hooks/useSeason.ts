// ============================================================
// useSeason — Sezon sistemi + Battle Pass + Sıralama
// Kaynak: SeasonManager.gd (269 satır)
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";

export type LeaderboardCategory = "level" | "power" | "pvp_rating" | "gold" | "guild_power";

export interface SeasonInfo {
  id: string;
  name: string;
  start_date: string;
  end_date: string;
  is_active: boolean;
}

export interface LeaderboardEntry {
  rank: number;
  player_id: string;
  username: string;
  value: number;
  level: number;
  guild_name: string | null;
}

export interface BattlePassInfo {
  currentTier: number;
  currentXp: number;
  xpPerTier: number;
  maxTiers: number;
  isPremium: boolean;
  claimedRewards: number[];
}

const BATTLE_PASS_TIERS = 100;
const XP_PER_TIER = 1000;

export function useSeason() {
  const [season, setSeason] = useState<SeasonInfo | null>(null);
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [playerRank, setPlayerRank] = useState<number | null>(null);
  const [battlePass, setBattlePass] = useState<BattlePassInfo>({
    currentTier: 0,
    currentXp: 0,
    xpPerTier: XP_PER_TIER,
    maxTiers: BATTLE_PASS_TIERS,
    isPremium: false,
    claimedRewards: [],
  });
  const [isLoading, setIsLoading] = useState(false);

  const addToast = useUiStore((s) => s.addToast);
  const player = usePlayerStore((s) => s.player);

  const config = GAME_CONFIG.season;

  /** Days remaining in season */
  const daysRemaining = season
    ? Math.max(0, Math.ceil((new Date(season.end_date).getTime() - Date.now()) / 86400000))
    : 0;

  /** Fetch current season */
  const fetchSeason = useCallback(async () => {
    setIsLoading(true);
    const res = await api.get<SeasonInfo>(APIEndpoints.SEASON_CURRENT);
    if (res.success && res.data) setSeason(res.data);
    setIsLoading(false);
  }, []);

  /** Fetch leaderboard */
  const fetchLeaderboard = useCallback(
    async (category: LeaderboardCategory, limit = 50, offset = 0) => {
      setIsLoading(true);
      const res = await api.get<LeaderboardEntry[]>(
        `${APIEndpoints.SEASON_LEADERBOARD}?category=${category}&limit=${limit}&offset=${offset}`
      );
      if (res.success && res.data) setLeaderboard(res.data);
      setIsLoading(false);
    },
    []
  );

  /** Get player rank in category */
  const fetchPlayerRank = useCallback(
    async (category: LeaderboardCategory) => {
      const res = await api.get<{ rank: number }>(
        `${APIEndpoints.SEASON_RANK}?category=${category}`
      );
      if (res.success && res.data) setPlayerRank(res.data.rank);
    },
    []
  );

  /** Get battle pass progress */
  const fetchBattlePass = useCallback(async () => {
    const res = await api.get<BattlePassInfo>(APIEndpoints.SEASON_BATTLE_PASS);
    if (res.success && res.data) setBattlePass(res.data);
  }, []);

  /** Add battle pass XP */
  const addBattlePassXp = useCallback(
    (amount: number) => {
      setBattlePass((prev) => {
        let xp = prev.currentXp + amount;
        let tier = prev.currentTier;
        while (xp >= XP_PER_TIER && tier < BATTLE_PASS_TIERS) {
          xp -= XP_PER_TIER;
          tier++;
        }
        return { ...prev, currentXp: xp, currentTier: tier };
      });
    },
    []
  );

  /** Claim battle pass reward */
  const claimReward = useCallback(
    async (tier: number): Promise<boolean> => {
      if (tier > battlePass.currentTier) {
        addToast("Bu seviyeye henüz ulaşmadınız!", "warning");
        return false;
      }
      if (battlePass.claimedRewards.includes(tier)) {
        addToast("Bu ödül zaten alındı!", "warning");
        return false;
      }

      const res = await api.post(APIEndpoints.SEASON_CLAIM_REWARD, { tier });
      if (res.success) {
        setBattlePass((prev) => ({
          ...prev,
          claimedRewards: [...prev.claimedRewards, tier],
        }));
        addToast(`Tier ${tier} ödülü alındı!`, "success");
        return true;
      }
      addToast(res.error ?? "Ödül alınamadı", "error");
      return false;
    },
    [battlePass, addToast]
  );

  /** Purchase premium battle pass */
  const purchasePremiumPass = useCallback(async (): Promise<boolean> => {
    const res = await api.post(APIEndpoints.SEASON_PURCHASE_PASS);
    if (res.success) {
      setBattlePass((prev) => ({ ...prev, isPremium: true }));
      addToast("Premium Battle Pass satın alındı!", "success");
      return true;
    }
    addToast(res.error ?? "Satın alma başarısız", "error");
    return false;
  }, [addToast]);

  /** Get rewards for a specific rank tier */
  const getSeasonRewards = useCallback(
    (rank: number) => {
      for (const tier of config.rewardsTiers) {
        if (rank <= tier.rank) {
          return tier;
        }
      }
      return null;
    },
    [config]
  );

  /** Battle pass progress percentage */
  const battlePassProgress =
    battlePass.maxTiers > 0
      ? ((battlePass.currentTier * XP_PER_TIER + battlePass.currentXp) /
          (battlePass.maxTiers * XP_PER_TIER)) *
        100
      : 0;

  return {
    season,
    leaderboard,
    playerRank,
    battlePass,
    battlePassProgress,
    daysRemaining,
    isLoading,
    fetchSeason,
    fetchLeaderboard,
    fetchPlayerRank,
    fetchBattlePass,
    addBattlePassXp,
    claimReward,
    purchasePremiumPass,
    getSeasonRewards,
  };
}
