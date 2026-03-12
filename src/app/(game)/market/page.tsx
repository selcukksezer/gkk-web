// ============================================================
// Market Page — Kaynak: scenes/ui/screens/PazarScreen.gd
// 3 sekmeli: Gözat, Sat, Siparişlerim
// ============================================================

"use client";

import { useEffect, useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useMarketStore } from "@/stores/marketStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { formatGold } from "@/lib/utils/string";
import { timeAgo } from "@/lib/utils/datetime";
import { getRarityColor, getRarityLabel } from "@/types/item";
import type { MarketOrder } from "@/types/market";

type MarketTab = "browse" | "sell" | "orders";

// Godot: PazarScreen.gd category filter — CATEGORY_FILTERS
const CATEGORY_FILTERS = [
  { key: "", label: "Tümü" },
  { key: "weapon", label: "⚔️ Silah" },
  { key: "armor", label: "🛡️ Zırh" },
  { key: "consumable", label: "🧪 İksir" },
  { key: "material", label: "🪨 Malzeme" },
  { key: "accessory", label: "💍 Aksesuar" },
];

// Godot: PazarScreen.gd rarity filter — RARITY_FILTERS
const RARITY_FILTERS = [
  { key: "", label: "Tüm Nadirlik" },
  { key: "common", label: "Yaygın" },
  { key: "uncommon", label: "Olağandışı" },
  { key: "rare", label: "Nadir" },
  { key: "epic", label: "Destansı" },
  { key: "legendary", label: "Efsanevi" },
];

