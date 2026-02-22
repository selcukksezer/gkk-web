// ============================================================
// QuestCard — Görev listesi kartı
// ============================================================

"use client";

import { motion } from "framer-motion";
import { ProgressBar } from "@/components/ui/ProgressBar";
import type { QuestData } from "@/types/quest";

interface QuestCardProps {
  quest: QuestData;
  isActive?: boolean;
  onStart?: () => void;
  onComplete?: () => void;
  onAbandon?: () => void;
}

const DIFFICULTY_COLORS: Record<string, string> = {
  easy: "#22c55e",
  medium: "#eab308",
  hard: "#ef4444",
  legendary: "#f59e0b",
};

export function QuestCard({ quest, isActive, onStart, onComplete, onAbandon }: QuestCardProps) {
  const progress = quest.progress ?? 0;
  const target = quest.target ?? quest.progress_max ?? 1;
  const pct = Math.min(progress / target, 1);
  const canComplete = pct >= 1;
  const diff = quest.difficulty ?? "medium";

  return (
    <motion.div
      whileTap={{ scale: 0.98 }}
      className="bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-4"
    >
      <div className="flex items-center justify-between mb-1">
        <h3 className="font-bold text-sm">{quest.name}</h3>
        <span
          className="text-[10px] px-2 py-0.5 rounded-full"
          style={{
            color: DIFFICULTY_COLORS[diff],
            backgroundColor: `${DIFFICULTY_COLORS[diff]}20`,
          }}
        >
          {diff.charAt(0).toUpperCase() + diff.slice(1)}
        </span>
      </div>

      <p className="text-xs text-[var(--text-secondary)] mb-2 line-clamp-2">
        {quest.description}
      </p>

      {/* Rewards */}
      <div className="flex gap-3 text-xs mb-2">
        {quest.gold_reward != null && quest.gold_reward > 0 && (
          <span className="text-[var(--gold)]">🪙 {quest.gold_reward}</span>
        )}
        {quest.xp_reward != null && quest.xp_reward > 0 && (
          <span className="text-blue-400">⭐ {quest.xp_reward}</span>
        )}
        {quest.item_rewards && quest.item_rewards.length > 0 && (
          <span className="text-purple-400">🎁 {quest.item_rewards.length} eşya</span>
        )}
      </div>

      {/* Progress bar for active quests */}
      {isActive && (
        <div className="mb-2">
          <ProgressBar value={pct * 100} max={100} />
          <p className="text-[10px] text-[var(--text-secondary)] mt-0.5 text-right">
            {progress}/{target}
          </p>
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-2 justify-end">
        {isActive && onAbandon && (
          <button
            onClick={onAbandon}
            className="text-xs px-3 py-1 rounded bg-red-600/20 text-red-400"
          >
            Bırak
          </button>
        )}
        {isActive && canComplete && onComplete && (
          <button
            onClick={onComplete}
            className="text-xs px-3 py-1 rounded bg-green-600 text-white font-medium"
          >
            Tamamla
          </button>
        )}
        {!isActive && onStart && (
          <button
            onClick={onStart}
            className="text-xs px-3 py-1 rounded bg-[var(--primary)] text-white font-medium"
          >
            Başla
          </button>
        )}
      </div>
    </motion.div>
  );
}
