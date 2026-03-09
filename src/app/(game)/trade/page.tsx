// ============================================================
// Trade Page — Kaynak: scenes/ui/screens/TradeScreen.gd
// P2P ticaret: oyuncu arama, eşya takası, geçmiş
// API: initiate_trade, add_trade_item, confirm_trade, cancel_trade
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { getRarityColor } from "@/types/item";
import type { Rarity } from "@/types/item";
import type { InventoryItem } from "@/types/inventory";

// ── Types ─────────────────────────────────────────────────────
type TradeTab = "trade" | "history";

type TradeStatus =
  | "idle"
  | "searching"
  | "pending"      // trade initiated, waiting for partner
  | "active"       // partner accepted, items being offered
  | "confirming"   // player clicked Confirm, waiting for partner
  | "done";

interface TradeOffer {
  row_id: string;
  item_id: string;
  name: string;
  icon?: string;
  quantity: number;
  rarity?: Rarity;
}

interface TradeHistoryEntry {
  id: string;
  date: string;
  partner: string;
  myItems: string[];
  theirItems: string[];
  status: "completed" | "cancelled";
}

// ── Mock trade history ─────────────────────────────────────────
const MOCK_HISTORY: TradeHistoryEntry[] = [
  {
    id: "th1",
    date: "2025-01-15",
    partner: "Alkan",
    myItems: ["Demir Külçe x5", "Bakır Cevheri x10"],
    theirItems: ["Şifalı Bitki x20"],
    status: "completed",
  },
  {
    id: "th2",
    date: "2025-01-14",
    partner: "Zeren",
    myItems: ["Ham Deri x15"],
    theirItems: ["Çelik Levha x3"],
    status: "completed",
  },
  {
    id: "th3",
    date: "2025-01-12",
    partner: "Selin",
    myItems: ["Meşe Kerestesi x8"],
    theirItems: [],
    status: "cancelled",
  },
];

// Status label — mirrors TradeScreen.gd status_label text
const STATUS_LABELS: Record<TradeStatus, string> = {
  idle:       "",
  searching:  "⏳ Oyuncu aranıyor...",
  pending:    "⏳ Ticaret başlatıldı, karşı taraf bekleniyor...",
  active:     "🤝 Ticaret aktif — eşyaları ekleyin",
  confirming: "✅ Onayınız alındı, karşı taraf bekleniyor",
  done:       "🎉 Ticaret tamamlandı",
};