export default function MarketPage() {
  const tickers = useMarketStore((s) => s.tickers);
  const orderBook = useMarketStore((s) => s.orderBook);
  const myOrders = useMarketStore((s) => s.myOrders);
  const fetchTickers = useMarketStore((s) => s.fetchTickers);
  const fetchOrderBook = useMarketStore((s) => s.fetchOrderBook);
  const fetchMyOrders = useMarketStore((s) => s.fetchMyOrders);
  const createOrder = useMarketStore((s) => s.createOrder);
  const cancelOrder = useMarketStore((s) => s.cancelOrder);
  const isLoading = useMarketStore((s) => s.isLoading);

  const items = useInventoryStore((s) => s.items);
  const gold = usePlayerStore((s) => s.gold);
  const addToast = useUiStore((s) => s.addToast);

  const [tab, setTab] = useState<MarketTab>("browse");
  const [search, setSearch] = useState("");
  // Godot: PazarScreen._on_category_changed / _on_rarity_changed
  const [categoryFilter, setCategoryFilter] = useState("");
  const [rarityFilter, setRarityFilter] = useState("");
  const [buyConfirm, setBuyConfirm] = useState<MarketOrder | null>(null);
  const [sellItem, setSellItem] = useState<{
    row_id: string;
    name: string;
    price: string;
    quantity: string;
  } | null>(null);

  useEffect(() => {
    fetchTickers();
    fetchMyOrders();
  }, [fetchTickers, fetchMyOrders]);

  useEffect(() => {
    if (tab === "browse") fetchTickers();
    if (tab === "orders") fetchMyOrders();
  }, [tab, fetchTickers, fetchMyOrders]);

  // Filter tickers by search, category, rarity — Godot: _apply_filters
  const filteredTickers = useMemo(() => {
    return tickers.filter((t) => {
      if (search.trim()) {
        const q = search.toLowerCase();
        if (!t.item_name.toLowerCase().includes(q) && !t.item_type?.toLowerCase().includes(q)) {
          return false;
        }
      }
      if (categoryFilter && t.item_type !== categoryFilter) return false;
      if (rarityFilter && t.rarity !== rarityFilter) return false;
      return true;
    });
  }, [tickers, search, categoryFilter, rarityFilter]);

  // Items for sell tab (show market-locked items as disabled with reason)
  const tradeableItems = useMemo(() => {
    return items.filter((i) => i.is_tradeable && !i.is_equipped);
  }, [items]);

  const handleBuy = async (order: MarketOrder) => {
    if (gold < order.price) {
      addToast("Yeterli altın yok", "warning");
      return;
    }
    
    // CAPACITY CHECK: ensure inventory has space for purchase
    const invStore = useInventoryStore.getState?.() || { canAddItem: () => ({ canAdd: false }) };
    const capacityCheck = invStore.canAddItem?.(order.item_id, 1) || { canAdd: false };
    if (!capacityCheck.canAdd) {
      addToast(capacityCheck.reason || "Envanter dolu! Satın alma yapılamıyor.", "error");
      return;
    }
    
    try {
      const res = await api.rpc("purchase_market_listing", { p_order_id: order.order_id, p_quantity: 1 });
      if (res.success) {
        addToast(`${order.item_name} satın alındı!`, "success");
        fetchTickers();
      } else {
        addToast(res.error || "Satın alma başarısız", "error");
      }
    } catch {
      addToast("Satın alma başarısız", "error");
    }
    setBuyConfirm(null);
  };

  const handleSell = async () => {
    if (!sellItem) return;
    const price = parseInt(sellItem.price);
    const qty = parseInt(sellItem.quantity) || 1;
    if (isNaN(price) || price <= 0) {
      addToast("Geçerli bir fiyat girin", "warning");
      return;
    }
    try {
      await createOrder(sellItem.row_id, "sell", qty, price);
      addToast("Satış emri oluşturuldu!", "success");
      setSellItem(null);
    } catch {
      addToast("Satış emri oluşturulamadı", "error");
    }
  };

  const handleCancelOrder = async (orderId: string) => {
    try {
      await cancelOrder(orderId);
      addToast("Sipariş iptal edildi", "success");
    } catch {
      addToast("İptal başarısız", "error");
    }
  };

  return (
    <div className="p-4 space-y-4">
      <h2 className="text-lg font-bold text-[var(--text-primary)]">🏪 Pazar</h2>

      {/* Tabs */}
      <div className="flex gap-1">
        {([
          { key: "browse" as MarketTab, label: "📋 Gözat" },
          { key: "sell" as MarketTab, label: "💰 Sat" },
          { key: "orders" as MarketTab, label: "📦 Siparişlerim" },
        ]).map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`flex-1 py-2 text-xs font-medium rounded-lg transition-colors ${
              tab === t.key
                ? "bg-[var(--accent)] text-white"
                : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Browse Tab */}
      {tab === "browse" && (
        <div className="space-y-3">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Eşya ara..."
            className="w-full px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)]"
          />
          {/* Category & Rarity filters — Godot: PazarScreen._on_category_changed */}
          <div className="flex gap-2">
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              className="flex-1 px-2 py-1.5 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-xs text-[var(--text-primary)] focus:outline-none focus:border-[var(--accent)]"
            >
              {CATEGORY_FILTERS.map((f) => (
                <option key={f.key} value={f.key}>{f.label}</option>
              ))}
            </select>
            <select
              value={rarityFilter}
              onChange={(e) => setRarityFilter(e.target.value)}
              className="flex-1 px-2 py-1.5 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-xs text-[var(--text-primary)] focus:outline-none focus:border-[var(--accent)]"
            >
              {RARITY_FILTERS.map((f) => (
                <option key={f.key} value={f.key}>{f.label}</option>
              ))}
            </select>
          </div>
          {isLoading ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">
              Yükleniyor...
            </div>
          ) : filteredTickers.length === 0 ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">
              Sonuç bulunamadı
            </div>
          ) : (
            filteredTickers.map((ticker) => (
              <Card key={ticker.item_id}>
                <div className="p-3 flex items-center justify-between">
                  <div>
                    <p
                      className="text-sm font-semibold"
                      style={{ color: getRarityColor(ticker.rarity) }}
                    >
                      {ticker.item_name}
                    </p>
                    <p className="text-xs text-[var(--text-muted)]">
                      {getRarityLabel(ticker.rarity)} • {ticker.volume || 0} adet
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-bold text-[var(--color-gold)]">
                      🪙 {formatGold(ticker.lowest_price)}
                    </p>
                    {ticker.price_change !== undefined && (
                      <p
                        className={`text-[10px] ${
                          ticker.price_change >= 0
                            ? "text-[var(--color-success)]"
                            : "text-[var(--color-error)]"
                        }`}
                      >
                        {ticker.price_change >= 0 ? "▲" : "▼"}{" "}
                        {Math.abs(ticker.price_change)}%
                      </p>
                    )}
                  </div>
                </div>
              </Card>
            ))
          )}
        </div>
      )}

      {/* Sell Tab */}
      {tab === "sell" && (
        <div className="space-y-2">
          {tradeableItems.length === 0 ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">
              Satılabilir eşya yok
            </div>
          ) : (
            tradeableItems.map((item) => (
              <Card key={item.row_id}>
                <div className="p-3 flex items-center justify-between">
                  <div>
                    <p
                      className="text-sm font-semibold"
                      style={{ color: getRarityColor(item.rarity) }}
                    >
                      {item.name}
                    </p>
                    <p className="text-xs text-[var(--text-muted)]">
                      {item.quantity > 1 ? `${item.quantity} adet` : getRarityLabel(item.rarity)}
                    </p>
                  </div>
                  <div className="flex flex-col items-end gap-1">
                    <Button
                      variant="gold"
                      size="sm"
                      disabled={item.is_market_tradeable === false || item.is_han_only === true}
                      onClick={() =>
                        setSellItem({
                          row_id: item.row_id,
                          name: item.name,
                          price: String(item.base_price || 100),
                          quantity: "1",
                        })
                      }
                    >
                      Sat
                    </Button>
                    {(item.is_market_tradeable === false || item.is_han_only === true) && (
                      <p className="text-[10px] text-[var(--color-warning)] text-right max-w-[180px]">
                        Bu eşya pazarda satılamaz (Han-only)
                      </p>
                    )}
                  </div>
                </div>
              </Card>
            ))
          )}
        </div>
      )}

      {/* My Orders Tab */}
      {tab === "orders" && (
        <div className="space-y-2">
          {myOrders.length === 0 ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">
              Aktif sipariş yok
            </div>
          ) : (
            myOrders.map((order) => (
              <Card key={order.order_id}>
                <div className="p-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-semibold text-[var(--text-primary)]">
                        {order.item_name}
                      </p>
                      <p className="text-xs text-[var(--text-muted)]">
                        🪙 {formatGold(order.price)} • Adet: {order.quantity}
                      </p>
                    </div>
                    <Button
                      variant="danger"
                      size="sm"
                      onClick={() => handleCancelOrder(order.order_id)}
                    >
                      İptal
                    </Button>
                  </div>
                </div>
              </Card>
            ))
          )}
        </div>
      )}

      {/* Sell Modal */}
      <Modal
        isOpen={sellItem !== null}
        onClose={() => setSellItem(null)}
        title={`${sellItem?.name} — Satış Emri`}
        size="sm"
      >
        {sellItem && (
          <div className="space-y-3">
            <div>
              <label className="block text-xs text-[var(--text-secondary)] mb-1">
                Fiyat (Altın)
              </label>
              <input
                type="number"
                value={sellItem.price}
                onChange={(e) =>
                  setSellItem({ ...sellItem, price: e.target.value })
                }
                className="w-full px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-secondary)] mb-1">
                Adet
              </label>
              <input
                type="number"
                value={sellItem.quantity}
                min={1}
                onChange={(e) =>
                  setSellItem({ ...sellItem, quantity: e.target.value })
                }
                className="w-full px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)]"
              />
            </div>
            <div className="flex gap-2">
              <Button
                variant="secondary"
                size="sm"
                fullWidth
                onClick={() => setSellItem(null)}
              >
                Vazgeç
              </Button>
              <Button
                variant="gold"
                size="sm"
                fullWidth
                isLoading={isLoading}
                onClick={handleSell}
              >
                Satış Emri Ver
              </Button>
            </div>
          </div>
        )}
      </Modal>

      {/* Buy Confirm Modal */}
      <Modal
        isOpen={buyConfirm !== null}
        onClose={() => setBuyConfirm(null)}
        title="Satın Alma Onayı"
        size="sm"
      >
        {buyConfirm && (
          <div className="space-y-3">
            <p className="text-sm text-[var(--text-secondary)]">
              <strong>{buyConfirm.item_name}</strong> eşyasını{" "}
              <strong>{formatGold(buyConfirm.price)} altın</strong> karşılığında
              satın almak istiyor musun?
            </p>
            <div className="flex gap-2">
              <Button
                variant="secondary"
                size="sm"
                fullWidth
                onClick={() => setBuyConfirm(null)}
              >
                Vazgeç
              </Button>
              <Button
                variant="primary"
                size="sm"
                fullWidth
                onClick={() => handleBuy(buyConfirm)}
              >
                Satın Al
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
