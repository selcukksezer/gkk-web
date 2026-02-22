// ============================================================
// RewardCard — Dungeon / genel ödül kartı
// ============================================================

"use client";

import { motion } from "framer-motion";

export interface Reward {
  type: "gold" | "xp" | "item" | "gem" | "reputation";
  amount?: number;
  itemName?: string;
  rarity?: string;
}

interface RewardCardProps {
  rewards: Reward[];
  title?: string;
}

const REWARD_ICON: Record<string, string> = {
  gold: "🪙",
  xp: "⭐",
  item: "🎁",
  gem: "💎",
  reputation: "🏅",
};

const RARITY_COLOR: Record<string, string> = {
  common: "#9ca3af",
  uncommon: "#22c55e",
  rare: "#3b82f6",
  epic: "#a855f7",
  legendary: "#f59e0b",
};

export function RewardCard({ rewards, title = "Ödüller" }: RewardCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-4"
    >
      <h3 className="text-sm font-bold mb-3">{title}</h3>
      <div className="space-y-2">
        {rewards.map((r, i) => (
          <div key={i} className="flex items-center gap-2">
            <span className="text-lg">{REWARD_ICON[r.type] ?? "🎁"}</span>
            <span
              className="text-sm"
              style={{
                color: r.rarity ? RARITY_COLOR[r.rarity] ?? "#9ca3af" : "var(--text-primary)",
              }}
            >
              {r.type === "item" ? r.itemName ?? "Eşya" : `+${r.amount ?? 0}`}
              {r.type === "gold" && " Altın"}
              {r.type === "xp" && " XP"}
              {r.type === "gem" && " Mücevher"}
              {r.type === "reputation" && " İtibar"}
            </span>
          </div>
        ))}
      </div>
    </motion.div>
  );
}
