// ============================================================
// BribeButton — Rüşvet butonu ile şüphe azaltma
// ============================================================

"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useFacilityStore } from "@/stores/facilityStore";

interface BribeButtonProps {
  facilityId: string;
  cost: number;
  suspicion: number;
}

export function BribeButton({ facilityId, cost, suspicion }: BribeButtonProps) {
  const [isBribing, setIsBribing] = useState(false);
  const gold = usePlayerStore((s) => s.gold);
  const addToast = useUiStore((s) => s.addToast);

  const handleBribe = async () => {
    if (gold < cost) {
      addToast("Yetersiz altın!", "error");
      return;
    }
    if (suspicion <= 0) {
      addToast("Şüphe zaten düşük", "info");
      return;
    }
    setIsBribing(true);
    try {
      // API call would go through facility store
      addToast("Rüşvet verildi, şüphe azaltıldı", "success");
    } finally {
      setIsBribing(false);
    }
  };

  return (
    <motion.button
      whileTap={{ scale: 0.95 }}
      className="flex items-center gap-2 bg-yellow-600/20 border border-yellow-600/40 text-yellow-400 px-4 py-2 rounded-xl text-sm font-medium disabled:opacity-50"
      onClick={handleBribe}
      disabled={isBribing || gold < cost || suspicion <= 0}
    >
      <span>🤫</span>
      <span>{isBribing ? "..." : `Rüşvet (${cost} 🪙)`}</span>
    </motion.button>
  );
}
