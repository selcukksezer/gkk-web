// ============================================================
// Shop Page — Kaynak: ShopManager.gd (292 satır) + Godot ShopScreen 5 tab
// Gem paketleri, altın, teklifler, battle pass, eşya mağazası
// ============================================================

"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { useShop } from "@/hooks/useShop";
import type { ShopItemData } from "@/hooks/useShop";
import { useSeason } from "@/hooks/useSeason";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";

type ShopTab = "gems" | "gold" | "offers" | "battlepass" | "items";

const RARITY_BORDER: Record<string, string> = {
  common: "border-l-gray-400",
  uncommon: "border-l-green-500",
  rare: "border-l-blue-500",
  epic: "border-l-purple-500",
  legendary: "border-l-yellow-500",
  mythic: "border-l-red-500",
};

const DEFAULT_RARITY_BORDER = RARITY_BORDER.common;

const RARITY_LABEL: Record<string, string> = {
  common: "Sıradan",
  uncommon: "Yaygın Olmayan",
  rare: "Nadir",
  epic: "Destansı",
  legendary: "Efsanevi",
  mythic: "Mitik",
};

// Godot: ShopScreen._load_gold_packages — altın paketleri (gem ile satın alınır)
const GOLD_PACKAGES: { id: string; gold: number; gemCost: number }[] = [
  { id: "gp1", gold: 5000,   gemCost: 10  },
  { id: "gp2", gold: 15000,  gemCost: 25  },
  { id: "gp3", gold: 50000,  gemCost: 75  },
  { id: "gp4", gold: 150000, gemCost: 200 },
];

