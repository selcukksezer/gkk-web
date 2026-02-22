// ============================================================
// PvPTargetCard — PvP hedef oyuncu kartı
// ============================================================

"use client";

import { motion } from "framer-motion";
import type { PvPTarget } from "@/types/pvp";

interface PvPTargetCardProps {
  target: PvPTarget;
  winChance: number;
  onAttack: () => void;
  disabled?: boolean;
}

export function PvPTargetCard({ target, winChance, onAttack, disabled }: PvPTargetCardProps) {
  const winPct = Math.round(winChance * 100);
  const winColor = winPct >= 60 ? "#22c55e" : winPct >= 40 ? "#eab308" : "#ef4444";

  return (
    <motion.div
      whileTap={{ scale: 0.98 }}
      className="bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-4"
    >
      <div className="flex items-center justify-between mb-2">
        <div>
          <h3 className="font-bold">{target.username}</h3>
          <p className="text-xs text-[var(--text-secondary)]">
            Lv.{target.level} • ⚔️ {target.pvp_rating ?? target.rating}
          </p>
          {target.guild_name && (
            <p className="text-[10px] text-blue-400">[{target.guild_name}]</p>
          )}
        </div>
        <div className="text-right">
          <p className="text-sm">Güç: {target.power}</p>
          <p className="text-xs text-[var(--gold)]">~{target.estimated_gold} 🪙</p>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-xs" style={{ color: winColor }}>
            Kazanma: %{winPct}
          </span>
          <div className="w-20 h-1.5 bg-[var(--surface)] rounded-full overflow-hidden">
            <div
              className="h-full rounded-full"
              style={{ width: `${winPct}%`, backgroundColor: winColor }}
            />
          </div>
        </div>
        <button
          className="px-4 py-1.5 rounded-lg bg-red-600 text-white text-sm font-medium disabled:opacity-50"
          onClick={onAttack}
          disabled={disabled}
        >
          Saldır
        </button>
      </div>
    </motion.div>
  );
}
