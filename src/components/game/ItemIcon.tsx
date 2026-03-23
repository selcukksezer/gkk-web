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

const PREFIX_FOLDER_MAP: Record<string, string> = {
  wpn: "weapons",
  arm: "armor",
  acc: "accessories",
  pot: "potions",
  rune: "runes",
  res: "materials",
  scroll: "materials",
  key: "materials",
  quest: "materials",
  recipe: "materials",
};

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
  // pure emoji / single short token without a dot or slash → not an image src
  if (!value.includes("/") && !value.includes(".")) return null;

  // support internal resource scheme
  if (value.startsWith("res://")) return value.replace(/^res:\/\//, "/");

  // Normalize common variants so requests target the public root:
  // - public/assets/...  -> /assets/...
  // - /public/assets/... -> /assets/...
  // - assets/...         -> /assets/...
  let v = value;
  if (v.startsWith("/public/")) v = v.replace(/^\/public\//, "");
  if (v.startsWith("public/")) v = v.replace(/^public\//, "");
  if (!v.startsWith("/")) v = "/" + v;
  return v;
}

function itemTokenToIconPath(token?: string | null): string | null {
  if (!token) return null;
  const value = token.trim().toLowerCase();
  if (!value) return null;
  // Accept ids like wpn_dagger_common, res_mining_common, scroll_upgrade_low.
  if (!/^[a-z][a-z0-9]*_[a-z0-9_]+$/.test(value)) return null;
  const prefix = value.split("_")[0];
  const folder = PREFIX_FOLDER_MAP[prefix];
  if (!folder) return null;
  return `/assets/icons/${folder}/${value}.png`;
}

function isShortEmojiLike(text?: string | null): boolean {
  if (!text) return false;
  const value = text.trim();
  if (!value) return false;
  return !value.includes("/") && !value.includes(".") && value.length <= 3;
}

function buildIconCandidates(icon?: string | null, itemId?: string | null): string[] {
  const candidates = [
    resolveIconSrc(icon),
    itemTokenToIconPath(icon),
    itemTokenToIconPath(itemId),
  ].filter((v): v is string => Boolean(v));

  return Array.from(new Set(candidates));
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
  const srcCandidates = useMemo(() => buildIconCandidates(icon, itemId), [icon, itemId]);
  const [failedVersion, setFailedVersion] = useState(0);

  const src = useMemo(
    () => srcCandidates.find((url) => !_failedUrls.has(url)) ?? null,
    [srcCandidates, failedVersion]
  );

  useEffect(() => {
    setFailedVersion((v) => v + 1);
  }, [icon, itemId]);

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
    // Render first non-failed candidate URL.
    if (src) {
      return (
        <img
          src={src}
          alt={alt}
          className={className}
          draggable={false}
          onError={() => {
            _failedUrls.add(src);
            setFailedVersion((v) => v + 1);
          }}
        />
      );
    }

    // If icon prop is a raw emoji, show it directly.
    if (isShortEmojiLike(icon)) {
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
