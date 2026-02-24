// ============================================================
// useShop — Mağaza + IAP + Gem paketleri
// Kaynak: ShopManager.gd (292 satır)
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { supabase } from "@/lib/supabase";
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
      console.log("[useShop] purchaseWithGems called:", { itemId, gemCost, currentGems: gems });
      if (gems < gemCost) {
        addToast("Yetersiz gem!", "error");
        return false;
      }
      setIsPurchasing(true);
      const res = await api.post(APIEndpoints.SHOP_BUY, {
        p_item_id: itemId,
        p_currency: "gems",
        p_price: gemCost,
      });
      console.log("[useShop] purchaseWithGems response:", res, "responseData:", (res && (res.data || res.error)));
      setIsPurchasing(false);
      if (res.success) {
        updateGems(gems - gemCost);
        addToast("Satın alma başarılı!", "success");
        // Refresh player profile and inventory
        const { usePlayerStore: pStore } = await import("@/stores/playerStore");
        const { useInventoryStore: invStore } = await import("@/stores/inventoryStore");
        pStore.getState().fetchProfile();
        invStore.getState().fetchInventory();
        // If server returned a simulated success (fallback), try client-side insert
        if ((res.data as any)?.simulated) {
          console.log("[useShop] server returned simulated success — attempting client-side inventory insert", { itemId, gemCost });
          try {
            // Find first empty slot (0-19)
            const { data: slots } = await supabase
              .from("inventory")
              .select("slot_position")
              .gte("slot_position", 0)
              .lte("slot_position", 19);
            const used = Array.isArray(slots) ? slots.map((s: any) => Number(s.slot_position)).filter((n: any) => Number.isInteger(n)) : [];
            let slotPos: number | null = null;
            for (let i = 0; i < 20; i++) {
              if (!used.includes(i)) { slotPos = i; break; }
            }

            const payload: any = { item_id: itemId, quantity: 1, obtained_at: Math.floor(Date.now() / 1000) };
            // CRITICAL: inventory.user_id MUST be Auth UUID (session.user.id)
            // NOT public.users.id (profile.id) — FK, RPCs, RLS all expect auth.users.id
            try {
              const { data: { session: sess } } = await supabase.auth.getSession();
              if (sess?.user?.id) {
                payload.user_id = sess.user.id; // Auth UUID
                console.log("[useShop] client-side insert payload uses Auth UUID:", sess.user.id);
              } else {
                console.warn("[useShop] no auth session — cannot set user_id on payload");
              }
            } catch (e) {
              console.warn("[useShop] failed to attach auth user id to payload:", e);
            }
            if (slotPos !== null) payload.slot_position = slotPos;

            const insertRes = await supabase.from("inventory").insert(payload).select();
            console.log("[useShop] client-side inventory insert result:", insertRes, "assignedSlot:", slotPos);
            await invStore.getState().fetchInventory();
          } catch (e) {
            console.warn("[useShop] client-side inventory insert failed:", e);
          }
        }
        return true;
      }
      console.warn("[useShop] purchaseWithGems failed:", { error: res.error, status: (res as any)?.status });
      addToast(res.error ?? "Satın alma başarısız", "error");
      return false;
    },
    [gems, updateGems, addToast]
  );

    /** Purchase an offer (offers may contain multiple rewards) */
    const purchaseOffer = useCallback(
      async (offer: ShopOffer): Promise<boolean> => {
          console.log("[useShop] purchaseOffer called:", { offerId: offer.id, price: offer.price, currency: offer.currency, gems, gold });
        // Basic affordability check
        if (offer.currency === "gems" && gems < offer.price) {
          addToast("Yetersiz gem!", "error");
          return false;
        }
        if (offer.currency === "gold" && gold < offer.price) {
          addToast("Yetersiz altın!", "error");
          return false;
        }
        setIsPurchasing(true);
        const res = await api.post(APIEndpoints.SHOP_BUY, {
          offer_id: offer.id,
          p_currency: offer.currency,
          p_price: offer.price,
        });
          console.log("[useShop] purchaseOffer response:", res, "responseData:", (res && (res.data || res.error)));
        setIsPurchasing(false);
        if (res.success) {
          // Update balances conservatively
          if (offer.currency === "gems") updateGems(gems - offer.price);
          if (offer.currency === "gold") updateGold(gold - offer.price);
            addToast("Satın alma başarılı!", "success");
          const { usePlayerStore: pStore } = await import("@/stores/playerStore");
          const { useInventoryStore: invStore } = await import("@/stores/inventoryStore");
          pStore.getState().fetchProfile();
            invStore.getState().fetchInventory();
          // Do NOT perform direct client-side item insert for offers
          if ((res.data as any)?.simulated) {
              console.log("[useShop] server simulated offer purchase; refreshed stores only");
          }
            console.log("[useShop] purchaseOffer completed, refreshed stores");
            return true;
        }
          console.warn("[useShop] purchaseOffer failed:", { error: res.error });
          addToast(res.error ?? "Satın alma başarısız", "error");
        return false;
      },
      [gems, gold, updateGems, updateGold, addToast]
    );

  /** Purchase an item with gold */
  const purchaseWithGold = useCallback(
    async (itemId: string, goldCost: number): Promise<boolean> => {
      console.log("[useShop] purchaseWithGold called:", { itemId, goldCost, currentGold: gold });
      if (gold < goldCost) {
        addToast("Yetersiz altın!", "error");
        return false;
      }
      setIsPurchasing(true);
      const res = await api.post(APIEndpoints.SHOP_BUY, {
        p_item_id: itemId,
        p_currency: "gold",
        p_price: goldCost,
      });
      console.log("[useShop] purchaseWithGold response:", res, "responseData:", (res && (res.data || res.error)));
      setIsPurchasing(false);
      if (res.success) {
        updateGold(gold - goldCost);
        addToast("Satın alma başarılı!", "success");
        // Refresh player profile and inventory
        const { usePlayerStore: pStore } = await import("@/stores/playerStore");
        const { useInventoryStore: invStore } = await import("@/stores/inventoryStore");
        pStore.getState().fetchProfile();
        invStore.getState().fetchInventory();
        if ((res.data as any)?.simulated) {
          console.log("[useShop] server returned simulated success — attempting client-side inventory insert", { itemId, goldCost });
          try {
            // CRITICAL: inventory.user_id MUST be Auth UUID (session.user.id)
            try {
              const { data: { session: sess } } = await supabase.auth.getSession();
              const authUuid = sess?.user?.id;
              const row: any = { item_id: itemId, quantity: 1, obtained_at: Math.floor(Date.now() / 1000) };
              if (authUuid) {
                row.user_id = authUuid; // Auth UUID — NOT public.users.id!
                console.log("[useShop] client-side quick insert uses Auth UUID:", authUuid);
              } else {
                console.warn("[useShop] no auth session for gold purchase insert");
              }
              const insertRes = await supabase.from("inventory").insert(row).select();
              console.log("[useShop] client-side inventory insert result:", insertRes);
            } catch (e) {
              console.warn("[useShop] client-side inventory insert failed:", e);
            }
            await invStore.getState().fetchInventory();
          } catch (e) {
            console.warn("[useShop] client-side inventory insert failed:", e);
          }
        }
        return true;
      }
      console.warn("[useShop] purchaseWithGold failed:", { error: res.error });
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
      console.log("[useShop] purchaseGemPackage called:", { packageId, pkg });
      setIsPurchasing(true);
      // In production, this would go through IAP validation
      const res = await api.post(APIEndpoints.SHOP_BUY, {
        package_id: packageId,
        gems: pkg.gems + pkg.bonus,
      });
      console.log("[useShop] purchaseGemPackage response:", res);
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
    // Purchase an offer (do not treat as single item)
    purchaseOffer,
    purchaseWithGold,
    purchaseGemPackage,
  };
}
