// ============================================================
// ProgressBar Component
// Kaynak: main_theme.tres ProgressBar styles
// ============================================================

import { cn } from "@/lib/utils/cn";

interface ProgressBarProps {
  value: number; // 0-1 arası
  max?: number;
  color?: "accent" | "energy" | "health" | "gold" | "success" | "warning";
  size?: "sm" | "md" | "lg";
  showLabel?: boolean;
  label?: string;
  className?: string;
}

const colorClasses: Record<string, string> = {
  accent: "bg-[var(--accent)]",
  energy: "bg-[var(--color-energy)]",
  health: "bg-[var(--color-error)]",
  gold: "bg-[var(--color-gold)]",
  success: "bg-[var(--color-success)]",
  warning: "bg-[var(--color-warning)]",
};

const sizeClasses: Record<string, string> = {
  sm: "h-1.5",
  md: "h-2.5",
  lg: "h-4",
};

export function ProgressBar({
  value,
  color = "accent",
  size = "md",
  showLabel = false,
  label,
  className,
}: ProgressBarProps) {
  const percent = Math.min(Math.max(value, 0), 1) * 100;

  return (
    <div className={cn("w-full", className)}>
      {showLabel && (
        <div className="flex justify-between text-xs mb-1">
          <span className="text-[var(--text-secondary)]">{label}</span>
          <span className="text-[var(--text-primary)]">
            {Math.round(percent)}%
          </span>
        </div>
      )}
      <div
        className={cn(
          "w-full rounded-full bg-[var(--bg-input)] overflow-hidden",
          sizeClasses[size]
        )}
      >
        <div
          className={cn(
            "h-full rounded-full transition-all duration-500 ease-out",
            colorClasses[color]
          )}
          style={{ width: `${percent}%` }}
        />
      </div>
    </div>
  );
}