export default function ShopPage() {
  const {
    offers,
    shopItems,
    gemPackages,
    isLoading,
    isPurchasing,
    fetchOffers,
    fetchShopItems,
    purchaseWithGems,
    purchaseGemPackage,
  } = useShop();
  const { battlePass, fetchBattlePass, claimReward, purchasePremiumPass } = useSeason();

  const gems = usePlayerStore((s) => s.gems);
  const gold = usePlayerStore((s) => s.gold);
  const addToast = useUiStore((s) => s.addToast);
  const [activeTab, setActiveTab] = useState<ShopTab>("gems");

  useEffect(() => {
    fetchOffers();
    fetchShopItems();
    fetchBattlePass();
  }, [fetchOffers, fetchShopItems, fetchBattlePass]);

  const tabDefs: { key: ShopTab; label: string }[] = [
    { key: "gems",       label: "💎 Gem"    },
    { key: "gold",       label: "💰 Altın"  },
    { key: "offers",     label: "🎁 Teklif" },
    { key: "battlepass", label: "🎫 Pass"   },
    { key: "items",      label: "🛒 Eşya"   },
  ];

  const [buyingId, setBuyingId] = useState<string | null>(null);
  const [buyingGoldId, setBuyingGoldId] = useState<string | null>(null);

  // Godot: ShopScreen._on_gold_package_pressed — gem ile altın satın al
  const buyGoldPackage = async (pkg: { id: string; gold: number; gemCost: number }) => {
    if (gems < pkg.gemCost) { addToast("Yetersiz gem!", "error"); return; }
    setBuyingGoldId(pkg.id);
    try {
      const res = await api.post("/rest/v1/rpc/buy_gold_with_gems", {
        p_gold_amount: pkg.gold,
        p_gem_cost: pkg.gemCost,
      });
      if (res.success) {
        addToast(`${pkg.gold.toLocaleString()} altın satın alındı!`, "success");
        const { usePlayerStore: pStore } = await import("@/stores/playerStore");
        pStore.getState().fetchProfile();
      } else {
        addToast(res.error || "Satın alma başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setBuyingGoldId(null);
    }
  };

  // Godot: ShopScreen._on_item_buy_pressed — quantity destekli satın alma
  // quantities: item id → adet (1..max_stack)
  const [quantities, setQuantities] = useState<Record<string, number>>({});

  const getQty = (itemId: string) => quantities[itemId] ?? 1;
  const setQty = (itemId: string, newQty: number, max: number) =>
    setQuantities((prev) => ({ ...prev, [itemId]: Math.min(Math.max(1, newQty), max) }));

  const buyItem = async (item: ShopItemData) => {
    const qty = getQty(item.id);
    const totalPrice = item.price * qty;
    if (item.currency === "gems" && gems < totalPrice) { addToast("Yetersiz gem!", "error"); return; }
    if (item.currency === "gold" && gold < totalPrice) { addToast("Yetersiz altın!", "error"); return; }
    setBuyingId(item.id);
    try {
      const res = await api.post("/rest/v1/rpc/buy_shop_item", {
        p_item_id: item.id,
        p_currency: item.currency,
        p_price: totalPrice,
        p_quantity: qty,
      });
      if (res.success) {
        addToast(`${item.name} x${qty} satın alındı!`, "success");
        const { usePlayerStore: pStore } = await import("@/stores/playerStore");
        pStore.getState().fetchProfile();
      } else {
        addToast(res.error || `${item.name} satın alınamadı`, "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setBuyingId(null);
    }
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

      {/* 5 Tabs */}
      <div className="flex gap-1 overflow-x-auto">
        {tabDefs.map((tab) => (
          <button key={tab.key}
            className={`flex-1 min-w-[60px] py-2 rounded-lg text-xs font-medium transition-colors whitespace-nowrap ${
              activeTab === tab.key ? "bg-[var(--primary)] text-white" : "bg-[var(--card-bg)] text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveTab(tab.key)}>
            {tab.label}
          </button>
        ))}
      </div>

      {/* ─── Gem Packages (Real Money) ─── */}
      {activeTab === "gems" && (
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
      )}

      {/* ─── Gold Packages (Gem→Gold) — Godot: ShopScreen._populate_gold_packages ─── */}
      {activeTab === "gold" && (
        <div>
          <h3 className="text-xs font-semibold text-[var(--text-muted)] mb-2">🪙 Altın Satın Al (Gem ile)</h3>
          <div className="grid grid-cols-2 gap-3">
            {GOLD_PACKAGES.map((pkg) => {
              const canAfford = gems >= pkg.gemCost;
              return (
                <motion.button
                  key={pkg.id}
                  whileTap={{ scale: canAfford ? 0.97 : 1 }}
                  className={`bg-[var(--card-bg)] border rounded-xl p-4 text-center ${
                    canAfford ? "border-yellow-600/40" : "border-[var(--border)] opacity-60"
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
      )}

      {/* ─── Offers ─── */}
      {activeTab === "offers" && (
        <div className="space-y-3">
          {isLoading ? (
            <p className="text-center text-[var(--text-secondary)] py-8">Yükleniyor...</p>
          ) : offers.length === 0 ? (
            <p className="text-center text-[var(--text-secondary)] py-8">Aktif teklif yok</p>
          ) : (
            offers.map((offer) => (
              <motion.div key={offer.id} whileTap={{ scale: 0.98 }}
                className={`bg-[var(--card-bg)] border rounded-xl p-4 ${offer.is_featured ? "border-[var(--gold)]" : "border-[var(--border)]"}`}>
                {offer.is_featured && (
                  <span className="text-[10px] bg-[var(--gold)] text-black px-2 py-0.5 rounded font-bold">ÖNE ÇIKAN</span>
                )}
                <h3 className="font-bold mt-1">{offer.name}</h3>
                <p className="text-xs text-[var(--text-secondary)] mt-0.5">{offer.description}</p>
                <div className="flex flex-wrap gap-1 mt-2">
                  {offer.rewards.map((r, i) => (
                    <span key={i} className="text-[10px] bg-[var(--surface)] px-2 py-0.5 rounded">{r.type}: {r.amount}</span>
                  ))}
                </div>
                {offer.expires_at && (
                  <p className="text-[10px] text-red-400 mt-2">Bitiş: {new Date(offer.expires_at).toLocaleDateString("tr-TR")}</p>
                )}
                <button
                  className="w-full mt-3 py-2 rounded-lg bg-[var(--primary)] text-white text-sm font-medium disabled:opacity-50"
                  onClick={() => purchaseWithGems(offer.id, offer.price)}
                  disabled={isPurchasing || (offer.currency === "gems" && gems < offer.price)}>
                  {offer.currency === "gems" ? `💎 ${offer.price} Gem` : offer.currency === "gold" ? `🪙 ${offer.price} Altın` : `$${offer.price}`}
                </button>
              </motion.div>
            ))
          )}
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
                  className={`aspect-square rounded-lg border text-xs font-bold flex items-center justify-center transition-colors ${
                    claimed ? "bg-green-500/20 border-green-500 text-green-400" :
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

      {/* ─── Items — Godot: ShopScreen._populate_item_shop ─── */}
      {activeTab === "items" && (
        <div className="space-y-2">
          {shopItems.map((item) => {
            const qty = getQty(item.id);
            const totalPrice = item.price * qty;
            const canAfford = item.currency === "gems" ? gems >= totalPrice : gold >= totalPrice;
            return (
              <Card key={item.id}>
                {/* Rarity border — Godot: ItemCard rarity colour */}
                <div className={`flex items-center gap-3 p-3 border-l-4 ${RARITY_BORDER[item.rarity] ?? DEFAULT_RARITY_BORDER}`}>
                  <span className="text-2xl">{item.icon}</span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5">
                      <h3 className="text-sm font-medium text-[var(--text-primary)] truncate">{item.name}</h3>
                      {/* Rarity label — Godot: ItemCard rarity display */}
                      <span className="text-[9px] text-[var(--text-muted)] shrink-0">
                        {RARITY_LABEL[item.rarity] ?? item.rarity}
                      </span>
                    </div>
                    <p className="text-[10px] text-[var(--text-muted)]">{item.description}</p>
                    {/* Price display — Godot: ItemCard price label */}
                    <p className="text-[10px] font-medium mt-0.5">
                      {item.currency === "gems"
                        ? <span className="text-blue-400">💎 {item.price} / adet</span>
                        : <span className="text-[var(--gold)]">🪙 {item.price} / adet</span>
                      }
                    </p>
                  </div>
                  <div className="flex flex-col items-end gap-1.5 shrink-0">
                    {/* Quantity selector — Godot: SpinBox (1..max_stack) */}
                    <div className="flex items-center gap-1">
                      <button
                        className="w-6 h-6 rounded bg-[var(--surface)] text-[var(--text-primary)] text-sm font-bold leading-none disabled:opacity-40"
                        onClick={() => setQty(item.id, qty - 1, item.max_stack)}
                        disabled={qty <= 1}>
                        −
                      </button>
                      <span className="w-6 text-center text-xs font-medium text-[var(--text-primary)]">{qty}</span>
                      <button
                        className="w-6 h-6 rounded bg-[var(--surface)] text-[var(--text-primary)] text-sm font-bold leading-none disabled:opacity-40"
                        onClick={() => setQty(item.id, qty + 1, item.max_stack)}
                        disabled={qty >= item.max_stack}>
                        +
                      </button>
                    </div>
                    <Button
                      variant="primary"
                      size="sm"
                      onClick={() => buyItem(item)}
                      disabled={buyingId === item.id || !canAfford}>
                      {buyingId === item.id
                        ? "..."
                        : item.currency === "gems"
                          ? `💎 ${totalPrice}`
                          : `🪙 ${totalPrice}`
                      }
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
