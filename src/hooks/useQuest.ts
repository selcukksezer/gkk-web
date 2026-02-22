// ============================================================
// useQuest — Görev sistemi hook'u
// Kaynak: QuestManager.gd (179 satır)
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";
import { trackEvent, trackQuestCompleted } from "@/lib/telemetry";
import type { QuestData, QuestDifficulty } from "@/types/quest";

export function useQuest() {
  const [availableQuests, setAvailableQuests] = useState<QuestData[]>([]);
  const [activeQuests, setActiveQuests] = useState<QuestData[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const level = usePlayerStore((s) => s.level);
  const energy = usePlayerStore((s) => s.energy);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const addToast = useUiStore((s) => s.addToast);

  const config = GAME_CONFIG.quest;

  /** Get energy cost for difficulty */
  const getEnergyCost = useCallback(
    (difficulty: QuestDifficulty): number => {
      return (config.energyCosts as Record<string, number>)[difficulty] ?? 5;
    },
    [config]
  );

  /** Check if quest is available for player */
  const isQuestAvailable = useCallback(
    (quest: QuestData): boolean => {
      if (quest.required_level > level) return false;
      if (activeQuests.length >= config.maxActiveQuests) return false;
      if (activeQuests.some((q) => q.quest_id === quest.quest_id)) return false;
      return true;
    },
    [level, activeQuests, config.maxActiveQuests]
  );

  /** Fetch available quests */
  const fetchAvailableQuests = useCallback(async () => {
    setIsLoading(true);
    const res = await api.get<QuestData[]>(APIEndpoints.QUEST_LIST);
    if (res.success && res.data) {
      setAvailableQuests(res.data);
    }
    setIsLoading(false);
  }, []);

  /** Fetch active quests */
  const fetchActiveQuests = useCallback(async () => {
    const res = await api.get<QuestData[]>(`${APIEndpoints.QUEST_LIST}?status=active`);
    if (res.success && res.data) {
      setActiveQuests(res.data);
    }
  }, []);

  /** Start a quest */
  const startQuest = useCallback(
    async (questId: string, difficulty?: QuestDifficulty): Promise<boolean> => {
      const cost = getEnergyCost(difficulty ?? "easy");
      if (energy < cost) {
        addToast(`Yetersiz enerji! (${cost} gerekli)`, "error");
        return false;
      }
      if (activeQuests.length >= config.maxActiveQuests) {
        addToast(`Maksimum aktif görev sayısına ulaştınız (${config.maxActiveQuests})`, "warning");
        return false;
      }

      setIsLoading(true);
      const res = await api.post<QuestData>(APIEndpoints.QUEST_START, {
        quest_id: questId,
        difficulty: difficulty ?? "easy",
      });
      setIsLoading(false);

      if (res.success && res.data) {
        consumeEnergy(cost);
        setActiveQuests((prev) => [...prev, res.data!]);
        addToast("Görev başlatıldı!", "success");
        trackEvent("quest_start", { questId });
        return true;
      }
      addToast(res.error ?? "Görev başlatılamadı", "error");
      return false;
    },
    [energy, activeQuests, config.maxActiveQuests, getEnergyCost, addToast]
  );

  /** Complete a quest */
  const completeQuest = useCallback(
    async (questId: string): Promise<boolean> => {
      setIsLoading(true);
      const res = await api.post<{ gold: number; xp: number; items: string[] }>(
        APIEndpoints.QUEST_COMPLETE,
        { quest_id: questId }
      );
      setIsLoading(false);

      if (res.success && res.data) {
        setActiveQuests((prev) => prev.filter((q) => q.quest_id !== questId));
        addToast(
          `Görev tamamlandı! +${res.data.gold} altın, +${res.data.xp} XP`,
          "success"
        );
        trackQuestCompleted(questId, "unknown");
        return true;
      }
      addToast(res.error ?? "Görev tamamlanamadı", "error");
      return false;
    },
    [addToast]
  );

  /** Abandon a quest */
  const abandonQuest = useCallback(
    async (questId: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.QUEST_ABANDON, {
        quest_id: questId,
      });
      if (res.success) {
        setActiveQuests((prev) => prev.filter((q) => q.quest_id !== questId));
        addToast("Görev terk edildi", "info");
        return true;
      }
      addToast(res.error ?? "İşlem başarısız", "error");
      return false;
    },
    [addToast]
  );

  /** Get daily quests */
  const dailyQuests = availableQuests.filter(
    (q) => q.expires_at !== null
  );

  return {
    availableQuests,
    activeQuests,
    dailyQuests,
    isLoading,
    getEnergyCost,
    isQuestAvailable,
    fetchAvailableQuests,
    fetchActiveQuests,
    startQuest,
    completeQuest,
    abandonQuest,
  };
}
