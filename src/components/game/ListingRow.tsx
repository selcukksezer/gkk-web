// ============================================================
// ListingRow — Market order listing row
// ============================================================

"use client";

import type { Rarity } from "@/types/item";
import { getRarityColor } from "@/types/item";

interface ListingRowProps {
  itemName: string;
  rarity: string;
  quantity: number;
  price: number;
  side: "buy" | "sell";
  sellerName?: string;
  createdAt?: string;
  onClick?: () => void;
}

export function ListingRow({
  itemName,
  rarity,
  quantity,
  price,
  side,
  sellerName,
  createdAt,
  onClick,
}: ListingRowProps) {
  return (
    <button
      className="w-full flex items-center gap-3 bg-[var(--card-bg)] border border-[var(--border)] rounded-lg p-3 hover:bg-[var(--surface)] transition-colors"
      onClick={onClick}
    >
      <div className="flex-1 text-left">
        <p className="font-medium text-sm" style={{ color: getRarityColor(rarity as Rarity) }}>
          {itemName}
        </p>
        {sellerName && (
          <p className="text-[10px] text-[var(--text-secondary)]">{sellerName}</p>
        )}
      </div>
      <div className="text-right">
        <p className="text-sm font-bold text-[var(--gold)]">
          {price.toLocaleString("tr-TR")} 🪙
        </p>
        <p className="text-[10px] text-[var(--text-secondary)]">×{quantity}</p>
      </div>
      <span
        className={`text-[10px] px-2 py-0.5 rounded font-medium ${
          side === "buy"
            ? "bg-green-600/20 text-green-400"
            : "bg-red-600/20 text-red-400"
        }`}
      >
        {side === "buy" ? "ALIŞ" : "SATIŞ"}
      </span>
    </button>
  );
}
