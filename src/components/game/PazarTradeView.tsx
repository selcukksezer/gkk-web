// ============================================================
// PazarTradeView — Market trading interface
// ============================================================

"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { useMarketStore } from "@/stores/marketStore";

interface PazarTradeViewProps {
  selectedItemId: string | null;
  onClose: () => void;
}

export function PazarTradeView({ selectedItemId, onClose }: PazarTradeViewProps) {
  const createOrder = useMarketStore((s) => s.createOrder);
  const [side, setSide] = useState<"buy" | "sell">("buy");
  const [quantity, setQuantity] = useState(1);
  const [price, setPrice] = useState(100);
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!selectedItemId) return null;

  const handleSubmit = async () => {
    setIsSubmitting(true);
    await createOrder(selectedItemId, side, quantity, price);
    setIsSubmitting(false);
    onClose();
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-4 space-y-4"
    >
      <h3 className="font-bold">Emir Oluştur</h3>

      {/* Side toggle */}
      <div className="flex gap-2">
        <button
          className={`flex-1 py-2 rounded-lg text-sm font-medium ${
            side === "buy" ? "bg-green-600 text-white" : "bg-[var(--surface)] text-[var(--text-secondary)]"
          }`}
          onClick={() => setSide("buy")}
        >
          Alış
        </button>
        <button
          className={`flex-1 py-2 rounded-lg text-sm font-medium ${
            side === "sell" ? "bg-red-600 text-white" : "bg-[var(--surface)] text-[var(--text-secondary)]"
          }`}
          onClick={() => setSide("sell")}
        >
          Satış
        </button>
      </div>

      {/* Quantity */}
      <div>
        <label className="text-xs text-[var(--text-secondary)] block mb-1">Miktar</label>
        <input
          type="number"
          min={1}
          value={quantity}
          onChange={(e) => setQuantity(Math.max(1, Number(e.target.value)))}
          className="w-full bg-[var(--surface)] border border-[var(--border)] rounded-lg px-3 py-2 text-sm"
        />
      </div>

      {/* Price */}
      <div>
        <label className="text-xs text-[var(--text-secondary)] block mb-1">Fiyat (🪙)</label>
        <input
          type="number"
          min={1}
          value={price}
          onChange={(e) => setPrice(Math.max(1, Number(e.target.value)))}
          className="w-full bg-[var(--surface)] border border-[var(--border)] rounded-lg px-3 py-2 text-sm"
        />
      </div>

      {/* Total */}
      <p className="text-sm text-[var(--text-secondary)]">
        Toplam: <span className="text-[var(--gold)] font-bold">{(quantity * price).toLocaleString("tr-TR")} 🪙</span>
      </p>

      {/* Actions */}
      <div className="flex gap-2">
        <button
          className="flex-1 py-2 rounded-lg bg-[var(--surface)] text-[var(--text-secondary)] text-sm"
          onClick={onClose}
        >
          İptal
        </button>
        <button
          className={`flex-1 py-2 rounded-lg text-white text-sm font-medium ${
            side === "buy" ? "bg-green-600" : "bg-red-600"
          }`}
          onClick={handleSubmit}
          disabled={isSubmitting}
        >
          {isSubmitting ? "..." : side === "buy" ? "Satın Al" : "Sat"}
        </button>
      </div>
    </motion.div>
  );
}
