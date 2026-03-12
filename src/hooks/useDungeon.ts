// ============================================================
// useDungeon — Zindan keşfi + çözümleme + ödüller
// Kaynak: DungeonManager.gd (518 satır)
// Server-authoritative: ödüller sunucuda verilir, hastaneye yatış sunucuda yapılır
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";
import { trackEvent } from "@/lib/telemetry";
import type {
  DungeonData,
  DungeonDifficulty,
  DungeonInstance,
  DungeonReward,
} from "@/types/dungeon";

interface SuccessRateBreakdown {
  baseFromPower: number;
  luckBonus: number;
  warriorBonus: number;
  reputationBonus: number;
  ratio: number;
  playerPower: number;
  powerRequirement: number;
  final: number;
}

export function useDungeon() {
  const [availableDungeons, setAvailableDungeons] = useState<DungeonData[]>([]);
  const [activeDungeon, setActiveDungeon] = useState<DungeonInstance | null>(null);
  const [lastRewards, setLastRewards] = useState<DungeonReward[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const energy = usePlayerStore((s) => s.energy);
  const level = usePlayerStore((s) => s.level);
  const updateEnergy = usePlayerStore((s) => s.updateEnergy);
  const addXp = usePlayerStore((s) => s.addXp);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);

  const config = GAME_CONFIG.dungeon;

  /** Fetch available dungeons from server */
  const fetchDungeons = useCallback(async () => {
    setIsLoading(true);
    const res = await api.get<DungeonData[]>(APIEndpoints.DUNGEON_LIST);
    if (res.success && res.data) {
      setAvailableDungeons(Array.isArray(res.data) ? res.data : []);
    }
    setIsLoading(false);
  }, []);

  /** Get energy cost for a difficulty */
  const getEnergyCost = useCallback(
    (difficulty: DungeonDifficulty): number => {
      return (config.energyCosts as Record<string, number>)[difficulty] ?? 10;
    },
    [config]
  );

  /** Client-side success rate preview */
  const previewSuccessRate = useCallback(
    (dungeon: DungeonData): SuccessRateBreakdown => {
      const player = usePlayerStore.getState().player;

      const playerPower = (player?.power ?? 0) > 0
        ? Number(player?.power ?? 0)
        : Math.floor(
            level * 500 +
            Math.floor((player?.reputation ?? 0) * 0.1) +
            Math.floor((player?.luck ?? 0) * 50)
          );

      const inferredPowerReq = dungeon.dungeon_order === 1 ? 0 : Math.max(1, dungeon.required_level * 500);
      const powerRequirement = typeof dungeon.power_requirement === "number"
        ? dungeon.power_requirement
        : inferredPowerReq;

      const ratio = powerRequirement > 0 ? playerPower / powerRequirement : 999;

      let baseFromPower = 0;
      if (powerRequirement === 0) {
        baseFromPower = 1.0;
      } else if (ratio >= 1.5) {
        baseFromPower = 0.95;
      } else if (ratio >= 1.0) {
        baseFromPower = 0.70 + (ratio - 1.0) * 0.50;
      } else if (ratio >= 0.5) {
        baseFromPower = 0.25 + (ratio - 0.5) * 0.90;
      } else if (ratio >= 0.25) {
        baseFromPower = 0.10 + (ratio - 0.25) * 0.60;
      } else {
        baseFromPower = Math.max(0.05, ratio * 0.40);
      }

      const luckBonus = Math.max(0, Math.min(0.05, (player?.luck ?? 0) * 0.001));
      const warriorBonus = (player?.character_class ?? null) === "warrior" ? 0.05 : 0;
      const reputationBonus = Math.max(0, Math.min(0.025, (player?.reputation ?? 0) * 0.0005));

      const final = Math.max(0.05, Math.min(0.95, baseFromPower + luckBonus + warriorBonus + reputationBonus));

      return { baseFromPower, luckBonus, warriorBonus, reputationBonus, ratio, playerPower, powerRequirement, final };
    },
    [level]
  );

  /** Estimate reward range for a dungeon */
  const estimateRewards = useCallback(
    (dungeon: DungeonData) => {
      const levelMultiplier = 1 + (level - dungeon.required_level) * 0.05;
      return {
        goldMin: Math.floor(dungeon.min_gold * levelMultiplier),
        goldMax: Math.floor(dungeon.max_gold * levelMultiplier),
        xp: Math.floor(dungeon.xp_reward * levelMultiplier),
        criticalGoldMax: Math.floor(
          dungeon.max_gold * levelMultiplier * config.criticalSuccessMultiplier
        ),
        lootChance: config.lootDropChance,
      };
    },
    [level, config]
  );

  /** Start a dungeon run — SERVER-AUTHORITATIVE */
  const startDungeon = useCallback(
    async (dungeon: DungeonData): Promise<DungeonInstance | null> => {
      const cost = getEnergyCost(dungeon.difficulty);
      if (energy < cost) {
        addToast(`Yetersiz enerji! (${cost} gerekli)`, "error");
        return null;
      }
      if (activeDungeon) {
        addToast("Zaten aktif bir zindan var!", "warning");
        return null;
      }

      // Prison/hospital check
      const playerStore = usePlayerStore.getState();
      if (playerStore.inPrison) {
        addToast("Hapisteyken zindana giremezsiniz!", "error");
        return null;
      }
      if (playerStore.inHospital) {
        addToast("Hastanedeyken zindana giremezsiniz!", "error");
        return null;
      }

      setIsLoading(true);

      // Try server-side resolution first
      const serverRes = await api.post<{
        success: boolean;
        dungeon_instance: DungeonInstance;
        rewards: DungeonReward[];
        hospitalized: boolean;
        hospital_until?: string;
      }>(APIEndpoints.DUNGEON_START, {
        dungeon_id: dungeon.dungeon_id ?? dungeon.id,
        difficulty: dungeon.difficulty,
      });

      if (serverRes.success && serverRes.data) {
        const data = serverRes.data;
        const instance = data.dungeon_instance ?? {
          id: crypto.randomUUID(),
          dungeon_id: dungeon.dungeon_id ?? dungeon.id,
          player_id: playerStore.profile?.id ?? "",
          difficulty: dungeon.difficulty,
          started_at: new Date().toISOString(),
          completed_at: new Date().toISOString(),
          success: data.success,
          rewards: data.rewards ?? [],
        };

        const rewards = data.rewards ?? instance.rewards ?? [];

        // Update local state from server response
        updateEnergy(energy - cost);

        // Apply rewards
        for (const reward of rewards) {
          if (reward.type === "gold" && reward.amount) {
            updateGold(reward.amount, true);
          } else if (reward.type === "xp" && reward.amount) {
            addXp(reward.amount);
          }
        }

        // Check hospitalization
        if (data.hospitalized && data.hospital_until) {
          addToast("Yenildiniz ve hastaneye kaldırıldınız!", "error");
        } else if (instance.success) {
          addToast("Zindan tamamlandı!", "success");
        } else {
          addToast("Zindan başarısız!", "error");
        }

        setActiveDungeon(instance);
        setLastRewards(rewards);
        setIsLoading(false);

        // Re-fetch inventory (loot may have been added server-side)
        useInventoryStore.getState().fetchInventory();
        // Sync player data
        playerStore.fetchProfile();

        trackEvent("dungeon_run", {
          dungeonId: dungeon.dungeon_id ?? dungeon.id,
          success: instance.success,
          difficulty: dungeon.difficulty,
        });

        return instance;
      }

      // Fallback: client-side resolution (if server endpoint doesn't exist yet)
      const preview = previewSuccessRate(dungeon);
      const roll = Math.random();
      const success = roll <= preview.final;
      const isCritical = success && Math.random() < config.criticalSuccessChance;

      const rewards: DungeonReward[] = [];
      if (success) {
        const baseGold =
          dungeon.min_gold +
          Math.floor(Math.random() * (dungeon.max_gold - dungeon.min_gold));
        const goldMultiplier = isCritical ? config.criticalSuccessMultiplier : 1;
        const goldAmount = Math.floor(baseGold * goldMultiplier);
        const xpAmount = Math.floor(dungeon.xp_reward * (isCritical ? 1.5 : 1));

        rewards.push({ type: "gold", amount: goldAmount });
        rewards.push({ type: "xp", amount: xpAmount });

        updateGold(goldAmount, true);
        addXp(xpAmount);

        // Loot roll
        if (Math.random() < config.lootDropChance && dungeon.loot_table?.length) {
          const lootIndex = Math.floor(Math.random() * dungeon.loot_table.length);
          rewards.push({ type: "item", item_id: dungeon.loot_table[lootIndex] });
        }

        addToast(
          isCritical ? "Kritik Başarı! 🎉" : "Zindan tamamlandı!",
          "success"
        );
      } else {
        // Failure rewards (30% of normal)
        const failGold = Math.floor(dungeon.min_gold * config.failureRewardPercent);
        const failXp = Math.floor(dungeon.xp_reward * config.failureRewardPercent);
        if (failGold > 0) rewards.push({ type: "gold", amount: failGold });
        if (failXp > 0) rewards.push({ type: "xp", amount: failXp });
        updateGold(failGold, true);
        addXp(failXp);

        // Hospitalization check on failure
        const hospRate =
          (config.hospitalizationRates as Record<string, number>)[
            dungeon.difficulty
          ] ?? 0;
        if (hospRate > 0 && Math.random() < hospRate) {
          // Request hospitalization from server
          const hospDurations = (config.hospitalDurationMinutes as unknown as Record<string, number[]>)[dungeon.difficulty];
          const duration = hospDurations
            ? hospDurations[0] + Math.floor(Math.random() * (hospDurations[1] - hospDurations[0]))
            : 120;

          await api.post(APIEndpoints.HOSPITAL_ADMIT, {
            p_reason: "dungeon_defeat",
            p_duration_minutes: duration,
          });
          addToast("Yenildiniz ve hastaneye kaldırıldınız!", "error");
          playerStore.fetchProfile(); // Refresh hospital status
        } else {
          addToast("Zindan başarısız!", "error");
        }
      }

      updateEnergy(energy - cost);

      const instance: DungeonInstance = {
        id: crypto.randomUUID(),
        dungeon_id: dungeon.dungeon_id ?? dungeon.id,
        player_id: playerStore.profile?.id ?? "",
        difficulty: dungeon.difficulty,
        started_at: new Date().toISOString(),
        completed_at: new Date().toISOString(),
        success,
        rewards,
      };

      setActiveDungeon(instance);
      setLastRewards(rewards);
      setIsLoading(false);

      trackEvent("dungeon_run", {
        dungeonId: dungeon.dungeon_id ?? dungeon.id,
        success,
        difficulty: dungeon.difficulty,
      });

      // Sync player state back
      playerStore.syncToSupabase?.();

      return instance;
    },
    [
      energy,
      activeDungeon,
      getEnergyCost,
      previewSuccessRate,
      updateEnergy,
      updateGold,
      addXp,
      addToast,
      config,
    ]
  );

  /** Clear active dungeon (after reward collection) */
  const clearDungeon = useCallback(() => {
    setActiveDungeon(null);
    setLastRewards([]);
  }, []);

  return {
    availableDungeons,
    activeDungeon,
    lastRewards,
    isLoading,
    fetchDungeons,
    getEnergyCost,
    previewSuccessRate,
    estimateRewards,
    startDungeon,
    clearDungeon,
  };
}
