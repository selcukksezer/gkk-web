// ============================================================
// UnlockFacilityCard — Kilitli tesis kartı + unlock butonu
// ============================================================

"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { FACILITIES_CONFIG } from "@/data/FacilityConfig";
import type { FacilityType } from "@/types/facility";

interface UnlockFacilityCardProps {
  type: FacilityType;
  requiredLevel: number;
  unlockCost: number;
  onUnlock: () => Promise<boolean>;
}

export function UnlockFacilityCard({
  type,
  requiredLevel,
  unlockCost,
  onUnlock,
}: UnlockFacilityCardProps) {
  const [isUnlocking, setIsUnlocking] = useState(false);
  const level = usePlayerStore((s) => s.level);
  const gold = usePlayerStore((s) => s.gold);
  const addToast = useUiStore((s) => s.addToast);
  const config = FACILITIES_CONFIG[type];

  const canUnlock = level >= requiredLevel && gold >= unlockCost;

  const handleUnlock = async () => {
    if (!canUnlock) {
      if (level < requiredLevel) addToast(`Seviye ${requiredLevel} gerekli`, "warning");
      else addToast("Yetersiz altın!", "error");
      return;
    }
    setIsUnlocking(true);
    await onUnlock();
    setIsUnlocking(false);
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="bg-[var(--card-bg)] border border-dashed border-[var(--border)] rounded-xl p-6 text-center"
    >
      <span className="text-4xl">{config?.icon ?? "🔒"}</span>
      <h3 className="font-bold mt-2">{config?.name ?? type}</h3>
      <p className="text-xs text-[var(--text-secondary)] mt-1">{config?.description ?? ""}</p>

      <div className="mt-4 space-y-1 text-sm">
        <p className={level >= requiredLevel ? "text-green-400" : "text-red-400"}>
          Seviye {requiredLevel} {level >= requiredLevel ? "✓" : "✗"}
        </p>
        <p className={gold >= unlockCost ? "text-green-400" : "text-red-400"}>
          {unlockCost.toLocaleString("tr-TR")} Altın {gold >= unlockCost ? "✓" : "✗"}
        </p>
      </div>

      <button
        className="mt-4 w-full py-2 rounded-lg bg-[var(--primary)] text-white font-medium disabled:opacity-50"
        onClick={handleUnlock}
        disabled={!canUnlock || isUnlocking}
      >
        {isUnlocking ? "Açılıyor..." : "Tesisi Aç"}
      </button>
    </motion.div>
  );
}
