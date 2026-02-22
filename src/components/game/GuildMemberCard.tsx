// ============================================================
// GuildMemberCard — Lonca üye satırı
// ============================================================

"use client";

import type { GuildMemberData } from "@/types/guild";

interface GuildMemberCardProps {
  member: GuildMemberData;
  canManage: boolean;
  onKick?: () => void;
  onPromote?: () => void;
  onDemote?: () => void;
}

const ROLE_LABELS: Record<string, string> = {
  leader: "Lider",
  officer: "Subay",
  member: "Üye",
};

const ROLE_COLORS: Record<string, string> = {
  leader: "#f59e0b",
  officer: "#3b82f6",
  member: "#9ca3af",
};

export function GuildMemberCard({
  member,
  canManage,
  onKick,
  onPromote,
  onDemote,
}: GuildMemberCardProps) {
  const role = member.role ?? "member";
  const isOnline = member.is_online ?? false;

  return (
    <div className="flex items-center gap-3 bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-3">
      {/* Online indicator */}
      <span
        className="h-2.5 w-2.5 rounded-full shrink-0"
        style={{ backgroundColor: isOnline ? "#22c55e" : "#6b7280" }}
      />

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="font-medium truncate">{member.username}</span>
          <span
            className="text-[10px] px-1.5 py-0.5 rounded"
            style={{
              color: ROLE_COLORS[role],
              backgroundColor: `${ROLE_COLORS[role]}20`,
            }}
          >
            {ROLE_LABELS[role] ?? role}
          </span>
        </div>
        <p className="text-xs text-[var(--text-secondary)]">
          Lv.{member.level} • Katkı: {member.contribution ?? 0}🪙
        </p>
      </div>

      {/* Management buttons */}
      {canManage && role !== "leader" && (
        <div className="flex gap-1 shrink-0">
          {onPromote && (
            <button
              onClick={onPromote}
              className="text-xs p-1.5 rounded bg-blue-600/20 text-blue-400 hover:bg-blue-600/30"
              title="Terfi"
            >
              ↑
            </button>
          )}
          {onDemote && role === "officer" && (
            <button
              onClick={onDemote}
              className="text-xs p-1.5 rounded bg-yellow-600/20 text-yellow-400 hover:bg-yellow-600/30"
              title="İndir"
            >
              ↓
            </button>
          )}
          {onKick && (
            <button
              onClick={onKick}
              className="text-xs p-1.5 rounded bg-red-600/20 text-red-400 hover:bg-red-600/30"
              title="At"
            >
              ✕
            </button>
          )}
        </div>
      )}
    </div>
  );
}
