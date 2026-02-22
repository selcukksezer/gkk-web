// ============================================================
// RarityBadge — Nadirlik etiketi
// ============================================================

"use client";

const RARITY_MAP: Record<string, { label: string; color: string }> = {
  common: { label: "Sıradan", color: "#9ca3af" },
  uncommon: { label: "Nadir Değil", color: "#22c55e" },
  rare: { label: "Nadir", color: "#3b82f6" },
  epic: { label: "Epik", color: "#a855f7" },
  legendary: { label: "Efsanevi", color: "#f59e0b" },
};

interface RarityBadgeProps {
  rarity: string;
  size?: "sm" | "md";
}

export function RarityBadge({ rarity, size = "sm" }: RarityBadgeProps) {
  const info = RARITY_MAP[rarity] ?? RARITY_MAP.common;
  const textSize = size === "sm" ? "text-[10px]" : "text-xs";

  return (
    <span
      className={`${textSize} px-1.5 py-0.5 rounded font-medium`}
      style={{
        color: info.color,
        backgroundColor: `${info.color}20`,
      }}
    >
      {info.label}
    </span>
  );
}
