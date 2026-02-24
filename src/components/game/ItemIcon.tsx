"use client";

import { useEffect, useMemo, useState } from "react";

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

function inferItemType(itemType?: string | null, itemId?: string | null): string {
  if (itemType && itemType.trim().length > 0) return itemType.toLowerCase();
  if (!itemId) return "";
  const prefix = itemId.split("_")[0];
  return prefix?.toLowerCase() ?? "";
}

function resolveIconSrc(icon?: string | null): string | null {
  if (!icon) return null;
  const value = icon.trim();
  if (!value) return null;
  if (!value.includes("/") && !value.includes(".")) return null;
  if (value.startsWith("res://")) {
    const normalized = value.replace(/^res:\/\//, "/");
    if (normalized.startsWith("/assets/sprites/items/") && normalized.endsWith(".png")) {
      return normalized.replace(/\.png$/, ".svg");
    }
    return normalized;
  }
  if (value.startsWith("/assets/sprites/items/") && value.endsWith(".png")) {
    return value.replace(/\.png$/, ".svg");
  }
  return value;
}

interface ItemIconProps {
  icon?: string | null;
  itemType?: string | null;
  itemId?: string | null;
  className?: string;
  alt?: string;
}

export function ItemIcon({ icon, itemType, itemId, className = "text-xl", alt = "item icon" }: ItemIconProps) {
  const [failed, setFailed] = useState(false);
  const [currentSrc, setCurrentSrc] = useState<string | null>(() => resolveIconSrc(icon));

  const inferredType = useMemo(() => inferItemType(itemType, itemId), [itemType, itemId]);
  const fallbackEmoji = TYPE_EMOJI[inferredType] ?? "📦";
  const src = useMemo(() => resolveIconSrc(icon), [icon]);

  useEffect(() => {
    setFailed(false);
    setCurrentSrc(src);
  }, [src]);

  if (currentSrc && !failed) {
    return (
      // try currentSrc; on error attempt an icons->sprites fallback then finally fail to emoji
      <img
        src={currentSrc}
        alt={alt}
        className={className}
        draggable={false}
        onError={() => {
          if (currentSrc.includes("/assets/icons/")) {
            const altSrc = currentSrc.replace("/assets/icons/", "/assets/sprites/items/").replace(/\.png$/i, ".svg");
            if (altSrc !== currentSrc) {
              setCurrentSrc(altSrc);
              return;
            }
          }
          setFailed(true);
        }}
      />
    );
  }

  if (icon && !src) {
    return <span className={className}>{icon}</span>;
  }

  return <span className={className}>{fallbackEmoji}</span>;
}
