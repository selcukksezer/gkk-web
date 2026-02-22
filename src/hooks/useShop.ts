// ============================================================
// useShop — Mağaza + IAP + Gem paketleri
// Kaynak: ShopManager.gd (292 satır)
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";

export interface ShopOffer {
  id: string;
  name: string;
  description: string;
  price: number;
  currency: "gems" | "gold" | "usd";
  rewards: { type: string; amount: number; item_id?: string }[];
  expires_at: string | null;
  is_featured: boolean;
}

export interface GemPackage {
  id: string;
  gems: number;
  price: number;
  bonus: number;
  label: string;
}

const GEM_PACKAGES: GemPackage[] = GAME_CONFIG.monetization.premiumCurrencyPacks.map(
  (p, i) => ({
    id: `gem_pack_${i}`,
    gems: p.gems,
    price: p.price,
    bonus: "bonus" in p ? (p as { bonus: number }).bonus : 0,
    label:
      p.gems <= 100
        ? "Başlangıç"
        : p.gems <= 500
          ? "Küçük"
          : p.gems <= 1200
            ? "Orta"
            : p.gems <= 2500
              ? "Büyük"
              : p.gems <= 6500
                ? "Dev"
                : "Mega",
  })
);

export function useShop() {
  const [offers, setOffers] = useState<ShopOffer[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isPurchasing, setIsPurchasing] = useState(false);

  const gems = usePlayerStore((s) => s.gems);
  const gold = usePlayerStore((s) => s.gold);
  const updateGems = usePlayerStore((s) => s.updateGems);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);

  /** Load active offers from server */
  const fetchOffers = useCallback(async () => {
    setIsLoading(true);
    const res = await api.get<ShopOffer[]>(APIEndpoints.SHOP_LIST);
    if (res.success && res.data) {
      // Filter expired
      const now = Date.now();
      setOffers(
        res.data.filter(
          (o) => !o.expires_at || new Date(o.expires_at).getTime() > now
        )
      );
    }
    setIsLoading(false);
  }, []);

  /** Purchase an item with gems */
  const purchaseWithGems = useCallback(
    async (itemId: string, gemCost: number): Promise<boolean> => {
      if (gems < gemCost) {
        addToast("Yetersiz gem!", "error");
        return false;
      }
      setIsPurchasing(true);
      const res = await api.post(APIEndpoints.SHOP_BUY, {
        item_id: itemId,
        currency: "gems",
      });
      setIsPurchasing(false);
      if (res.success) {
        updateGems(gems - gemCost);
        addToast("Satın alma başarılı!", "success");
        return true;
      }
      addToast(res.error ?? "Satın alma başarısız", "error");
      return false;
    },
    [gems, updateGems, addToast]
  );

  /** Purchase an item with gold */
  const purchaseWithGold = useCallback(
    async (itemId: string, goldCost: number): Promise<boolean> => {
      if (gold < goldCost) {
        addToast("Yetersiz altın!", "error");
        return false;
      }
      setIsPurchasing(true);
      const res = await api.post(APIEndpoints.SHOP_BUY, {
        item_id: itemId,
        currency: "gold",
      });
      setIsPurchasing(false);
      if (res.success) {
        updateGold(gold - goldCost);
        addToast("Satın alma başarılı!", "success");
        return true;
      }
      addToast(res.error ?? "Satın alma başarısız", "error");
      return false;
    },
    [gold, updateGold, addToast]
  );

  /** Simulate gem purchase (for dev/testing) */
  const purchaseGemPackage = useCallback(
    async (packageId: string): Promise<boolean> => {
      const pkg = GEM_PACKAGES.find((p) => p.id === packageId);
      if (!pkg) {
        addToast("Geçersiz paket", "error");
        return false;
      }
      setIsPurchasing(true);
      // In production, this would go through IAP validation
      const res = await api.post(APIEndpoints.SHOP_BUY, {
        package_id: packageId,
        gems: pkg.gems + pkg.bonus,
      });
      setIsPurchasing(false);
      if (res.success) {
        updateGems(gems + pkg.gems + pkg.bonus);
        addToast(`+${pkg.gems + pkg.bonus} gem eklendi!`, "success");
        return true;
      }
      addToast(res.error ?? "Satın alma başarısız", "error");
      return false;
    },
    [gems, updateGems, addToast]
  );

  return {
    offers,
    gemPackages: GEM_PACKAGES,
    isLoading,
    isPurchasing,
    fetchOffers,
    purchaseWithGems,
    purchaseWithGold,
    purchaseGemPackage,
  };
}
