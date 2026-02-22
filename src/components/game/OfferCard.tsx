// ============================================================
// OfferCard — Mağaza teklif kartı
// ============================================================

"use client";

import { motion } from "framer-motion";
import { Button } from "@/components/ui/Button";

export interface ShopOffer {
  id: string;
  title: string;
  description?: string;
  price_gems?: number;
  price_gold?: number;
  original_price?: number;
  featured?: boolean;
  expires_at?: string;
  icon?: string;
}

interface OfferCardProps {
  offer: ShopOffer;
  onPurchase: () => void;
  disabled?: boolean;
}

export function OfferCard({ offer, onPurchase, disabled }: OfferCardProps) {
  const hasDiscount = offer.original_price && offer.price_gems && offer.original_price > offer.price_gems;
  const expiresAt = offer.expires_at ? new Date(offer.expires_at) : null;
  const isExpired = expiresAt ? expiresAt.getTime() < Date.now() : false;

  return (
    <motion.div
      whileTap={{ scale: 0.98 }}
      className={`bg-[var(--card-bg)] border rounded-xl p-4 ${
        offer.featured ? "border-[var(--gold)]" : "border-[var(--border)]"
      }`}
    >
      {offer.featured && (
        <span className="text-[10px] bg-[var(--gold)] text-black px-2 py-0.5 rounded-full font-bold mb-2 inline-block">
          ÖNE ÇIKAN
        </span>
      )}

      <div className="flex items-center gap-3 mb-2">
        <span className="text-3xl">{offer.icon ?? "🎁"}</span>
        <div>
          <h3 className="font-bold text-sm">{offer.title}</h3>
          {offer.description && (
            <p className="text-xs text-[var(--text-secondary)]">{offer.description}</p>
          )}
        </div>
      </div>

      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          {hasDiscount && (
            <span className="text-xs text-[var(--text-secondary)] line-through">
              💎 {offer.original_price}
            </span>
          )}
          {offer.price_gems != null && (
            <span className="text-sm font-bold text-purple-400">💎 {offer.price_gems}</span>
          )}
          {offer.price_gold != null && (
            <span className="text-sm font-bold text-[var(--gold)]">🪙 {offer.price_gold}</span>
          )}
        </div>
        <Button
          variant="primary"
          onClick={onPurchase}
          disabled={disabled || isExpired}
        >
          {isExpired ? "Süresi Doldu" : "Satın Al"}
        </Button>
      </div>

      {expiresAt && !isExpired && (
        <p className="text-[10px] text-[var(--text-secondary)] mt-2 text-right">
          ⏳ {expiresAt.toLocaleDateString("tr-TR")} tarihine kadar
        </p>
      )}
    </motion.div>
  );
}
