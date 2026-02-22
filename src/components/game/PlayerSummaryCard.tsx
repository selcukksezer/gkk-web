// ============================================================
// PlayerSummaryCard — Ana sayfa oyuncu özeti
// ============================================================

"use client";

import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { ProgressBar } from "@/components/ui/ProgressBar";

export function PlayerSummaryCard() {
  const player = usePlayerStore((s) => s.player);
  const level = usePlayerStore((s) => s.level);
  const xp = usePlayerStore((s) => s.xp);
  const nextLevelXp = usePlayerStore((s) => s.nextLevelXp);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const pvpRating = usePlayerStore((s) => s.pvpRating);

  const username = (player as unknown as Record<string, unknown>)?.username as string ?? "Oyuncu";

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="bg-[var(--card-bg)] border border-[var(--border)] rounded-2xl p-4"
    >
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <div>
          <h2 className="font-bold text-lg">{username}</h2>
          <p className="text-xs text-[var(--text-secondary)]">Seviye {level}</p>
        </div>
        <div className="flex items-center gap-2 text-sm">
          <span>⚔️ {pvpRating}</span>
        </div>
      </div>

      {/* XP Bar */}
      <div className="mb-3">
        <div className="flex justify-between text-xs text-[var(--text-secondary)] mb-1">
          <span>Deneyim</span>
          <span>{xp}/{nextLevelXp}</span>
        </div>
        <ProgressBar value={xp} max={nextLevelXp} color="accent" />
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-2 text-center text-sm">
        <div className="bg-[var(--surface)] rounded-lg py-2">
          <p className="text-xs text-[var(--text-secondary)]">⚡ Enerji</p>
          <p className="font-bold text-green-400">{energy}/{maxEnergy}</p>
        </div>
        <div className="bg-[var(--surface)] rounded-lg py-2">
          <p className="text-xs text-[var(--text-secondary)]">🪙 Altın</p>
          <p className="font-bold text-[var(--gold)]">{gold.toLocaleString("tr-TR")}</p>
        </div>
        <div className="bg-[var(--surface)] rounded-lg py-2">
          <p className="text-xs text-[var(--text-secondary)]">💎 Gem</p>
          <p className="font-bold text-blue-400">{gems.toLocaleString("tr-TR")}</p>
        </div>
      </div>

      {/* TEMP DEBUG DUMP FOR USER */}
      <div className="mt-4 p-2 bg-black bg-opacity-50 text-[10px] text-gray-300 font-mono overflow-x-auto max-h-40 rounded border border-red-500">
        <p className="text-red-400 font-bold mb-1">=== API YANITI DEBUG (Lütfen bu alanın fotoğrafını veya metnini bana (Ajan'a) atın) ===</p>
        <pre>{JSON.stringify(player, null, 2)}</pre>
      </div>
    </motion.div>
  );
}
