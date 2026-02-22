// ============================================================
// useHospital — Hastane durumu + taburcu yöntemleri
// Kaynak: HospitalManager.gd (268 satır)
// ============================================================

"use client";

import { useState, useCallback, useEffect } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";
import { useCountdown } from "./useCountdown";

export type HospitalReason = "overdose" | "pvp_defeat" | "quest_failure" | "dungeon_failure";
export type ReleaseMethod = "wait" | "gems" | "guild_help" | "quest";

const REASON_TEXTS: Record<HospitalReason, string> = {
  overdose: "Doz Aşımı",
  pvp_defeat: "PvP Yenilgisi",
  quest_failure: "Görev Başarısızlığı",
  dungeon_failure: "Zindan Yenilgisi",
};

export function useHospital() {
  const [isReleasing, setIsReleasing] = useState(false);
  const [reason, setReason] = useState<HospitalReason | null>(null);

  const inHospital = usePlayerStore((s) => s.inHospital);
  const hospitalUntil = usePlayerStore((s) => s.hospitalUntil);
  const gems = usePlayerStore((s) => s.gems);
  const updateGems = usePlayerStore((s) => s.updateGems);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);
  const addToast = useUiStore((s) => s.addToast);

  const { secondsLeft, formatted, isComplete } = useCountdown({
    targetDate: hospitalUntil,
    onComplete: () => {
      addToast("Hastaneden taburcu oldunuz!", "success");
      fetchProfile();
    },
  });

  /** Calculate gem cost for instant release */
  const gemCost = Math.max(
    1,
    Math.ceil(secondsLeft / 60) * GAME_CONFIG.hospital.gemReleaseCostPerMinute
  );

  /** Get reason text */
  const getReasonText = useCallback(
    (r?: HospitalReason | null) => REASON_TEXTS[(r ?? reason) as HospitalReason] ?? "Bilinmeyen",
    [reason]
  );

  /** Fetch hospital status from server */
  const fetchStatus = useCallback(async () => {
    const res = await api.rpc<{
      in_hospital: boolean;
      hospital_until: string | null;
      reason: string | null;
    }>("get_hospital_status");
    if (res.success && res.data) {
      setReason((res.data.reason as HospitalReason) ?? null);
    }
  }, []);

  // Fetch status on mount if hospitalized
  useEffect(() => {
    if (inHospital) fetchStatus();
  }, [inHospital, fetchStatus]);

  /** Release with gems (instant) */
  const releaseWithGems = useCallback(async (): Promise<boolean> => {
    if (gems < gemCost) {
      addToast(`Yetersiz gem! (${gemCost} gerekli)`, "error");
      return false;
    }
    setIsReleasing(true);
    const res = await api.rpc("release_from_hospital", {
      p_method: "gems",
      p_cost: gemCost,
    });
    setIsReleasing(false);
    if (res.success) {
      updateGems(gems - gemCost);
      addToast("Gem ile taburcu oldunuz!", "success");
      fetchProfile();
      return true;
    }
    addToast(res.error ?? "Taburcu başarısız", "error");
    return false;
  }, [gems, gemCost, updateGems, addToast, fetchProfile]);

  /** Release with guild help (partial time reduction) */
  const releaseWithGuildHelp = useCallback(async (): Promise<boolean> => {
    setIsReleasing(true);
    const res = await api.rpc("release_from_hospital", {
      p_method: "guild_help",
    });
    setIsReleasing(false);
    if (res.success) {
      addToast(`Lonca yardımıyla süre %${GAME_CONFIG.hospital.guildHelpReductionPercent} azaltıldı!`, "success");
      fetchProfile();
      return true;
    }
    addToast(res.error ?? "Lonca yardımı başarısız", "error");
    return false;
  }, [addToast, fetchProfile]);

  /** Release with quest completion */
  const releaseWithQuest = useCallback(
    async (questId: string): Promise<boolean> => {
      setIsReleasing(true);
      const res = await api.rpc("release_from_hospital", {
        p_method: "quest",
        p_quest_id: questId,
      });
      setIsReleasing(false);
      if (res.success) {
        addToast("Görev ile taburcu oldunuz!", "success");
        fetchProfile();
        return true;
      }
      addToast(res.error ?? "Taburcu başarısız", "error");
      return false;
    },
    [addToast, fetchProfile]
  );

  return {
    inHospital,
    hospitalUntil,
    secondsLeft,
    formatted,
    isComplete,
    isReleasing,
    reason,
    gemCost,
    getReasonText,
    fetchStatus,
    releaseWithGems,
    releaseWithGuildHelp,
    releaseWithQuest,
  };
}
