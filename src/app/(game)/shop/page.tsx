// ============================================================
// Shop Page — Kaynak: ShopManager.gd (292 satır) + Godot ShopScreen 4 tab
// Gem paketleri, teklifler, battle pass, eşya mağazası
// ============================================================

"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useShop } from "@/hooks/useShop";
import { useSeason } from "@/hooks/useSeason";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { ItemIcon } from "@/components/game/ItemIcon";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { INVENTORY_CAPACITY } from "@/types/inventory";

type ShopTab = "gems" | "offers" | "battlepass" | "items";

interface ShopItem {
  id: string;
  item_id: string;  // NEW: Inventory ile eşleştirme için
  name: string;
  icon: string;
  price: number;
  currency: "gold" | "gems";
  description: string;
  rarity: string;
  item_type?: string;
  is_stackable?: boolean;
  max_stack?: number;
}

// NOTE: shop items are loaded from Supabase; do not use local static fallbacks.

const RARITY_BG: Record<string, string> = {
  common: "border-gray-500/30", uncommon: "border-green-500/30", rare: "border-blue-500/30",
  epic: "border-purple-500/30", legendary: "border-yellow-500/30",
};

const RARITY_RING: Record<string, string> = {
  common: "ring-gray-500/40",
  uncommon: "ring-green-500/50",
  rare: "ring-blue-500/50",
  epic: "ring-purple-500/60",
  legendary: "ring-yellow-500/60",
};

const RARITY_LABEL: Record<string, string> = {
  common: "text-gray-400",
  uncommon: "text-green-400",
  rare: "text-blue-400",
  epic: "text-purple-400",
  legendary: "text-yellow-400",
};

// Godot: ShopScreen._load_gold_packages — altın paketleri (gem ile satın alınır)
const GOLD_PACKAGES: { id: string; gold: number; gemCost: number }[] = [
  { id: "gp1", gold: 5000, gemCost: 10 },
  { id: "gp2", gold: 15000, gemCost: 25 },
  { id: "gp3", gold: 50000, gemCost: 75 },
  { id: "gp4", gold: 150000, gemCost: 200 },
];

