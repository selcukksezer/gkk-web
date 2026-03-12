"use client";

import { usePlayerStore } from "@/stores/playerStore";
import { cn } from "@/lib/utils/cn";

export function ToleranceBar() {
  const tolerance = usePlayerStore((s) => s.tolerance);
  const addictionLevel = usePlayerStore((s) => s.addictionLevel);

  // Determine bar color based on tolerance
  let barColor = "bg-green-500";
  if (tolerance > 80) barColor = "bg-red-600";
  else if (tolerance > 50) barColor = "bg-orange-500";
  else if (tolerance > 20) barColor = "bg-yellow-500";

  return (
    <div className="flex flex-col gap-1 w-full" title="İksir Toleransı ve Bağımlılık">
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs text-[var(--text-muted)]">☠️ Tolerans</span>
        <span className={cn(
          "text-xs font-semibold",
          tolerance > 80 ? "text-red-400" :
          tolerance > 50 ? "text-orange-400" : "text-white"
        )}>
          {tolerance}/100
        </span>
      </div>
      <div className="h-2 w-full bg-[var(--bg-card)] rounded-full overflow-hidden">
        <div
          className={cn("h-full transition-all duration-500 rounded-full", barColor)}
          style={{ width: `${Math.min(100, Math.max(0, tolerance))}%` }}
        />
      </div>
      {addictionLevel > 0 && (
        <div className="flex justify-between text-[10px] px-1 mt-0.5">
          <span className="text-[var(--color-error)] opacity-80">Bağımlılık (Yoksunluk: {addictionLevel >= 3 ? "Aktif" : "Pasif"})</span>
          <span className="text-purple-400 font-bold">Seviye {addictionLevel}</span>
        </div>
      )}
    </div>
  );
}
