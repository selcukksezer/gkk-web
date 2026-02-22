// ============================================================
// LeaderboardRow — Sıralama satırı
// ============================================================

"use client";

interface LeaderboardRowProps {
  rank: number;
  username: string;
  value: number;
  label?: string;
  isCurrentPlayer?: boolean;
}

const RANK_EMOJI: Record<number, string> = {
  1: "🥇",
  2: "🥈",
  3: "🥉",
};

export function LeaderboardRow({
  rank,
  username,
  value,
  label,
  isCurrentPlayer,
}: LeaderboardRowProps) {
  return (
    <div
      className="flex items-center gap-3 px-3 py-2 rounded-lg"
      style={{
        backgroundColor: isCurrentPlayer ? "var(--primary-dim, rgba(139,92,246,0.15))" : "transparent",
      }}
    >
      <span className="w-8 text-center text-sm font-bold">
        {RANK_EMOJI[rank] ?? `#${rank}`}
      </span>
      <span className={`flex-1 text-sm truncate ${isCurrentPlayer ? "font-bold" : ""}`}>
        {username}
      </span>
      <span className="text-sm font-mono text-[var(--text-secondary)]">
        {value.toLocaleString("tr-TR")} {label ?? ""}
      </span>
    </div>
  );
}