export default function ShopPage() {
  const {
    offers,
    gemPackages,
    isLoading,
    isPurchasing,
    fetchOffers,
    purchaseWithGems,
    purchaseGemPackage,
  } = useShop();
  const { battlePass, battlePassProgress, fetchBattlePass, claimReward, purchasePremiumPass } = useSeason();

  const gems = usePlayerStore((s) => s.gems);
  const gold = usePlayerStore((s) => s.gold);
  const addToast = useUiStore((s) => s.addToast);
  const inventoryItems = useInventoryStore((s) => s.items);
  const [activeTab, setActiveTab] = useState<ShopTab>("gems");

  // Quantity dialog for stackable items
  const [quantityDialog, setQuantityDialog] = useState<{ item: ShopItem; maxQty: number } | null>(null);
  const [quantityInput, setQuantityInput] = useState(1);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    fetchOffers();
    fetchBattlePass();
  }, [fetchOffers, fetchBattlePass]);

  const tabDefs: { key: ShopTab; label: string }[] = [
    { key: "gems", label: "💎 Gem" },
    { key: "offers", label: "🎁 Teklif" },
    { key: "battlepass", label: "🎫 Pass" },
    { key: "items", label: "🛒 Eşya" },
  ];

  const [buyingId, setBuyingId] = useState<string | null>(null);
  const [buyingGoldId, setBuyingGoldId] = useState<string | null>(null);
  const buyLockRef = useRef(false); // synchronous guard against double-clicks

  // Items loaded from Supabase via server API (start empty — only Supabase items)
  const [shopItems, setShopItems] = useState<ShopItem[]>([]);

  // Memoized filtered items for search — prevents re-filtering on every render
  const filteredItems = useMemo(() => {
    if (!searchQuery.trim()) return shopItems;
    const q = searchQuery.trim().toLowerCase();
    return shopItems.filter(
      (item) =>
        item.name.toLowerCase().includes(q) ||
        item.description?.toLowerCase().includes(q) ||
        item.item_type?.toLowerCase().includes(q) ||
        item.rarity?.toLowerCase().includes(q)
    );
  }, [shopItems, searchQuery]);

  const isStackableItem = (item: ShopItem): boolean => {
    if (item.is_stackable === true) return true;
    if ((item.max_stack ?? 1) > 1) return true;
    const itemType = String(item.item_type ?? "").toLowerCase();
    return ["potion", "material", "scroll", "rune", "consumable"].includes(itemType);
  };

  const getMaxPurchasableByBalance = (item: ShopItem): number => {
    const unitPrice = Number(item.price || 0);
    if (unitPrice <= 0) return 99;
    const wallet = item.currency === "gems" ? gems : gold;
    return Math.max(0, Math.floor(wallet / unitPrice));
  };

  const getMaxPurchasableByInventory = (item: ShopItem): number => {
    const rows = inventoryItems.filter((row) => !row.is_equipped && row.slot_position >= 0);
    const sameItemRows = rows.filter((row) => row.item_id === item.item_id);
    const occupiedSlots = new Set(rows.map((row) => row.slot_position));
    const freeSlots = Math.max(0, INVENTORY_CAPACITY - occupiedSlots.size);

    if (!isStackableItem(item)) {
      return freeSlots;
    }

    const maxStack = Math.max(
      1,
      Number(item.max_stack ?? sameItemRows[0]?.max_stack ?? 1)
    );

    const existingStackSpace = sameItemRows.reduce((acc, row) => {
      const quantity = Math.max(0, Number(row.quantity ?? 0));
      return acc + Math.max(0, maxStack - quantity);
    }, 0);

    const newSlotSpace = freeSlots * maxStack;
    return Math.max(0, existingStackSpace + newSlotSpace);
  };

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const res = await api.get<ShopItem[]>(APIEndpoints.SHOP_LIST);
        if (res.success && res.data && mounted) {
          setShopItems(res.data);
        } else if (mounted) {
          setShopItems([]);
        }
      } catch (err) {
        if (mounted) setShopItems([]);
      }
    })();
    return () => { mounted = false; };
  }, []);

  // Godot: ShopScreen._on_gold_package_pressed — gem ile altın satın al
  const buyGoldPackage = async (pkg: { id: string; gold: number; gemCost: number }) => {
    if (buyLockRef.current) return; // prevent double-click
    if (gems < pkg.gemCost) { addToast("Yetersiz gem!", "error"); return; }
    buyLockRef.current = true;
    setBuyingGoldId(pkg.id);
    try {
      console.log("[ShopPage] buyGoldPackage called", { pkg, gems });
      const res = await api.post(APIEndpoints.SHOP_BUY, {
        package_id: pkg.id,
        p_gold_amount: pkg.gold,
        p_gem_cost: pkg.gemCost,
      });
      console.log("[ShopPage] buyGoldPackage response:", res);
      if (res.success) {
        addToast(`${pkg.gold.toLocaleString()} altın satın alındı!`, "success");
        const { usePlayerStore: pStore } = await import("@/stores/playerStore");
        pStore.getState().fetchProfile();
      } else {
        console.warn("[ShopPage] buyGoldPackage failed:", res.error);
        addToast(res.error || "Satın alma başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setBuyingGoldId(null);
      buyLockRef.current = false;
    }
  };

  const buyItem = async (item: ShopItem, quantity = 1) => {
    if (buyLockRef.current) return; // prevent double-click
    const safeQuantity = Math.max(1, Math.floor(quantity));
    const totalPrice = item.price * safeQuantity;

    if (item.currency === "gems" && gems < totalPrice) { addToast("Yetersiz gem!", "error"); return; }
    if (item.currency === "gold" && gold < totalPrice) { addToast("Yetersiz altın!", "error"); return; }

    const maxByInventory = getMaxPurchasableByInventory(item);
    if (safeQuantity > maxByInventory) {
      addToast(`Envanter kapasitesi yetersiz. En fazla ${maxByInventory} adet alınabilir.`, "error");
      return;
    }

    buyLockRef.current = true;
    setBuyingId(item.id);
    try {
      console.log("[ShopPage] buyItem called:", {
        item_id: item.item_id,
        id: item.id,
        currency: item.currency,
        unitPrice: item.price,
        quantity: safeQuantity,
        totalPrice,
        gems,
        gold,
      });
      const res = await api.post(APIEndpoints.SHOP_BUY, {
        p_item_id: item.item_id,  // Use item_id not shop id
        p_currency: item.currency,
        p_unit_price: item.price,
        p_price: totalPrice,
        p_quantity: safeQuantity,
      });
      console.log("[ShopPage] buyItem response:", res);
      if (res.success) {
        addToast(`${item.name} x${safeQuantity} satın alındı!`, "success");
        // Refresh player balance AND inventory
        const { usePlayerStore: pStore } = await import("@/stores/playerStore");
        const { useInventoryStore: invStore } = await import("@/stores/inventoryStore");
        await pStore.getState().fetchProfile();
        await invStore.getState().fetchInventory();
      } else {
        console.warn("[ShopPage] buyItem failed:", res.error);
        addToast(res.error || `${item.name} satın alınamadı`, "error");
      }
    } catch (err) {
      console.error("[ShopPage] buyItem error:", err);
      try {
        const { useInventoryStore: invStore } = await import("@/stores/inventoryStore");
        await invStore.getState().fetchInventory();
      } catch (e2) {
        console.warn("[ShopPage] failed to refresh inventory in catch:", e2);
      }
    } finally {
      setBuyingId(null);
      buyLockRef.current = false;
    }
  };

  const handleBuyClick = (item: ShopItem) => {
    if (!isStackableItem(item)) {
      if (getMaxPurchasableByInventory(item) < 1) {
        addToast("Envanter dolu!", "error");
        return;
      }
      void buyItem(item, 1);
      return;
    }

    const byBalance = getMaxPurchasableByBalance(item);
    const byInventory = getMaxPurchasableByInventory(item);
    const maxQty = Math.max(0, Math.min(byBalance, byInventory));
    if (maxQty < 1) {
      addToast(byBalance < 1 ? "Yetersiz bakiye!" : "Envanter kapasitesi yetersiz!", "error");
      return;
    }
    setQuantityInput(1);
    setQuantityDialog({ item, maxQty });
  };

  const confirmQuantityPurchase = async () => {
    if (!quantityDialog) return;
    const qty = Math.max(1, Math.min(quantityInput, quantityDialog.maxQty));
    await buyItem(quantityDialog.item, qty);
    setQuantityDialog(null);
    setQuantityInput(1);
  };

  return (
    <div className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🏪 Mağaza</h1>

      {/* Balance */}
      <div className="flex gap-4 bg-[var(--card-bg)] rounded-xl p-3">
        <div className="flex items-center gap-1.5">
          <span>💎</span>
          <span className="font-bold text-blue-400">{gems}</span>
        </div>
        <div className="flex items-center gap-1.5">
          <span>🪙</span>
          <span className="font-bold text-[var(--gold)]">{gold}</span>
        </div>
      </div>

      {/* 4 Tabs */}
      <div className="flex gap-1.5">
        {tabDefs.map((tab) => (
          <button key={tab.key}
            className={`flex-1 py-2 rounded-lg text-xs font-medium transition-colors ${activeTab === tab.key ? "bg-[var(--primary)] text-white" : "bg-[var(--card-bg)] text-[var(--text-secondary)]"
              }`}
            onClick={() => setActiveTab(tab.key)}>
            {tab.label}
          </button>
        ))}
      </div>

      {/* ─── Gem Packages (Gold→Gem) + Gold Packages (Gem→Gold) ─── */}
      {activeTab === "gems" && (
        <div className="space-y-4">
          <div>
            <h3 className="text-xs font-semibold text-[var(--text-muted)] mb-2">💎 Gem Satın Al (Gerçek Para)</h3>
            <div className="grid grid-cols-2 gap-3">
              {gemPackages.map((pkg) => (
                <motion.button key={pkg.id} whileTap={{ scale: 0.97 }}
                  className="bg-[var(--card-bg)] border border-[var(--border)] rounded-xl p-4 text-center relative overflow-hidden"
                  onClick={() => purchaseGemPackage(pkg.id)} disabled={isPurchasing}>
                  {pkg.bonus > 0 && (
                    <div className="absolute top-0 right-0 bg-green-600 text-[10px] text-white px-2 py-0.5 rounded-bl-lg font-medium">
                      +{pkg.bonus} BONUS
                    </div>
                  )}
                  <p className="text-2xl mb-1">💎</p>
                  <p className="font-bold text-lg text-blue-400">{pkg.gems}</p>
                  {pkg.bonus > 0 && <p className="text-xs text-green-400">+{pkg.bonus} bonus</p>}
                  <p className="text-sm text-[var(--text-secondary)] mt-1">{pkg.label}</p>
                  <div className="mt-2 bg-[var(--primary)] rounded-lg py-1.5 text-white text-sm font-medium">${pkg.price}</div>
                </motion.button>
              ))}
            </div>
          </div>

          {/* Godot: ShopScreen._load_gold_packages — Gem→Gold packages */}
          <div>
            <h3 className="text-xs font-semibold text-[var(--text-muted)] mb-2">🪙 Altın Satın Al (Gem ile)</h3>
            <div className="grid grid-cols-2 gap-3">
              {GOLD_PACKAGES.map((pkg) => {
                const canAfford = gems >= pkg.gemCost;
                return (
                  <motion.button
                    key={pkg.id}
                    whileTap={{ scale: canAfford ? 0.97 : 1 }}
                    className={`bg-[var(--card-bg)] border rounded-xl p-4 text-center ${canAfford ? "border-yellow-600/40" : "border-[var(--border)] opacity-60"
                      }`}
                    onClick={() => buyGoldPackage(pkg)}
                    disabled={isPurchasing || !canAfford || buyingGoldId === pkg.id}
                  >
                    <p className="text-2xl mb-1">🪙</p>
                    <p className="font-bold text-lg text-[var(--gold)]">{pkg.gold.toLocaleString()}</p>
                    <div className="mt-2 bg-blue-600 rounded-lg py-1.5 text-white text-sm font-medium">
                      {buyingGoldId === pkg.id ? "İşleniyor..." : `💎 ${pkg.gemCost} Gem`}
                    </div>
                    {!canAfford && <p className="text-[10px] text-red-400 mt-1">Yetersiz gem</p>}
                  </motion.button>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* ─── Offers ─── */}
      {activeTab === "offers" && (
        <div className="space-y-3">
          {/* Offers intentionally left blank per design — no items shown in Offers tab */}
        </div>
      )}

      {/* ─── Battle Pass ─── */}
      {activeTab === "battlepass" && (
        <div className="space-y-4">
          <Card variant="elevated">
            <div className="p-4">
              <div className="flex items-center justify-between mb-2">
                <h3 className="text-sm font-semibold text-[var(--text-secondary)]">🎫 Battle Pass</h3>
                <span className={`text-xs font-medium ${battlePass.isPremium ? "text-[var(--gold)]" : "text-[var(--text-muted)]"}`}>
                  {battlePass.isPremium ? "⭐ Premium" : "Ücretsiz"}
                </span>
              </div>
              <div className="flex items-center justify-between text-xs text-[var(--text-muted)] mb-2">
                <span>Tier {battlePass.currentTier}/{battlePass.maxTiers}</span>
                <span>{battlePass.currentXp}/{battlePass.xpPerTier} XP</span>
              </div>
              <ProgressBar value={battlePass.currentXp} max={battlePass.xpPerTier} color="accent" size="sm" />
            </div>
          </Card>

          {/* Tier Grid */}
          <div className="grid grid-cols-5 gap-1.5">
            {Array.from({ length: Math.min(30, battlePass.maxTiers) }).map((_, i) => {
              const tier = i + 1;
              const claimed = battlePass.claimedRewards.includes(tier);
              const available = tier <= battlePass.currentTier && !claimed;
              return (
                <button key={tier} onClick={() => available && claimReward(tier)}
                  className={`aspect-square rounded-lg border text-xs font-bold flex items-center justify-center transition-colors ${claimed ? "bg-green-500/20 border-green-500 text-green-400" :
                    available ? "bg-[var(--accent)]/20 border-[var(--accent)] text-[var(--accent)] animate-pulse" :
                      "bg-[var(--bg-input)] border-[var(--border-default)] text-[var(--text-muted)]"
                    }`}>
                  {claimed ? "✓" : tier}
                </button>
              );
            })}
          </div>

          {!battlePass.isPremium && (
            <Button variant="primary" fullWidth onClick={() => purchasePremiumPass()}>
              ⭐ Premium Battle Pass — 💎 500 Gem
            </Button>
          )}
        </div>
      )}

      {/* ─── Items ─── */}
      {activeTab === "items" && (
        <div className="space-y-3">
          {/* Search Bar */}
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)] text-sm pointer-events-none">🔍</span>
            <input
              type="text"
              placeholder="Eşya ara..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-[var(--bg-card)] border border-[var(--border-default)] text-sm text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus:outline-none focus:ring-1 focus:ring-[var(--primary)] transition-all"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery("")}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)] hover:text-[var(--text-primary)] text-xs"
              >
                ✕
              </button>
            )}
          </div>

          {/* Item count */}
          <p className="text-[10px] text-[var(--text-muted)]">
            {filteredItems.length} eşya{searchQuery && " bulundu"}
          </p>

          {/* 4-Column Grid */}
          <div className="grid grid-cols-4 gap-2">
            {filteredItems.map((item) => {
              const rarityRing = RARITY_RING[item.rarity] ?? "ring-gray-500/30";
              const rarityLabel = RARITY_LABEL[item.rarity] ?? "text-gray-400";
              const isBuying = buyingId === item.id;

              return (
                <button
                  key={item.id}
                  onClick={() => handleBuyClick(item)}
                  disabled={isBuying}
                  className="group relative flex flex-col items-center rounded-xl bg-[var(--bg-card)] border border-[var(--border-default)] p-2 pb-1.5 transition-all hover:border-[var(--primary)] hover:bg-[var(--bg-elevated)] active:scale-95 disabled:opacity-50"
                >
                  {/* Icon with rarity ring */}
                  <div className={`w-11 h-11 flex items-center justify-center rounded-lg bg-black/20 ring-2 ${rarityRing} mb-1.5`}>
                    <ItemIcon icon={item.icon} itemType={item.item_type} itemId={item.id} className="text-2xl" />
                  </div>

                  {/* Name */}
                  <p className="text-[10px] font-medium text-[var(--text-primary)] leading-tight text-center line-clamp-2 w-full min-h-[24px]">
                    {item.name}
                  </p>

                  {/* Price tag */}
                  <div className="mt-1 w-full">
                    <div className={`text-[10px] font-bold text-center rounded-md py-0.5 ${item.currency === "gems"
                      ? "bg-blue-500/15 text-blue-400"
                      : "bg-yellow-500/15 text-yellow-400"
                      }`}>
                      {isBuying ? "..." : item.currency === "gems" ? `💎${item.price}` : `🪙${item.price}`}
                    </div>
                  </div>

                  {/* Rarity dot */}
                  <span className={`absolute top-1 right-1 w-1.5 h-1.5 rounded-full ${rarityLabel.replace('text-', 'bg-')}`} />
                </button>
              );
            })}
          </div>

          {filteredItems.length === 0 && (
            <div className="text-center py-8 text-[var(--text-muted)] text-sm">
              {searchQuery ? "Eşya bulunamadı" : "Mağazada eşya yok"}
            </div>
          )}
        </div>
      )}

      <AnimatePresence>
        {quantityDialog && (
          <motion.div
            className="fixed inset-0 z-50 bg-black/60 flex items-center justify-center p-4"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setQuantityDialog(null)}
          >
            <motion.div
              className="w-full max-w-sm rounded-xl border border-[var(--border)] bg-[var(--card-bg)] p-4 space-y-4"
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              onClick={(e) => e.stopPropagation()}
            >
              <div>
                <h3 className="text-sm font-semibold text-[var(--text-primary)]">{quantityDialog.item.name}</h3>
                <p className="text-xs text-[var(--text-secondary)]">Satın alma adedi seç</p>
              </div>

              <div className="flex items-center justify-between rounded-lg border border-[var(--border)] p-2">
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => setQuantityInput((v) => Math.max(1, v - 1))}
                >
                  -
                </Button>
                <span className="text-base font-semibold text-[var(--text-primary)]">
                  <input
                    type="number"
                    min={1}
                    max={quantityDialog.maxQty}
                    value={quantityInput}
                    onChange={(e) => {
                      const val = parseInt(e.target.value, 10);
                      if (!isNaN(val)) setQuantityInput(Math.max(1, Math.min(quantityDialog.maxQty, val)));
                      else if (e.target.value === "") setQuantityInput(1);
                    }}
                    onBlur={() => setQuantityInput((v) => Math.max(1, Math.min(quantityDialog.maxQty, v)))}
                    className="w-16 text-center bg-transparent border-b border-[var(--border)] text-base font-semibold text-[var(--text-primary)] outline-none focus:border-[var(--primary)] [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                  />
                </span>
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => setQuantityInput((v) => Math.min(quantityDialog.maxQty, v + 1))}
                >
                  +
                </Button>
              </div>

              <div className="text-xs text-[var(--text-secondary)] space-y-1">
                <p>Birim: {quantityDialog.item.currency === "gems" ? `💎${quantityDialog.item.price}` : `🪙${quantityDialog.item.price}`}</p>
                <p>Maksimum adet: {quantityDialog.maxQty}</p>
                <p className="font-semibold text-[var(--text-primary)]">
                  Toplam tutar: {quantityDialog.item.currency === "gems"
                    ? `💎${quantityDialog.item.price * quantityInput}`
                    : `🪙${quantityDialog.item.price * quantityInput}`}
                </p>
              </div>

              <div className="flex gap-2">
                <Button variant="secondary" className="flex-1" onClick={() => setQuantityDialog(null)}>
                  İptal
                </Button>
                <Button variant="primary" className="flex-1" onClick={confirmQuantityPurchase}>
                  Satın Al
                </Button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
