// ============================================================
// Shop Page — Floating Glassmorphism MMORPG Market
// Gem paketleri, teklifler, battle pass, eşya mağazası
// ============================================================

"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Gem, CircleDollarSign, Ticket, ShoppingBag, Search, X,
  Sparkles, Star, ChevronRight, Zap, Lock,
  Minus, Plus, ShoppingCart,
} from "lucide-react";
import { useShop } from "@/hooks/useShop";
import { useSeason } from "@/hooks/useSeason";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { ItemIcon } from "@/components/game/ItemIcon";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { INVENTORY_CAPACITY } from "@/types/inventory";

type ShopTab = "gems" | "offers" | "battlepass" | "items";

interface ShopItem {
  id: string;
  item_id: string;
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

// ─── Rarity tokens ────────────────────────────────────────
const RARITY_GLOW: Record<string, string> = {
  common:    "rgba(160,170,190,0.30)",
  uncommon:  "rgba(74,222,128,0.35)",
  rare:      "rgba(96,165,250,0.40)",
  epic:      "rgba(192,132,252,0.45)",
  legendary: "rgba(251,191,36,0.50)",
};

const RARITY_BORDER: Record<string, string> = {
  common:    "rgba(148,163,184,0.25)",
  uncommon:  "rgba(74,222,128,0.30)",
  rare:      "rgba(96,165,250,0.35)",
  epic:      "rgba(192,132,252,0.40)",
  legendary: "rgba(251,191,36,0.45)",
};

const RARITY_TEXT: Record<string, string> = {
  common:    "rgb(160,170,190)",
  uncommon:  "rgb(74,222,128)",
  rare:      "rgb(96,165,250)",
  epic:      "rgb(192,132,252)",
  legendary: "rgb(251,191,36)",
};

const RARITY_LABEL_TR: Record<string, string> = {
  common: "Sıradan", uncommon: "Nadir Değil", rare: "Nadir",
  epic: "Destansı", legendary: "Efsanevi",
};

// Godot: ShopScreen._load_gold_packages — altın paketleri (gem ile satın alınır)
const GOLD_PACKAGES: { id: string; gold: number; gemCost: number }[] = [
  { id: "gp1", gold: 5_000,   gemCost: 10  },
  { id: "gp2", gold: 15_000,  gemCost: 25  },
  { id: "gp3", gold: 50_000,  gemCost: 75  },
  { id: "gp4", gold: 150_000, gemCost: 200 },
];

// ─── Shared glass panel style ─────────────────────────────
const GLASS_PANEL = {
  background:           "linear-gradient(155deg,rgba(20,27,38,0.96),rgba(9,13,21,0.96))",
  border:               "1px solid rgba(255,255,255,0.07)",
  boxShadow:            "0 20px 40px rgba(0,0,0,0.40)",
  backdropFilter:       "blur(12px)",
  WebkitBackdropFilter: "blur(12px)",
} as React.CSSProperties;

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

  // ─── Tab config ─────────────────────────────────────────
  const tabDefs: { key: ShopTab; label: string; icon: React.ReactNode }[] = [
    { key: "gems",       label: "Gem",      icon: <Gem size={13} /> },
    { key: "offers",     label: "Teklif",   icon: <Sparkles size={13} /> },
    { key: "battlepass", label: "Pass",     icon: <Ticket size={13} /> },
    { key: "items",      label: "Eşya",     icon: <ShoppingBag size={13} /> },
  ];

