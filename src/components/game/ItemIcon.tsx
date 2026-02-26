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
  enhancementLevel?: number | null;
}

export function ItemIcon({ icon, itemType, itemId, className = "text-xl", alt = "item icon", enhancementLevel = null }: ItemIconProps) {
  const [failed, setFailed] = useState(false);
  const [currentSrc, setCurrentSrc] = useState<string | null>(() => resolveIconSrc(icon));

  const inferredType = useMemo(() => inferItemType(itemType, itemId), [itemType, itemId]);
  const fallbackEmoji = TYPE_EMOJI[inferredType] ?? "📦";
  const src = useMemo(() => resolveIconSrc(icon), [icon]);

  useEffect(() => {
    setFailed(false);
    setCurrentSrc(src);
  }, [src]);

  // Resolve enhancement level: prefer explicit prop, otherwise try inventory store by row_id or item_id
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
    if (currentSrc && !failed) {
      return (
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
  })();

  return (
   <div className="relative inline-block">
  {content}
  {/* Bu yapı (Ternary), koşul sağlanmazsa React'e "null render et" (yani hiçbir şey yapma) der. */}
  {Number(resolvedEnhancement) > 0 ? (
    <span className="absolute top-1 right-1 text-[9px] text-[var(--gold)] font-bold bg-black/50 rounded px-0.5 py-0.5 z-10">
      +{resolvedEnhancement}
    </span>
  ) : null}
</div>
  );
}
