// ============================================================
// SuspicionBar — Şüphe seviyesi göstergesi
// ============================================================

"use client";

interface SuspicionBarProps {
  value: number;
  max?: number;
  showLabel?: boolean;
}

export function SuspicionBar({ value, max = 100, showLabel = true }: SuspicionBarProps) {
  const pct = Math.min((value / max) * 100, 100);
  const color = pct < 30 ? "#22c55e" : pct < 60 ? "#eab308" : pct < 80 ? "#f97316" : "#ef4444";
  const label =
    pct < 30 ? "Düşük" : pct < 60 ? "Orta" : pct < 80 ? "Yüksek" : "Kritik";

  return (
    <div>
      {showLabel && (
        <div className="flex justify-between text-xs mb-1">
          <span className="text-[var(--text-secondary)]">Şüphe</span>
          <span style={{ color }}>{label} ({Math.round(pct)}%)</span>
        </div>
      )}
      <div className="w-full h-2 bg-[var(--surface)] rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all duration-500"
          style={{ width: `${pct}%`, backgroundColor: color }}
        />
      </div>
    </div>
  );
}