  // ─── JSX ────────────────────────────────────────────────
  return (
    <div
      className="relative min-h-screen overflow-hidden pb-24 pt-4 px-3"
      style={{
        background: [
          "radial-gradient(circle at 15% 10%, rgba(56,189,248,0.10), transparent 40%)",
          "radial-gradient(circle at 85% 20%, rgba(249,115,22,0.10), transparent 35%)",
          "linear-gradient(145deg,#090d14 0%,#101722 55%,#090d14 100%)",
        ].join(","),
      }}
    >
      {/* Ambient orbs */}
      <div className="pointer-events-none absolute -left-16 top-32 h-56 w-56 rounded-full bg-sky-500/8 blur-3xl" />
      <div className="pointer-events-none absolute -right-12 top-12 h-64 w-64 rounded-full bg-orange-400/8 blur-3xl" />
      <div className="pointer-events-none absolute left-1/2 bottom-40 h-48 w-48 -translate-x-1/2 rounded-full bg-violet-500/6 blur-3xl" />

      <div className="relative z-10 space-y-4">

        {/* ── Page header ─────────────────────────────── */}
        <div className="flex items-end justify-between">
          <div>
            <p className="text-[10px] uppercase tracking-[0.18em]" style={{ color: "rgba(100,130,180,0.60)" }}>
              PAZAR
            </p>
            <h1 className="text-2xl font-black text-white leading-none">
              Mağaza
            </h1>
          </div>

          {/* Balance chips */}
          <div className="flex items-center gap-2">
            <BalanceChip icon={<Gem size={12} />} value={gems} color="rgba(96,165,250,0.90)" glow="rgba(96,165,250,0.35)" />
            <BalanceChip icon={<CircleDollarSign size={12} />} value={gold.toLocaleString()} color="rgba(251,191,36,0.90)" glow="rgba(251,191,36,0.30)" />
          </div>
        </div>

        {/* ── Tab bar ─────────────────────────────────── */}
        <div
          className="flex gap-1 rounded-2xl p-1"
          style={GLASS_PANEL}
        >
          {tabDefs.map((tab) => {
            const isActive = activeTab === tab.key;
            return (
              <motion.button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                whileTap={{ scale: 0.95 }}
                className="relative flex-1 flex items-center justify-center gap-1.5 py-2 rounded-xl text-[11px] font-bold transition-colors"
                style={{ color: isActive ? "rgb(186,230,253)" : "rgba(100,130,175,0.60)" }}
              >
                {isActive && (
                  <motion.div
                    layoutId="shop-tab-bg"
                    className="absolute inset-0 rounded-xl"
                    transition={{ type: "spring", stiffness: 320, damping: 28 }}
                    style={{
                      background: "linear-gradient(135deg,rgba(38,99,180,0.55),rgba(56,189,248,0.22))",
                      boxShadow:  "inset 0 1px 0 rgba(255,255,255,0.08)",
                    }}
                  />
                )}
                <span className="relative z-10 flex items-center gap-1.5">
                  {tab.icon}
                  {tab.label}
                </span>
              </motion.button>
            );
          })}
        </div>

        {/* ── Tab content ─────────────────────────────── */}
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.18, ease: "easeOut" }}
          >

            {/* ══════════ GEM TAB ══════════════════════ */}
            {activeTab === "gems" && (
              <div className="space-y-5">

                {/* Gem packages */}
                <SectionLabel icon={<Gem size={11} />} title="Gem Satın Al" subtitle="Gerçek para ile" />
                <div className="grid grid-cols-2 gap-3">
                  {gemPackages.map((pkg) => (
                    <motion.button
                      key={pkg.id}
                      whileTap={{ scale: 0.96 }}
                      onClick={() => purchaseGemPackage(pkg.id)}
                      disabled={isPurchasing}
                      className="relative overflow-hidden rounded-2xl p-4 text-left disabled:opacity-50"
                      style={{
                        ...GLASS_PANEL,
                        background: "linear-gradient(155deg,rgba(30,50,90,0.85),rgba(10,25,55,0.90))",
                      }}
                    >
                      {pkg.bonus > 0 && (
                        <div
                          className="absolute top-0 right-0 rounded-bl-xl px-2 py-0.5 text-[9px] font-black uppercase tracking-wide"
                          style={{ background: "rgba(34,197,94,0.85)", color: "white" }}
                        >
                          +{pkg.bonus} BONUS
                        </div>
                      )}
                      <Gem size={28} style={{ color: "rgba(96,165,250,0.90)", marginBottom: 8 }} />
                      <p className="text-xl font-black" style={{ color: "rgb(186,230,253)" }}>
                        {pkg.gems.toLocaleString()}
                      </p>
                      {pkg.bonus > 0 && (
                        <p className="text-[10px] font-semibold" style={{ color: "rgb(74,222,128)" }}>
                          +{pkg.bonus} bonus gem
                        </p>
                      )}
                      <p className="text-[11px] mt-0.5" style={{ color: "rgba(148,163,184,0.65)" }}>
                        {pkg.label}
                      </p>
                      <div
                        className="mt-3 rounded-xl py-1.5 text-center text-[12px] font-bold"
                        style={{
                          background: "linear-gradient(90deg,rgba(56,189,248,0.85),rgba(99,102,241,0.80))",
                          color: "white",
                          boxShadow: "0 0 16px rgba(56,189,248,0.25)",
                        }}
                      >
                        ${pkg.price}
                      </div>
                    </motion.button>
                  ))}
                </div>

                {/* Gold packages */}
                <SectionLabel icon={<CircleDollarSign size={11} />} title="Altın Satın Al" subtitle="Gem ile" />
                <div className="grid grid-cols-2 gap-3">
                  {GOLD_PACKAGES.map((pkg) => {
                    const canAfford = gems >= pkg.gemCost;
                    const isBuying  = buyingGoldId === pkg.id;
                    return (
                      <motion.button
                        key={pkg.id}
                        whileTap={{ scale: canAfford ? 0.96 : 1 }}
                        onClick={() => buyGoldPackage(pkg)}
                        disabled={isPurchasing || !canAfford || isBuying}
                        className="relative overflow-hidden rounded-2xl p-4 text-left transition-opacity disabled:opacity-50"
                        style={{
                          ...GLASS_PANEL,
                          background: "linear-gradient(155deg,rgba(60,40,10,0.85),rgba(30,18,5,0.90))",
                          border: `1px solid ${canAfford ? "rgba(251,191,36,0.25)" : "rgba(255,255,255,0.06)"}`,
                        }}
                      >
                        <CircleDollarSign size={28} style={{ color: "rgba(251,191,36,0.90)", marginBottom: 8 }} />
                        <p className="text-xl font-black" style={{ color: "rgb(253,230,138)" }}>
                          {pkg.gold.toLocaleString()}
                        </p>
                        <p className="text-[11px]" style={{ color: "rgba(148,163,184,0.60)" }}>altın</p>
                        <div
                          className="mt-3 rounded-xl py-1.5 text-center text-[12px] font-bold"
                          style={{
                            background: canAfford
                              ? "linear-gradient(90deg,rgba(234,179,8,0.85),rgba(249,115,22,0.75))"
                              : "rgba(40,40,40,0.60)",
                            color: canAfford ? "white" : "rgba(150,150,150,0.60)",
                            boxShadow: canAfford ? "0 0 14px rgba(234,179,8,0.22)" : "none",
                          }}
                        >
                          {isBuying ? "İşleniyor..." : (
                            <span className="flex items-center justify-center gap-1">
                              <Gem size={11} /> {pkg.gemCost}
                            </span>
                          )}
                        </div>
                        {!canAfford && (
                          <p className="mt-1 text-center text-[9px]" style={{ color: "rgb(248,113,113)" }}>
                            Yetersiz gem
                          </p>
                        )}
                      </motion.button>
                    );
                  })}
                </div>
              </div>
            )}

            {/* ══════════ OFFERS TAB ════════════════════ */}
            {activeTab === "offers" && (
              <div
                className="rounded-3xl p-10 text-center"
                style={GLASS_PANEL}
              >
                <Sparkles size={40} style={{ color: "rgba(192,132,252,0.50)", margin: "0 auto 12px" }} />
                <p className="text-[13px] font-semibold" style={{ color: "rgba(148,163,184,0.50)" }}>
                  Yakında özel teklifler gelecek
                </p>
              </div>
            )}

            {/* ══════════ BATTLE PASS TAB ══════════════ */}
            {activeTab === "battlepass" && (
              <div className="space-y-4">

                {/* Pass info card */}
                <div className="rounded-3xl p-5 space-y-4" style={GLASS_PANEL}>
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-[10px] uppercase tracking-[0.16em]" style={{ color: "rgba(100,130,180,0.55)" }}>
                        SEZİSON PASS
                      </p>
                      <h3 className="text-lg font-black text-white">Battle Pass</h3>
                    </div>
                    <div
                      className="flex items-center gap-1.5 rounded-full px-3 py-1 text-[11px] font-bold"
                      style={battlePass.isPremium
                        ? { background: "rgba(234,179,8,0.15)", color: "rgb(253,224,71)", border: "1px solid rgba(234,179,8,0.30)" }
                        : { background: "rgba(100,116,139,0.15)", color: "rgba(148,163,184,0.70)", border: "1px solid rgba(148,163,184,0.15)" }
                      }
                    >
                      {battlePass.isPremium ? <Star size={11} /> : <Lock size={11} />}
                      {battlePass.isPremium ? "Premium" : "Ücretsiz"}
                    </div>
                  </div>

                  <div className="flex items-center justify-between text-[11px]" style={{ color: "rgba(100,130,175,0.65)" }}>
                    <span>Tier {battlePass.currentTier}/{battlePass.maxTiers}</span>
                    <span>{battlePass.currentXp}/{battlePass.xpPerTier} XP</span>
                  </div>
                  <ProgressBar value={battlePass.currentXp} max={battlePass.xpPerTier} color="accent" size="sm" />
                </div>

                {/* Tier grid */}
                <div className="grid grid-cols-5 gap-1.5">
                  {Array.from({ length: Math.min(30, battlePass.maxTiers) }).map((_, i) => {
                    const tier       = i + 1;
                    const claimed    = battlePass.claimedRewards.includes(tier);
                    const available  = tier <= battlePass.currentTier && !claimed;

                    let cellStyle: React.CSSProperties = {};
                    let textColor = "rgba(100,116,139,0.55)";

                    if (claimed) {
                      cellStyle = {
                        background: "rgba(34,197,94,0.14)",
                        border: "1px solid rgba(34,197,94,0.35)",
                        boxShadow: "0 0 8px rgba(34,197,94,0.12)",
                      };
                      textColor = "rgb(74,222,128)";
                    } else if (available) {
                      cellStyle = {
                        background: "rgba(56,189,248,0.14)",
                        border: "1px solid rgba(56,189,248,0.35)",
                        boxShadow: "0 0 10px rgba(56,189,248,0.20)",
                      };
                      textColor = "rgb(125,211,252)";
                    } else {
                      cellStyle = {
                        background: "rgba(15,22,35,0.60)",
                        border: "1px solid rgba(255,255,255,0.06)",
                      };
                    }

                    return (
                      <motion.button
                        key={tier}
                        onClick={() => available && claimReward(tier)}
                        whileTap={available ? { scale: 0.90 } : {}}
                        className="aspect-square rounded-xl text-[11px] font-black flex items-center justify-center"
                        style={{ ...cellStyle, color: textColor }}
                        animate={available ? { scale: [1, 1.04, 1] } : {}}
                        transition={available ? { repeat: Infinity, duration: 1.8, ease: "easeInOut" } : {}}
                      >
                        {claimed ? "✓" : tier}
                      </motion.button>
                    );
                  })}
                </div>

                {!battlePass.isPremium && (
                  <motion.button
                    whileTap={{ scale: 0.97 }}
                    onClick={() => purchasePremiumPass()}
                    className="w-full rounded-2xl py-3.5 font-bold text-[13px]"
                    style={{
                      background: "linear-gradient(90deg,rgba(234,179,8,0.85),rgba(249,115,22,0.80))",
                      color: "white",
                      boxShadow: "0 0 24px rgba(234,179,8,0.28)",
                      border: "1px solid rgba(234,179,8,0.35)",
                    }}
                  >
                    <span className="flex items-center justify-center gap-2">
                      <Star size={15} />
                      Premium Battle Pass
                      <span className="flex items-center gap-0.5 opacity-80">
                        — <Gem size={13} /> 500
                      </span>
                    </span>
                  </motion.button>
                )}
              </div>
            )}

            {/* ══════════ ITEMS TAB ════════════════════ */}
            {activeTab === "items" && (
              <div className="space-y-3">

                {/* Search bar */}
                <div
                  className="flex items-center gap-2 rounded-2xl px-3 py-2"
                  style={{ ...GLASS_PANEL, background: "rgba(12,18,32,0.80)" }}
                >
                  <Search size={14} style={{ color: "rgba(100,130,175,0.55)", flexShrink: 0 }} />
                  <input
                    type="text"
                    placeholder="Eşya ara..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="flex-1 bg-transparent text-[12.5px] outline-none"
                    style={{ color: "rgba(186,220,255,0.85)", caretColor: "rgba(96,165,250,0.90)" }}
                  />
                  {searchQuery && (
                    <button onClick={() => setSearchQuery("")} style={{ color: "rgba(100,130,175,0.50)" }}>
                      <X size={13} />
                    </button>
                  )}
                </div>

                {/* Item count */}
                <p className="text-[10px] px-1" style={{ color: "rgba(100,116,139,0.55)" }}>
                  {filteredItems.length} eşya{searchQuery ? ` "${searchQuery}" için bulundu` : ""}
                </p>

                {/* 4-col grid */}
                <div className="grid grid-cols-4 gap-2">
                  {filteredItems.map((item) => {
                    const isBuying   = buyingId === item.id;
                    const glowColor  = RARITY_GLOW[item.rarity]   ?? RARITY_GLOW.common;
                    const borderCol  = RARITY_BORDER[item.rarity]  ?? RARITY_BORDER.common;
                    const textColor  = RARITY_TEXT[item.rarity]    ?? RARITY_TEXT.common;
                    const isGem      = item.currency === "gems";

                    return (
                      <motion.button
                        key={item.id}
                        whileHover={{ y: -2 }}
                        whileTap={{ scale: 0.93 }}
                        onClick={() => handleBuyClick(item)}
                        disabled={isBuying}
                        className="relative flex flex-col items-center rounded-2xl p-2 pb-2 overflow-hidden disabled:opacity-50"
                        style={{
                          background: "linear-gradient(160deg,rgba(18,26,42,0.95),rgba(9,13,21,0.95))",
                          border: `1px solid ${borderCol}`,
                          boxShadow: `0 4px 16px rgba(0,0,0,0.35), 0 0 0 0 ${glowColor}`,
                        }}
                      >
                        {/* Rarity dot */}
                        <span
                          className="absolute top-1.5 right-1.5 w-1.5 h-1.5 rounded-full"
                          style={{ background: textColor, boxShadow: `0 0 5px ${textColor}` }}
                        />

                        {/* Icon */}
                        <div
                          className="w-11 h-11 flex items-center justify-center rounded-xl mb-1.5"
                          style={{
                            background: `radial-gradient(circle,${glowColor},transparent 70%)`,
                            border: `1px solid ${borderCol}`,
                          }}
                        >
                          <ItemIcon icon={item.icon} itemType={item.item_type} itemId={item.id} className="text-2xl" />
                        </div>

                        {/* Name */}
                        <p
                          className="text-[9.5px] font-semibold text-center leading-tight line-clamp-2 w-full min-h-[22px]"
                          style={{ color: "rgba(186,220,255,0.80)" }}
                        >
                          {item.name}
                        </p>

                        {/* Price */}
                        <div
                          className="mt-1.5 w-full rounded-xl py-0.5 text-[10px] font-black text-center flex items-center justify-center gap-0.5"
                          style={{
                            background: isGem
                              ? "rgba(56,189,248,0.13)"
                              : "rgba(234,179,8,0.13)",
                            color: isGem ? "rgb(125,211,252)" : "rgb(253,224,71)",
                            border: isGem ? "1px solid rgba(56,189,248,0.22)" : "1px solid rgba(234,179,8,0.20)",
                          }}
                        >
                          {isBuying ? (
                            <span style={{ color: "rgba(148,163,184,0.60)" }}>...</span>
                          ) : (
                            <>
                              {isGem ? <Gem size={9} /> : <CircleDollarSign size={9} />}
                              {item.price}
                            </>
                          )}
                        </div>
                      </motion.button>
                    );
                  })}
                </div>

                {filteredItems.length === 0 && (
                  <div className="rounded-3xl py-14 text-center" style={GLASS_PANEL}>
                    <ShoppingBag size={36} style={{ color: "rgba(100,130,175,0.25)", margin: "0 auto 10px" }} />
                    <p className="text-[13px]" style={{ color: "rgba(100,130,175,0.45)" }}>
                      {searchQuery ? `"${searchQuery}" için eşya bulunamadı` : "Mağazada henüz eşya yok"}
                    </p>
                  </div>
                )}
              </div>
            )}

          </motion.div>
        </AnimatePresence>
      </div>

      {/* ── Quantity dialog ─────────────────────────── */}
      <AnimatePresence>
        {quantityDialog && (
          <motion.div
            className="fixed inset-0 z-50 flex items-end justify-center p-0 sm:items-center sm:p-4"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            style={{ background: "rgba(2,4,14,0.72)", backdropFilter: "blur(4px)" }}
            onClick={() => setQuantityDialog(null)}
          >
            <motion.div
              className="w-full max-w-sm rounded-t-3xl sm:rounded-3xl p-6 space-y-5"
              style={{
                ...GLASS_PANEL,
                background: "linear-gradient(160deg,rgba(22,30,48,0.98),rgba(9,13,21,0.98))",
              }}
              initial={{ y: 80, opacity: 0 }}
              animate={{ y: 0,  opacity: 1 }}
              exit={{ y: 80,   opacity: 0 }}
              transition={{ type: "spring", stiffness: 280, damping: 26 }}
              onClick={(e) => e.stopPropagation()}
            >
              {/* Header */}
              <div>
                <p className="text-[10px] uppercase tracking-[0.16em]" style={{ color: "rgba(100,130,180,0.55)" }}>
                  SATIN AL
                </p>
                <h3 className="text-[15px] font-black text-white mt-0.5">{quantityDialog.item.name}</h3>
                <p className="text-[11px] mt-1" style={{ color: "rgba(100,130,175,0.60)" }}>
                  Birim: {quantityDialog.item.currency === "gems" ? `💎 ${quantityDialog.item.price}` : `🪙 ${quantityDialog.item.price}`}
                  {" · "}Maks: {quantityDialog.maxQty}
                </p>
              </div>

              {/* Qty stepper */}
              <div
                className="flex items-center justify-between rounded-2xl px-4 py-3"
                style={{ background: "rgba(10,16,30,0.70)", border: "1px solid rgba(255,255,255,0.07)" }}
              >
                <motion.button
                  whileTap={{ scale: 0.88 }}
                  onClick={() => setQuantityInput((v) => Math.max(1, v - 1))}
                  className="w-9 h-9 rounded-xl flex items-center justify-center"
                  style={{ background: "rgba(56,189,248,0.12)", color: "rgb(125,211,252)", border: "1px solid rgba(56,189,248,0.20)" }}
                >
                  <Minus size={14} />
                </motion.button>

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
                  className="w-16 bg-transparent text-center text-xl font-black outline-none [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                  style={{ color: "white" }}
                />

                <motion.button
                  whileTap={{ scale: 0.88 }}
                  onClick={() => setQuantityInput((v) => Math.min(quantityDialog.maxQty, v + 1))}
                  className="w-9 h-9 rounded-xl flex items-center justify-center"
                  style={{ background: "rgba(56,189,248,0.12)", color: "rgb(125,211,252)", border: "1px solid rgba(56,189,248,0.20)" }}
                >
                  <Plus size={14} />
                </motion.button>
              </div>

              {/* Total */}
              <div
                className="rounded-2xl px-4 py-2.5 flex items-center justify-between"
                style={{ background: "rgba(10,16,30,0.55)", border: "1px solid rgba(255,255,255,0.05)" }}
              >
                <span className="text-[11px]" style={{ color: "rgba(148,163,184,0.60)" }}>Toplam tutar</span>
                <span className="text-[14px] font-black flex items-center gap-1" style={{ color: "white" }}>
                  {quantityDialog.item.currency === "gems"
                    ? <><Gem size={13} style={{ color: "rgb(125,211,252)" }} />{quantityDialog.item.price * quantityInput}</>
                    : <><CircleDollarSign size={13} style={{ color: "rgb(253,224,71)" }} />{(quantityDialog.item.price * quantityInput).toLocaleString()}</>
                  }
                </span>
              </div>

              {/* Buttons */}
              <div className="flex gap-2">
                <motion.button
                  whileTap={{ scale: 0.96 }}
                  onClick={() => setQuantityDialog(null)}
                  className="flex-1 rounded-2xl py-3 text-[13px] font-bold"
                  style={{ background: "rgba(30,40,60,0.60)", color: "rgba(148,163,184,0.70)", border: "1px solid rgba(255,255,255,0.07)" }}
                >
                  İptal
                </motion.button>
                <motion.button
                  whileTap={{ scale: 0.96 }}
                  onClick={confirmQuantityPurchase}
                  className="flex-1 rounded-2xl py-3 text-[13px] font-bold flex items-center justify-center gap-1.5"
                  style={{
                    background: "linear-gradient(90deg,rgba(56,189,248,0.85),rgba(99,102,241,0.80))",
                    color: "white",
                    boxShadow: "0 0 20px rgba(56,189,248,0.22)",
                    border: "1px solid rgba(56,189,248,0.30)",
                  }}
                >
                  <ShoppingCart size={14} />
                  Satın Al
                </motion.button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── Helper: section label ────────────────────────────────
function SectionLabel({ icon, title, subtitle }: { icon: React.ReactNode; title: string; subtitle: string }) {
  return (
    <div className="flex items-center gap-2 px-1">
      <span style={{ color: "rgba(96,165,250,0.60)" }}>{icon}</span>
      <span className="text-[11px] font-black uppercase tracking-[0.14em]" style={{ color: "rgba(148,180,230,0.65)" }}>
        {title}
      </span>
      <span className="text-[10px]" style={{ color: "rgba(100,116,139,0.40)" }}>— {subtitle}</span>
    </div>
  );
}

// ─── Helper: balance chip ─────────────────────────────────
function BalanceChip({ icon, value, color, glow }: {
  icon: React.ReactNode;
  value: string | number;
  color: string;
  glow: string;
}) {
  return (
    <div
      className="flex items-center gap-1.5 rounded-full px-2.5 py-1"
      style={{
        background: "rgba(9,13,20,0.70)",
        border: `1px solid ${glow}`,
        boxShadow: `0 0 10px ${glow}`,
      }}
    >
      <span style={{ color, filter: `drop-shadow(0 0 4px ${glow})` }}>{icon}</span>
      <span className="text-[11px] font-black tabular-nums" style={{ color: "rgba(186,220,255,0.90)" }}>
        {typeof value === "number" ? value.toLocaleString() : value}
      </span>
    </div>
  );
}
