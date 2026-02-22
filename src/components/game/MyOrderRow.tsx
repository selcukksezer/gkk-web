// ============================================================
// MyOrderRow — Player's own market order row
// ============================================================

"use client";

import { useState } from "react";
import type { Rarity } from "@/types/item";
import { getRarityColor } from "@/types/item";

interface MyOrderRowProps {
  orderId: string;
  itemName: string;
  rarity: string;
  quantity: number;
  price: number;
  side: "buy" | "sell";
  status: string;
  createdAt: string;
  onCancel: (orderId: string) => void;
}

export function MyOrderRow({
  orderId,
  itemName,
  rarity,
  quantity,
  price,
  side,
  status,
  createdAt,
  onCancel,
}: MyOrderRowProps) {
  const [isCancelling, setIsCancelling] = useState(false);

  const handleCancel = async () => {
    setIsCancelling(true);
    await onCancel(orderId);
    setIsCancelling(false);
  };

  return (
    <div className="bg-[var(--card-bg)] border border-[var(--border)] rounded-lg p-3">
      <div className="flex items-center justify-between">
        <div>
          <p className="font-medium text-sm" style={{ color: getRarityColor(rarity as Rarity) }}>
            {itemName}
          </p>
          <p className="text-[10px] text-[var(--text-secondary)]">
            {new Date(createdAt).toLocaleDateString("tr-TR")}
          </p>
        </div>
        <div className="text-right">
          <p className="text-sm font-bold text-[var(--gold)]">
            {price.toLocaleString("tr-TR")} 🪙
          </p>
          <p className="text-[10px] text-[var(--text-secondary)]">×{quantity}</p>
        </div>
      </div>
      <div className="flex items-center justify-between mt-2">
        <div className="flex gap-2">
          <span
            className={`text-[10px] px-2 py-0.5 rounded ${
              side === "buy" ? "bg-green-600/20 text-green-400" : "bg-red-600/20 text-red-400"
            }`}
          >
            {side === "buy" ? "ALIŞ" : "SATIŞ"}
          </span>
          <span className="text-[10px] px-2 py-0.5 rounded bg-[var(--surface)] text-[var(--text-secondary)]">
            {status}
          </span>
        </div>
        {status === "open" && (
          <button
            className="text-xs text-red-400 hover:text-red-300 disabled:opacity-50"
            onClick={handleCancel}
            disabled={isCancelling}
          >
            {isCancelling ? "..." : "İptal Et"}
          </button>
        )}
      </div>
    </div>
  );
}
