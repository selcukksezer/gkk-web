// ============================================================
// CraftingQueue — Active crafting queue display
// ============================================================

"use client";

import { useCountdown } from "@/hooks/useCountdown";

interface CraftingQueueItem {
  id: string;
  recipe_name: string;
  completes_at: string | null;
  status: string;
}

interface CraftingQueueProps {
  items: CraftingQueueItem[];
  onClaim: (id: string) => void;
}

export function CraftingQueue({ items, onClaim }: CraftingQueueProps) {
  if (items.length === 0) {
    return (
      <div className="text-center text-[var(--text-secondary)] py-8 text-sm">
        Üretim kuyruğu boş
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {items.map((item) => (
        <CraftingQueueRow key={item.id} item={item} onClaim={() => onClaim(item.id)} />
      ))}
    </div>
  );
}

function CraftingQueueRow({
  item,
  onClaim,
}: {
  item: CraftingQueueItem;
  onClaim: () => void;
}) {
  const { formatted, isComplete } = useCountdown({
    targetDate: item.completes_at,
  });

  return (
    <div className="bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-3 flex items-center justify-between">
      <div>
        <p className="font-medium text-sm">{item.recipe_name}</p>
        <p className="text-xs text-[var(--text-secondary)]">
          {isComplete ? "Hazır!" : formatted}
        </p>
      </div>
      {isComplete ? (
        <button
          className="px-3 py-1 rounded-lg bg-green-600 text-white text-sm font-medium"
          onClick={onClaim}
        >
          Topla
        </button>
      ) : (
        <span className="text-xs text-[var(--text-secondary)]">{item.status}</span>
      )}
    </div>
  );
}
