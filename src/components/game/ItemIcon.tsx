"use client";

import { useEffect, useMemo, useState } from "react";
import { useInventoryStore } from "@/stores/inventoryStore";

const TYPE_EMOJI: Record<string, string> = {
  weapon: "⚔️",
  armor: "🛡️",
  accessory: "💍",
  consumable: "🧪",
  material: "🪨",
  potion: "🧪",
  scroll: "📜",
  key_item: "🔑",
  quest_item: "📋",
  recipe: "📖",
  rune: "🔮",
  cosmetic: "✨",
};

/**
 * Global cache of URLs that already returned 404.
 * Shared across ALL ItemIcon instances so we never re-attempt a broken URL.
 * This prevents: network request + onError + setState + re-render per item.
 */
const _failedUrls = new Set<string>();

function inferItemType(itemType?: string | null, itemId?: string | null): string {
  if (itemType && itemType.trim().length > 0) return itemType.toLowerCase();
  if (!itemId) return "";
  const prefix = itemId.split("_")[0];
  return prefix?.toLowerCase() ?? "";
}

/** Resolve icon path: keep .png as-is so real PNGs are shown when they exist */
function resolveIconSrc(icon?: string | null): string | null {
  if (!icon) return null;
  const value = icon.trim();
  if (!value) return null;
  // pure emoji / single word without path → not an image src
  if (!value.includes("/") && !value.includes(".")) return null;
  if (value.startsWith("res://")) {
    return value.replace(/^res:\/\//, "/");
  }
  return value;
}

interface ItemIconProps {
  icon?: string | null;
  itemType?: string | null;
  itemId?: string | null;
  className?: string;
  alt?: string;
  enhancementLevel?: number | null;
}

export function ItemIcon({ icon, itemType, itemId, className = "text-xl", alt = "item icon", enhancementLevel = null }: ItemIconProps) {
  const inferredType = useMemo(() => inferItemType(itemType, itemId), [itemType, itemId]);
  const fallbackEmoji = TYPE_EMOJI[inferredType] ?? "📦";
  const src = useMemo(() => resolveIconSrc(icon), [icon]);

  // If src is already known to fail, skip img entirely — no network request, no re-render
  const alreadyFailed = src ? _failedUrls.has(src) : false;
  const [failed, setFailed] = useState(alreadyFailed);

  useEffect(() => {
    setFailed(src ? _failedUrls.has(src) : false);
  }, [src]);

  // Resolve enhancement level: prefer explicit prop, otherwise try inventory store
  const resolvedEnhancement = useMemo(() => {
    if (typeof enhancementLevel === "number") return enhancementLevel;
    if (!itemId) return null;
    try {
      const store = useInventoryStore.getState();
      const byRow = (store.getItemByRowId && store.getItemByRowId(String(itemId))) || null;
      if (byRow && typeof byRow.enhancement_level === "number") return byRow.enhancement_level;
      const byId = (store.getItemById && store.getItemById(String(itemId))) || null;
      if (byId && typeof byId.enhancement_level === "number") return byId.enhancement_level;
    } catch {
      // ignore
    }
    return null;
  }, [itemId, enhancementLevel]);

  const content = (() => {
    // Only render <img> if src exists AND hasn't failed before
    if (src && !failed) {
      return (
        <img
          src={src}
          alt={alt}
          className={className}
          draggable={false}
          onError={() => {
            _failedUrls.add(src);
            setFailed(true);
          }}
        />
      );
    }

    // If icon prop is a raw emoji / text (not a file path), show it directly
    if (icon && !src) {
      return <span className={className}>{icon}</span>;
    }

    return <span className={className}>{fallbackEmoji}</span>;
  })();

  return (
    <div className="relative inline-block">
      {content}
      {Number(resolvedEnhancement) > 0 ? (
        <span className="absolute top-1 right-1 text-[9px] text-[var(--gold)] font-bold bg-black/50 rounded px-0.5 py-0.5 z-10">
          +{resolvedEnhancement}
        </span>
      ) : null}
    </div>
  );
}