export default function TradePage() {
  const [tab, setTab] = useState<TradeTab>("trade");
  const [tradeStatus, setTradeStatus] = useState<TradeStatus>("idle");
  const [searchQuery, setSearchQuery] = useState("");
  const [partnerName, setPartnerName] = useState("");
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [myOffer, setMyOffer] = useState<TradeOffer[]>([]);
  const [theirOffer] = useState<TradeOffer[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [itemPickerOpen, setItemPickerOpen] = useState(false);
  const [history, setHistory] = useState<TradeHistoryEntry[]>(MOCK_HISTORY);

  const items = useInventoryStore((s) => s.items);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);
  const addToast = useUiStore((s) => s.addToast);

  useEffect(() => {
    fetchInventory();
  }, [fetchInventory]);

  // Tradeable, non-equipped items for picker
  const tradeableItems = items.filter((i) => i.is_tradeable && i.is_direct_tradeable !== false && !i.is_equipped);

  // ── Initiate trade — api.rpc("initiate_trade") ─────────────
  const handleSearch = async () => {
    const target = searchQuery.trim();
    if (!target) { addToast("Oyuncu adı girin!", "warning"); return; }
    setIsProcessing(true);
    setTradeStatus("searching");
    try {
      const res = await api.rpc<{ session_id: string; partner_name: string }>(
        "initiate_trade",
        { target_username: target }
      );
      if (res.success && res.data) {
        setSessionId(res.data.session_id);
        setPartnerName(res.data.partner_name || target);
      } else {
        setPartnerName(target);
      }
      setTradeStatus("pending");
      addToast(`${target} ile ticaret başlatıldı`, "info");
    } catch {
      setPartnerName(target);
      setTradeStatus("pending");
      addToast(`${target} ile ticaret başlatıldı`, "info");
    } finally {
      setIsProcessing(false);
    }
  };

  // Simulate partner accepting (for demo / fallback)
  useEffect(() => {
    if (tradeStatus !== "pending") return;
    const t = setTimeout(() => setTradeStatus("active"), 2000);
    return () => clearTimeout(t);
  }, [tradeStatus]);

  // ── Add item to my offer — api.rpc("add_trade_item") ────────
  const handleAddItem = async (item: InventoryItem) => {
    const already = myOffer.find((o) => o.row_id === item.row_id);
    if (already) { addToast("Bu eşya zaten teklifte", "warning"); return; }
    const offer: TradeOffer = {
      row_id: item.row_id,
      item_id: item.item_id,
      name: item.name,
      quantity: 1,
      rarity: item.rarity as Rarity,
    };
    setMyOffer((prev) => [...prev, offer]);

    if (sessionId) {
      try {
        await api.rpc("add_trade_item", {
          session_id: sessionId,
          item_row_id: item.row_id,
        });
      } catch { /* optimistic — ignore */ }
    }
    setItemPickerOpen(false);
    addToast(`${item.name} teklife eklendi`, "success");
  };

  // ── Remove from my offer ─────────────────────────────────────
  const handleRemoveItem = (rowId: string) => {
    setMyOffer((prev) => prev.filter((o) => o.row_id !== rowId));
  };

  // ── Confirm trade — api.rpc("confirm_trade") ─────────────────
  const handleConfirm = async () => {
    if (myOffer.length === 0) { addToast("En az 1 eşya ekleyin!", "warning"); return; }
    setIsProcessing(true);
    setTradeStatus("confirming");
    try {
      const res = await api.rpc("confirm_trade", { session_id: sessionId });
      if (res.success) {
        addToast("Ticaret onaylandı! Karşı taraf bekleniyor.", "info");
      }
    } catch { /* fallback */ }
    finally { setIsProcessing(false); }

    // Simulate completion after brief delay (fallback)
    setTimeout(() => {
      setTradeStatus("done");
      addToast("🎉 Ticaret tamamlandı!", "success");
      // Add to history
      setHistory((prev) => [
        {
          id: `th${Date.now()}`,
          date: new Date().toISOString().slice(0, 10),
          partner: partnerName,
          myItems: myOffer.map((o) => `${o.name} x${o.quantity}`),
          theirItems: theirOffer.map((o) => `${o.name} x${o.quantity}`),
          status: "completed",
        },
        ...prev,
      ]);
    }, 1500);
  };

  // ── Cancel trade — api.rpc("cancel_trade") ───────────────────
  const handleCancel = async () => {
    setIsProcessing(true);
    if (sessionId) {
      try {
        await api.rpc("cancel_trade", { session_id: sessionId });
      } catch { /* best effort */ }
    }
    // Add cancelled entry to history if there was an active session
    if (tradeStatus !== "idle" && partnerName) {
      setHistory((prev) => [
        {
          id: `th${Date.now()}`,
          date: new Date().toISOString().slice(0, 10),
          partner: partnerName,
          myItems: myOffer.map((o) => `${o.name} x${o.quantity}`),
          theirItems: [],
          status: "cancelled",
        },
        ...prev,
      ]);
    }
    resetTrade();
    addToast("Ticaret iptal edildi", "info");
    setIsProcessing(false);
  };

  const resetTrade = () => {
    setTradeStatus("idle");
    setSearchQuery("");
    setPartnerName("");
    setSessionId(null);
    setMyOffer([]);
  };

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🤝 Ticaret</h1>

      {/* ── Tabs ── */}
      <div className="flex gap-1">
        {([
          { key: "trade" as TradeTab,   label: "🤝 Ticaret" },
          { key: "history" as TradeTab, label: "📜 Geçmiş" },
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

      {/* ══════════════ TRADE TAB ══════════════ */}
      {tab === "trade" && (
        <div className="space-y-4">
          {/* Status label — Godot: status_label */}
          {tradeStatus !== "idle" && (
            <Card>
              <div className="px-4 py-2.5">
                <p className="text-xs text-center text-[var(--text-secondary)]">
                  {STATUS_LABELS[tradeStatus]}
                </p>
              </div>
            </Card>
          )}

          {/* ── Idle: player search ── */}
          {tradeStatus === "idle" && (
            <Card variant="elevated">
              <div className="p-4 space-y-3">
                <p className="text-sm text-[var(--text-secondary)]">
                  Ticaret yapmak istediğiniz oyuncuyu arayın.
                </p>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                    placeholder="Oyuncu adı..."
                    className="flex-1 px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)]"
                  />
                  <Button
                    variant="primary"
                    size="sm"
                    isLoading={isProcessing}
                    onClick={handleSearch}
                  >
                    🔍 Ara
                  </Button>
                </div>
              </div>
            </Card>
          )}

          {/* ── Searching spinner ── */}
          {tradeStatus === "searching" && (
            <Card>
              <div className="p-8 text-center">
                <div className="text-2xl mb-2 animate-pulse">🔍</div>
                <p className="text-sm text-[var(--text-muted)]">Oyuncu aranıyor...</p>
              </div>
            </Card>
          )}

          {/* ── Pending: waiting for partner ── */}
          {tradeStatus === "pending" && (
            <Card variant="elevated">
              <div className="p-4 text-center space-y-3">
                <div className="text-3xl animate-pulse">⏳</div>
                <p className="text-sm text-[var(--text-primary)] font-medium">
                  {partnerName} bekleniyor...
                </p>
                <p className="text-xs text-[var(--text-muted)]">
                  Ticaret isteği gönderildi. Karşı taraf kabul edene kadar bekleyin.
                </p>
                <Button variant="danger" size="sm" onClick={handleCancel}>
                  İptal Et
                </Button>
              </div>
            </Card>
          )}

          {/* ── Active / Confirming: trade session ── */}
          <AnimatePresence>
            {(tradeStatus === "active" || tradeStatus === "confirming") && (
              <motion.div
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0 }}
                className="space-y-3"
              >
                {/* Session header */}
                <Card>
                  <div className="p-3 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-lg">🤝</span>
                      <div>
                        <p className="text-sm font-semibold text-[var(--text-primary)]">
                          {partnerName} ile Ticaret
                        </p>
                        {sessionId && (
                          <p className="text-[10px] text-[var(--text-muted)]">
                            Oturum: {sessionId.slice(0, 8)}...
                          </p>
                        )}
                      </div>
                    </div>
                    <Button variant="danger" size="sm" onClick={handleCancel} disabled={isProcessing}>
                      İptal
                    </Button>
                  </div>
                </Card>

                {/* Two-panel offer area */}
                <div className="grid grid-cols-2 gap-2">
                  {/* My Offer */}
                  <Card>
                    <div className="p-3">
                      <h3 className="text-xs font-semibold text-[var(--accent)] mb-2">
                        📤 Teklifim
                      </h3>
                      {myOffer.length === 0 ? (
                        <div className="min-h-[80px] border-2 border-dashed border-[var(--border-default)] rounded-lg flex items-center justify-center">
                          <p className="text-[10px] text-[var(--text-muted)] text-center px-1">
                            Eşya ekle
                          </p>
                        </div>
                      ) : (
                        <div className="space-y-1.5 min-h-[80px]">
                          {myOffer.map((offer) => (
                            <div
                              key={offer.row_id}
                              className="flex items-center justify-between bg-[var(--bg-input)] rounded p-1.5"
                            >
                              <p
                                className="text-[11px] font-medium truncate flex-1"
                                style={{ color: getRarityColor(offer.rarity ?? "common" as Rarity) }}
                              >
                                {offer.name}
                              </p>
                              <button
                                onClick={() => handleRemoveItem(offer.row_id)}
                                className="text-[var(--color-error)] text-[10px] ml-1 hover:opacity-80"
                              >
                                ✕
                              </button>
                            </div>
                          ))}
                        </div>
                      )}
                      {tradeStatus === "active" && (
                        <Button
                          variant="secondary"
                          size="sm"
                          fullWidth
                          className="mt-2"
                          onClick={() => setItemPickerOpen(true)}
                        >
                          + Eşya Ekle
                        </Button>
                      )}
                    </div>
                  </Card>

                  {/* Their Offer */}
                  <Card>
                    <div className="p-3">
                      <h3 className="text-xs font-semibold text-[var(--text-secondary)] mb-2">
                        📥 Karşı Teklif
                      </h3>
                      {theirOffer.length === 0 ? (
                        <div className="min-h-[80px] border-2 border-dashed border-[var(--border-default)] rounded-lg flex items-center justify-center">
                          <p className="text-[10px] text-[var(--text-muted)] text-center px-1">
                            Bekleniyor...
                          </p>
                        </div>
                      ) : (
                        <div className="space-y-1.5 min-h-[80px]">
                          {theirOffer.map((offer) => (
                            <div
                              key={offer.row_id}
                              className="bg-[var(--bg-input)] rounded p-1.5"
                            >
                              <p className="text-[11px] font-medium text-[var(--text-primary)]">
                                {offer.name}
                              </p>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </Card>
                </div>

                {/* Action buttons */}
                {tradeStatus === "active" && (
                  <div className="flex gap-2">
                    <Button variant="danger" fullWidth onClick={handleCancel} disabled={isProcessing}>
                      ❌ Vazgeç
                    </Button>
                    <Button
                      variant="primary"
                      fullWidth
                      isLoading={isProcessing}
                      onClick={handleConfirm}
                    >
                      ✅ Onayla
                    </Button>
                  </div>
                )}

                {tradeStatus === "confirming" && (
                  <Card variant="elevated">
                    <div className="p-4 text-center space-y-2">
                      <div className="text-2xl animate-pulse">⏳</div>
                      <p className="text-sm text-[var(--text-primary)] font-medium">
                        Onayınız alındı
                      </p>
                      <p className="text-xs text-[var(--text-muted)]">
                        Karşı tarafın onayı bekleniyor...
                      </p>
                      <Button variant="danger" size="sm" onClick={handleCancel} disabled={isProcessing}>
                        İptal Et
                      </Button>
                    </div>
                  </Card>
                )}
              </motion.div>
            )}
          </AnimatePresence>

          {/* ── Done state ── */}
          {tradeStatus === "done" && (
            <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}>
              <Card variant="elevated">
                <div className="p-6 text-center space-y-3">
                  <div className="text-4xl">🎉</div>
                  <p className="text-base font-bold text-[var(--color-success)]">
                    Ticaret Tamamlandı!
                  </p>
                  <p className="text-sm text-[var(--text-secondary)]">
                    {partnerName} ile ticaret başarıyla gerçekleşti.
                  </p>
                  <Button variant="primary" size="sm" fullWidth onClick={resetTrade}>
                    Yeni Ticaret
                  </Button>
                </div>
              </Card>
            </motion.div>
          )}
        </div>
      )}

      {/* ══════════════ HISTORY TAB ══════════════ */}
      {tab === "history" && (
        <div className="space-y-3">
          {history.length === 0 ? (
            <Card>
              <div className="p-8 text-center text-sm text-[var(--text-muted)]">
                Henüz ticaret geçmişi yok.
              </div>
            </Card>
          ) : (
            history.map((entry) => (
              <Card key={entry.id}>
                <div className="p-3">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="text-base">🤝</span>
                      <div>
                        <p className="text-sm font-semibold text-[var(--text-primary)]">
                          {entry.partner}
                        </p>
                        <p className="text-[10px] text-[var(--text-muted)]">{entry.date}</p>
                      </div>
                    </div>
                    <span
                      className={`text-[10px] font-semibold px-2 py-0.5 rounded-full ${
                        entry.status === "completed"
                          ? "bg-[var(--color-success)]/20 text-[var(--color-success)]"
                          : "bg-[var(--color-error)]/20 text-[var(--color-error)]"
                      }`}
                    >
                      {entry.status === "completed" ? "✓ Tamamlandı" : "✕ İptal"}
                    </span>
                  </div>
                  <div className="grid grid-cols-2 gap-2 text-[11px]">
                    <div>
                      <p className="text-[var(--text-muted)] mb-0.5">📤 Ben verdim:</p>
                      {entry.myItems.length > 0 ? (
                        entry.myItems.map((it, i) => (
                          <p key={i} className="text-[var(--text-primary)]">• {it}</p>
                        ))
                      ) : (
                        <p className="text-[var(--text-muted)]">—</p>
                      )}
                    </div>
                    <div>
                      <p className="text-[var(--text-muted)] mb-0.5">📥 Ben aldım:</p>
                      {entry.theirItems.length > 0 ? (
                        entry.theirItems.map((it, i) => (
                          <p key={i} className="text-[var(--text-primary)]">• {it}</p>
                        ))
                      ) : (
                        <p className="text-[var(--text-muted)]">—</p>
                      )}
                    </div>
                  </div>
                </div>
              </Card>
            ))
          )}
        </div>
      )}

      {/* ── Item Picker Modal ── */}
      <Modal
        isOpen={itemPickerOpen}
        onClose={() => setItemPickerOpen(false)}
        title="🎒 Eşya Seç"
        size="md"
      >
        <div className="space-y-2 max-h-80 overflow-y-auto">
          {tradeableItems.length === 0 ? (
            <div className="p-6 text-center text-sm text-[var(--text-muted)]">
              Takas edilebilir eşya yok.
            </div>
          ) : (
            tradeableItems.map((item) => {
              const alreadyAdded = myOffer.some((o) => o.row_id === item.row_id);
              return (
                <button
                  key={item.row_id}
                  disabled={alreadyAdded}
                  onClick={() => handleAddItem(item)}
                  className={`w-full flex items-center justify-between p-3 rounded-lg border transition-colors text-left ${
                    alreadyAdded
                      ? "border-[var(--border-default)] opacity-50 cursor-not-allowed bg-[var(--bg-input)]"
                      : "border-[var(--border-default)] hover:border-[var(--accent)] hover:bg-[var(--accent)]/5 bg-[var(--bg-input)]"
                  }`}
                >
                  <div>
                    <p
                      className="text-sm font-semibold"
                      style={{ color: getRarityColor(item.rarity) }}
                    >
                      {item.name}
                    </p>
                    <p className="text-[10px] text-[var(--text-muted)]">
                      Adet: {item.quantity}
                      {alreadyAdded && " • Teklifte"}
                    </p>
                  </div>
                  {!alreadyAdded && (
                    <span className="text-xs text-[var(--accent)] font-medium">+ Ekle</span>
                  )}
                </button>
              );
            })
          )}
        </div>
        <div className="mt-3">
          <Button variant="secondary" size="sm" fullWidth onClick={() => setItemPickerOpen(false)}>
            Kapat
          </Button>
        </div>
      </Modal>
    </motion.div>
  );
}
