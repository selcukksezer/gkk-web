// ============================================================
// CraftingQueue — Active crafting queue display
// ============================================================

"use client";

import { useCountdown } from "@/hooks/useCountdown";
import { RESOURCE_CATALOG } from "@/data/ResourceCatalog";

interface CraftingQueueItem {
  id: string;
  recipe_name: string;
  output_item_id?: string;
  output_quantity?: number;
  output_name?: string;
  completes_at: string | null;
  status: string;
}

interface CraftingQueueProps {
  items: CraftingQueueItem[];
  onClaim: (id: string) => void;
}

// Get item name from resource catalog or fallback to output_name
function humanizeId(id: string): string {
  return id
    .replace(/^res_/, '')
    .split(/[_\-]/)
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
    .join(' ');
}

function getItemName(itemId?: string, outputName?: string): string {
  const maybeId = itemId || outputName;
  if (!maybeId) return outputName || "Ürün";

  // Prefer catalog lookup for either the explicit id or the fallback name
  const byId = RESOURCE_CATALOG[maybeId as keyof typeof RESOURCE_CATALOG];
  if (byId?.name) return byId.name;

  // If outputName looks like an id (res_...), try that lookup explicitly
  if (outputName && /^res_/.test(outputName)) {
    const byOutputName = RESOURCE_CATALOG[outputName as keyof typeof RESOURCE_CATALOG];
    if (byOutputName?.name) return byOutputName.name;
  }

  // Fallback: if outputName is an id-like string, humanize it, otherwise use provided display name
  if (/^res_/.test(maybeId)) return humanizeId(maybeId);
  return outputName || itemId || maybeId;
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
        <div className="flex items-center gap-2 mt-1">
          {item.output_item_id && (
            <p className="text-xs text-[var(--text-secondary)]">
              {item.output_quantity}x {getItemName(item.output_item_id, item.output_name)}
            </p>
          )}
        </div>
        <p className="text-xs text-[var(--text-secondary)] mt-1">
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
