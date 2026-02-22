// ============================================================
// BatchSelector — Amount selector for crafting/production
// ============================================================

"use client";

interface BatchSelectorProps {
  value: number;
  min?: number;
  max?: number;
  onChange: (value: number) => void;
  label?: string;
}

export function BatchSelector({
  value,
  min = 1,
  max = 10,
  onChange,
  label = "Miktar",
}: BatchSelectorProps) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm text-[var(--text-secondary)]">{label}:</span>
      <div className="flex items-center gap-3">
        <button
          className="w-8 h-8 rounded-full bg-[var(--card-bg)] border border-[var(--border)] flex items-center justify-center text-sm disabled:opacity-30"
          onClick={() => onChange(Math.max(min, value - 1))}
          disabled={value <= min}
        >
          −
        </button>
        <span className="font-bold w-8 text-center">{value}</span>
        <button
          className="w-8 h-8 rounded-full bg-[var(--card-bg)] border border-[var(--border)] flex items-center justify-center text-sm disabled:opacity-30"
          onClick={() => onChange(Math.min(max, value + 1))}
          disabled={value >= max}
        >
          +
        </button>
      </div>
    </div>
  );
}
