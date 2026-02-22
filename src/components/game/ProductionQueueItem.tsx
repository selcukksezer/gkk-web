// ============================================================
// ProductionQueueItem — Üretim kuyruğu satırı
// ============================================================

"use client";

import { useCountdown } from "@/hooks/useCountdown";

interface ProductionQueueItemProps {
  id: string;
  recipeName: string;
  completesAt: string | null;
  rarity?: string;
  onCollect: () => void;
}

export function ProductionQueueItem({
  recipeName,
  completesAt,
  rarity,
  onCollect,
}: ProductionQueueItemProps) {
  const { formatted, isComplete, secondsLeft } = useCountdown({
    targetDate: completesAt,
  });

  const progressPct = completesAt
    ? Math.max(0, 100 - (secondsLeft / 3600) * 100)
    : 100;

  return (
    <div className="bg-[var(--surface)] rounded-lg p-3 flex items-center justify-between">
      <div className="flex-1">
        <p className="text-sm font-medium">{recipeName}</p>
        {rarity && (
          <span className="text-[10px] text-[var(--text-secondary)]">{rarity}</span>
        )}
        {!isComplete && (
          <div className="mt-1 w-full h-1 bg-[var(--card-bg)] rounded-full overflow-hidden">
            <div
              className="h-full bg-[var(--primary)] rounded-full transition-all"
              style={{ width: `${progressPct}%` }}
            />
          </div>
        )}
      </div>
      <div className="ml-3 text-right">
        {isComplete ? (
          <button
            className="px-3 py-1 bg-green-600 text-white text-xs rounded-lg font-medium"
            onClick={onCollect}
          >
            Topla
          </button>
        ) : (
          <span className="text-xs text-[var(--text-secondary)]">{formatted}</span>
        )}
      </div>
    </div>
  );
}
