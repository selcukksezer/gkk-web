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
import { supabase } from "@/lib/supabase";

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

// Godot: ItemCard.gd shop item data
export interface ShopItemData {
  id: string;
  name: string;
  icon: string;
  price: number;
  currency: "gold" | "gems";
  description: string;
  rarity: string;
  max_stack: number;
}

export interface GemPackage {
  id: string;
  gems: number;
  price: number;
  bonus: number;
  label: string;
}

// Godot: ShopScreen._populate_item_shop — static fallback items
const STATIC_SHOP_ITEMS: ShopItemData[] = [
  { id: "si1", name: "Sağlık İksiri",   icon: "🧪", price: 100,  currency: "gold", description: "50 HP yeniler",             rarity: "common",    max_stack: 99 },
  { id: "si2", name: "Mana İksiri",     icon: "💧", price: 150,  currency: "gold", description: "30 MP yeniler",             rarity: "common",    max_stack: 99 },
  { id: "si3", name: "Güç Scrollu",     icon: "📜", price: 500,  currency: "gold", description: "+10% saldırı (5dk)",        rarity: "uncommon",  max_stack: 10 },
  { id: "si4", name: "Koruma Scrollu",  icon: "🛡️", price: 500,  currency: "gold", description: "+10% savunma (5dk)",        rarity: "uncommon",  max_stack: 10 },
  { id: "si5", name: "Enerji İksiri",   icon: "⚡",  price: 50,   currency: "gems", description: "20 enerji yeniler",         rarity: "rare",      max_stack: 99 },
  { id: "si6", name: "Deneyim Kitabı",  icon: "📖", price: 200,  currency: "gems", description: "5,000 XP verir",            rarity: "rare",      max_stack: 10 },
  { id: "si7", name: "Nadir Sandık",    icon: "🎁", price: 300,  currency: "gems", description: "Nadir+ eşya garantili",     rarity: "epic",      max_stack: 5  },
  { id: "si8", name: "Efsanevi Sandık", icon: "✨", price: 800,  currency: "gems", description: "Efsanevi eşya şansı!",      rarity: "legendary", max_stack: 3  },
];

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
  const [shopItems, setShopItems] = useState<ShopItemData[]>(STATIC_SHOP_ITEMS);
  const [isLoading, setIsLoading] = useState(false);
  const [isPurchasing, setIsPurchasing] = useState(false);

  const gems = usePlayerStore((s) => s.gems);
  const gold = usePlayerStore((s) => s.gold);
  const updateGems = usePlayerStore((s) => s.updateGems);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);

  /** Godot: ItemDatabase.get_all_items() — load shopable items from Supabase */
  const fetchShopItems = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc("get_shop_items");
      if (error) {
        console.warn("[useShop] get_shop_items RPC error, using static fallback:", error.message);
        return;
      }
      if (data && (data as ShopItemData[]).length > 0) {
        setShopItems(data as ShopItemData[]);
      }
    } catch (err) {
      console.warn("[useShop] get_shop_items network error, using static fallback:", err);
    }
  }, []);

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
    shopItems,
    gemPackages: GEM_PACKAGES,
    isLoading,
    isPurchasing,
    fetchOffers,
    fetchShopItems,
    purchaseWithGems,
    purchaseWithGold,
    purchaseGemPackage,
  };
}
