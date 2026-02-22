// ============================================================
// Shop Page — Kaynak: ShopManager.gd (292 satır) + Godot ShopScreen 4 tab
// Gem paketleri, teklifler, battle pass, eşya mağazası
// ============================================================

"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { useShop } from "@/hooks/useShop";
import { useSeason } from "@/hooks/useSeason";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";

type ShopTab = "gems" | "offers" | "battlepass" | "items";

interface ShopItem {
  id: string;
  name: string;
  icon: string;
  price: number;
  currency: "gold" | "gems";
  description: string;
  rarity: string;
}

const SHOP_ITEMS: ShopItem[] = [
  { id: "si1", name: "Sağlık İksiri", icon: "🧪", price: 100, currency: "gold", description: "50 HP yeniler", rarity: "common" },
  { id: "si2", name: "Mana İksiri", icon: "💧", price: 150, currency: "gold", description: "30 MP yeniler", rarity: "common" },
  { id: "si3", name: "Güç Scrollu", icon: "📜", price: 500, currency: "gold", description: "+10% saldırı (5dk)", rarity: "uncommon" },
  { id: "si4", name: "Koruma Scrollu", icon: "🛡️", price: 500, currency: "gold", description: "+10% savunma (5dk)", rarity: "uncommon" },
  { id: "si5", name: "Enerji İksiri", icon: "⚡", price: 50, currency: "gems", description: "20 enerji yeniler", rarity: "rare" },
  { id: "si6", name: "Deneyim Kitabı", icon: "📖", price: 200, currency: "gems", description: "5,000 XP verir", rarity: "rare" },
  { id: "si7", name: "Nadir Sandık", icon: "🎁", price: 300, currency: "gems", description: "Nadir+ eşya garantili", rarity: "epic" },
  { id: "si8", name: "Efsanevi Sandık", icon: "✨", price: 800, currency: "gems", description: "Efsanevi eşya şansı!", rarity: "legendary" },
];

const RARITY_BG: Record<string, string> = {
  common: "border-gray-500/30", uncommon: "border-green-500/30", rare: "border-blue-500/30",
  epic: "border-purple-500/30", legendary: "border-yellow-500/30",
};

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
  const [activeTab, setActiveTab] = useState<ShopTab>("gems");

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

  const buyItem = async (item: ShopItem) => {
    if (item.currency === "gems" && gems < item.price) { addToast("Yetersiz gem!", "error"); return; }
    if (item.currency === "gold" && gold < item.price) { addToast("Yetersiz altın!", "error"); return; }
    setBuyingId(item.id);
    try {
      const res = await api.post("/rest/v1/rpc/buy_shop_item", {
        p_item_id: item.id,
        p_currency: item.currency,
        p_price: item.price,
      });
      if (res.success) {
        addToast(`${item.name} satın alındı!`, "success");
        // Refresh player balance
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

      {/* 4 Tabs */}
      <div className="flex gap-1.5">
        {tabDefs.map((tab) => (
          <button key={tab.key}
            className={`flex-1 py-2 rounded-lg text-xs font-medium transition-colors ${
              activeTab === tab.key ? "bg-[var(--primary)] text-white" : "bg-[var(--card-bg)] text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveTab(tab.key)}>
            {tab.label}
          </button>
        ))}
      </div>

      {/* ─── Gem Packages ─── */}
      {activeTab === "gems" && (
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

      {/* ─── Items ─── */}
      {activeTab === "items" && (
        <div className="space-y-2">
          {SHOP_ITEMS.map((item) => (
            <Card key={item.id}>
              <div className={`flex items-center gap-3 p-3 border-l-4 ${RARITY_BG[item.rarity]}`}>
                <span className="text-2xl">{item.icon}</span>
                <div className="flex-1">
                  <h3 className="text-sm font-medium text-[var(--text-primary)]">{item.name}</h3>
                  <p className="text-[10px] text-[var(--text-muted)]">{item.description}</p>
                </div>
                <Button variant="primary" size="sm" onClick={() => buyItem(item)} disabled={buyingId === item.id}>
                  {buyingId === item.id ? "..." : item.currency === "gems" ? `💎${item.price}` : `🪙${item.price}`}
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
