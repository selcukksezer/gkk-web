// ============================================================
// usePrison — Hapishane durumu + kefalet
// Kaynak: PrisonManager.gd (40 satır)
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { useCountdown } from "./useCountdown";

export function usePrison() {
  const [isReleasing, setIsReleasing] = useState(false);

  const inPrison = usePlayerStore((s) => s.inPrison);
  const prisonUntil = usePlayerStore((s) => s.prisonUntil);
  const prisonReason = usePlayerStore((s) => s.prisonReason);
  const gems = usePlayerStore((s) => s.gems);
  const updateGems = usePlayerStore((s) => s.updateGems);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);
  const addToast = useUiStore((s) => s.addToast);

  const { secondsLeft, formatted, isComplete } = useCountdown({
    targetDate: prisonUntil,
    onComplete: () => {
      addToast("Hapishaneden serbest bırakıldınız!", "success");
      fetchProfile();
    },
  });

  /** Bail cost in gems (increases with remaining time) */
  const bailCost = Math.max(5, Math.ceil(secondsLeft / 60) * 5);

  /** Pay bail to release instantly */
  const payBail = useCallback(async (): Promise<boolean> => {
    if (gems < bailCost) {
      addToast(`Yetersiz gem! (${bailCost} gerekli)`, "error");
      return false;
    }
    setIsReleasing(true);
    const res = await api.rpc("release_from_prison", { p_use_bail: true });
    setIsReleasing(false);
    if (res.success) {
      updateGems(gems - bailCost);
      addToast("Kefalet ödendi, serbest bırakıldınız!", "success");
      fetchProfile();
      return true;
    }
    addToast(res.error ?? "Kefalet başarısız", "error");
    return false;
  }, [gems, bailCost, updateGems, addToast, fetchProfile]);

  /** Get human-readable reason */
  const getReasonText = useCallback((): string => {
    if (!prisonReason) return "Bilinmeyen suç";
    const reasons: Record<string, string> = {
      high_suspicion: "Yüksek şüphe seviyesi",
      bribe_failed: "Başarısız rüşvet girişimi",
      illegal_trade: "Yasadışı ticaret",
      pvp_crime: "PvP suçu",
    };
    return reasons[prisonReason] ?? prisonReason;
  }, [prisonReason]);

  return {
    inPrison,
    prisonUntil,
    prisonReason,
    secondsLeft,
    formatted,
    isComplete,
    isReleasing,
    bailCost,
    payBail,
    getReasonText,
  };
}
