// ============================================================
// ToleranceBar — İksir bağımlılık/tolerans çubuğu
// ============================================================

"use client";

const TIER_COLORS = [
  { max: 20, color: "#22c55e", label: "Normal" },
  { max: 40, color: "#84cc16", label: "Hafif" },
  { max: 60, color: "#eab308", label: "Orta" },
  { max: 80, color: "#f97316", label: "Yüksek" },
  { max: 100, color: "#ef4444", label: "Kritik" },
];

interface ToleranceBarProps {
  value: number; // 0-100
  showLabel?: boolean;
}

export function ToleranceBar({ value, showLabel = true }: ToleranceBarProps) {
  const clamped = Math.max(0, Math.min(100, value));
  const tier = TIER_COLORS.find((t) => clamped <= t.max) ?? TIER_COLORS[4];

  return (
    <div className="w-full">
      {showLabel && (
        <div className="flex items-center justify-between mb-0.5">
          <span className="text-[10px] text-[var(--text-secondary)]">🧪 Tolerans</span>
          <span className="text-[10px]" style={{ color: tier.color }}>
            {tier.label} ({Math.round(clamped)}%)
          </span>
        </div>
      )}
      <div className="h-1.5 bg-[var(--surface)] rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all duration-500"
          style={{ width: `${clamped}%`, backgroundColor: tier.color }}
        />
      </div>
    </div>
  );
}
