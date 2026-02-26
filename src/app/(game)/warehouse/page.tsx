// ============================================================
// Warehouse Page — Kaynak: scenes/ui/screens/WarehouseScreen.gd
// Bina depolarına göre sekmeli görünüm (Maden, Kereste, Simya,
// Demirci, Deri), kapasite barları, transfer modal, Genişlet
// API: get_warehouses RPC, upgrade_warehouse RPC, transfer_warehouse RPC
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { ItemIcon } from "@/components/game/ItemIcon";
import { api } from "@/lib/api";
import { useUiStore } from "@/stores/uiStore";

// ── Types ─────────────────────────────────────────────────────
type WarehouseTab = "all" | "mine" | "lumber" | "alchemy" | "blacksmith" | "leather";

const TABS: { key: WarehouseTab; label: string; icon: string }[] = [
  { key: "all",        label: "Tümü",    icon: "📦" },
  { key: "mine",       label: "Maden",   icon: "⛏️" },
  { key: "lumber",     label: "Kereste", icon: "🪵" },
  { key: "alchemy",    label: "Simya",   icon: "⚗️" },
  { key: "blacksmith", label: "Demirci", icon: "⚒️" },
  { key: "leather",    label: "Deri",    icon: "🦌" },
];

interface StoredItem {
  item_id: string;
  name: string;
  icon: string;
  quantity: number;
}

interface WarehouseBuilding {
  warehouse_id: string;
  building_type: WarehouseTab;
  building_name: string;
  building_level: number;
  building_icon: string;
  current_used: number;
  max_capacity: number;
  items: StoredItem[];
}

// ── Fallback data (mirrors WarehouseScreen.gd mock values) ────
const FALLBACK_WAREHOUSES: WarehouseBuilding[] = [
  {
    warehouse_id: "wh_mine_1",
    building_type: "mine",
    building_name: "Demir Madeni",
    building_level: 3,
    building_icon: "⛏️",
    current_used: 68,
    max_capacity: 200,
    items: [
      { item_id: "iron_ore",    name: "Demir Cevheri",  icon: "🪨", quantity: 45 },
      { item_id: "gold_ore",    name: "Altın Cevheri",  icon: "✨", quantity: 12 },
      { item_id: "copper_ore",  name: "Bakır Cevheri",  icon: "🟤", quantity: 8  },
      { item_id: "silver_ore",  name: "Gümüş Cevheri",  icon: "⚪", quantity: 3  },
    ],
  },
  {
    warehouse_id: "wh_lumber_1",
    building_type: "lumber",
    building_name: "Kereste Evi",
    building_level: 2,
    building_icon: "🪵",
    current_used: 130,
    max_capacity: 150,
    items: [
      { item_id: "oak_log",     name: "Meşe Kerestesi", icon: "🪵", quantity: 80 },
      { item_id: "pine_log",    name: "Çam Kerestesi",  icon: "🌲", quantity: 35 },
      { item_id: "hardwood",    name: "Sert Odun",      icon: "🌳", quantity: 15 },
    ],
  },
  {
    warehouse_id: "wh_alchemy_1",
    building_type: "alchemy",
    building_name: "Simya Laboratuvarı",
    building_level: 2,
    building_icon: "⚗️",
    current_used: 40,
    max_capacity: 100,
    items: [
      { item_id: "herb",        name: "Şifalı Bitki",   icon: "🌿", quantity: 25 },
      { item_id: "poison_gland",name: "Zehir Özü",      icon: "☠️", quantity: 8  },
      { item_id: "mana_crystal",name: "Mana Kristali",  icon: "💎", quantity: 7  },
    ],
  },
  {
    warehouse_id: "wh_blacksmith_1",
    building_type: "blacksmith",
    building_name: "Demirci Dükkanı",
    building_level: 4,
    building_icon: "⚒️",
    current_used: 85,
    max_capacity: 120,
    items: [
      { item_id: "iron_ingot",  name: "Demir Külçe",    icon: "🔩", quantity: 50 },
      { item_id: "steel_plate", name: "Çelik Levha",    icon: "🛡️", quantity: 20 },
      { item_id: "mithril_bar", name: "Mitril Çubuğu",  icon: "🔮", quantity: 10 },
      { item_id: "coal",        name: "Kömür",           icon: "⬛", quantity: 5  },
    ],
  },
  {
    warehouse_id: "wh_leather_1",
    building_type: "leather",
    building_name: "Dericiler Atölyesi",
    building_level: 1,
    building_icon: "🦌",
    current_used: 30,
    max_capacity: 80,
    items: [
      { item_id: "raw_hide",    name: "Ham Deri",        icon: "🦌", quantity: 20 },
      { item_id: "tanned_hide", name: "İşlenmiş Deri",   icon: "👝", quantity: 10 },
    ],
  },
];

// ── Capacity bar color (green <50%, yellow 50-80%, red >80%) ──
function capacityColor(used: number, max: number): "success" | "warning" | "health" {
  const pct = max > 0 ? used / max : 0;
  if (pct > 0.8) return "health";
  if (pct > 0.5) return "warning";
  return "success";
}

// ── Transfer modal state ──────────────────────────────────────
interface TransferState {
  fromWarehouse: WarehouseBuilding;
  item: StoredItem;
  amount: number;
  toWarehouseId: string;
}

export default function WarehousePage() {
  const [activeTab, setActiveTab] = useState<WarehouseTab>("all");
  const [warehouses, setWarehouses] = useState<WarehouseBuilding[]>(FALLBACK_WAREHOUSES);
  const [isLoading, setIsLoading] = useState(true);
  const [upgradingId, setUpgradingId] = useState<string | null>(null);
  const [transferState, setTransferState] = useState<TransferState | null>(null);
  const [isTransferring, setIsTransferring] = useState(false);
  const addToast = useUiStore((s) => s.addToast);

  // ── Fetch warehouses — Godot: GET /v1/warehouses ──────────
  const fetchWarehouses = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<WarehouseBuilding[]>("/rest/v1/rpc/get_warehouses");
      if (res.success && res.data && Array.isArray(res.data) && res.data.length > 0) {
        setWarehouses(res.data);
      }
    } catch { /* keep fallback */ }
    finally { setIsLoading(false); }
  }, []);

  useEffect(() => { fetchWarehouses(); }, [fetchWarehouses]);

  // ── Upgrade warehouse — api.rpc("upgrade_warehouse") ─────
  const handleUpgrade = async (warehouse: WarehouseBuilding) => {
    setUpgradingId(warehouse.warehouse_id);
    try {
      const res = await api.post("/rest/v1/rpc/upgrade_warehouse", {
        warehouse_id: warehouse.warehouse_id,
        building_type: warehouse.building_type,
      });
      if (res.success) {
        addToast(`${warehouse.building_name} deposu genişletildi!`, "success");
        await fetchWarehouses();
      } else {
        addToast(res.error || "Genişletme başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setUpgradingId(null);
    }
  };

  // ── Open transfer modal ───────────────────────────────────
  const openTransfer = (warehouse: WarehouseBuilding, item: StoredItem) => {
    const otherWarehouses = warehouses.filter((w) => w.warehouse_id !== warehouse.warehouse_id);
    setTransferState({
      fromWarehouse: warehouse,
      item,
      amount: 1,
      toWarehouseId: otherWarehouses[0]?.warehouse_id ?? "",
    });
  };

  // ── Execute transfer — api.rpc("transfer_warehouse") ─────
  const handleTransfer = async () => {
    if (!transferState) return;
    if (transferState.amount < 1) {
      addToast("En az 1 adet seçin", "warning");
      return;
    }
    if (!transferState.toWarehouseId) {
      addToast("Hedef depo seçin", "warning");
      return;
    }
    
    // NOTE: Warehouse is separate storage, not inventory. No capacity check needed here.
    // Transfer moves items between warehouses, not to/from inventory.
    
    setIsTransferring(true);
    try {
      const res = await api.post("/rest/v1/rpc/transfer_warehouse", {
        from: transferState.fromWarehouse.warehouse_id,
        to: transferState.toWarehouseId,
        item: transferState.item.item_id,
        amount: transferState.amount,
      });
      if (res.success) {
        addToast(`${transferState.amount}x ${transferState.item.name} transfer edildi!`, "success");
        setTransferState(null);
        await fetchWarehouses();
      } else {
        addToast(res.error || "Transfer başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setIsTransferring(false);
    }
  };

  // ── Filtered warehouses for current tab ───────────────────
  const visibleWarehouses =
    activeTab === "all"
      ? warehouses
      : warehouses.filter((w) => w.building_type === activeTab);

  // ── Summary stats for mini-cards ─────────────────────────
  const categoryStats = TABS.filter((t) => t.key !== "all").map((t) => {
    const whs = warehouses.filter((w) => w.building_type === t.key);
    const used = whs.reduce((s, w) => s + w.current_used, 0);
    const max  = whs.reduce((s, w) => s + w.max_capacity, 0);
    return { ...t, used, max };
  });

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">📦 Depo</h1>

      {/* ── Category summary mini-cards ── */}
      <div className="grid grid-cols-5 gap-1.5">
        {categoryStats.map((cat) => {
          const pct = cat.max > 0 ? cat.used / cat.max : 0;
          const clr = pct > 0.8 ? "var(--color-error)" : pct > 0.5 ? "var(--color-warning)" : "var(--color-success)";
          return (
            <button
              key={cat.key}
              onClick={() => setActiveTab(cat.key)}
              className={`rounded-lg p-2 text-center transition-all border ${
                activeTab === cat.key
                  ? "bg-[var(--accent)]/20 border-[var(--accent)]"
                  : "bg-[var(--bg-card)] border-transparent"
              }`}
            >
              <span className="text-lg">{cat.icon}</span>
              <p className="text-[9px] text-[var(--text-muted)] leading-tight">{cat.label}</p>
              <p className="text-[10px] font-bold" style={{ color: clr }}>
                {cat.used}/{cat.max}
              </p>
            </button>
          );
        })}
      </div>

      {/* ── Tabs scrollable ── */}
      <div className="flex gap-1.5 overflow-x-auto pb-1 -mx-1 px-1">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`flex-shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              activeTab === tab.key
                ? "bg-[var(--accent)] text-white"
                : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
            }`}
          >
            {tab.icon} {tab.label}
          </button>
        ))}
      </div>

      {/* ── Warehouse buildings ── */}
      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : visibleWarehouses.length === 0 ? (
        <Card>
          <div className="p-6 text-center text-sm text-[var(--text-muted)]">
            Bu türde depo bulunamadı.
          </div>
        </Card>
      ) : (
        <div className="space-y-4">
          {visibleWarehouses.map((wh) => {
            const pct = wh.max_capacity > 0 ? wh.current_used / wh.max_capacity : 0;
            const pctNum = Math.round(pct * 100);
            const barColor = capacityColor(wh.current_used, wh.max_capacity);
            const isUpgrading = upgradingId === wh.warehouse_id;

            return (
              <Card key={wh.warehouse_id} variant="elevated">
                <div className="p-4">
                  {/* Building header */}
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2">
                      <span className="text-2xl">{wh.building_icon}</span>
                      <div>
                        <h3 className="text-sm font-bold text-[var(--text-primary)]">
                          {wh.building_name}
                        </h3>
                        <p className="text-[10px] text-[var(--text-muted)]">
                          Seviye {wh.building_level} •{" "}
                          {TABS.find((t) => t.key === wh.building_type)?.icon}{" "}
                          {TABS.find((t) => t.key === wh.building_type)?.label}
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-xs font-semibold" style={{
                        color: pct > 0.8 ? "var(--color-error)" : pct > 0.5 ? "var(--color-warning)" : "var(--color-success)"
                      }}>
                        %{pctNum}
                      </p>
                      <p className="text-[10px] text-[var(--text-muted)]">
                        {wh.current_used}/{wh.max_capacity}
                      </p>
                    </div>
                  </div>

                  {/* Capacity bar */}
                  <div className="mb-3">
                    <ProgressBar value={pct} color={barColor} size="md" />
                    <div className="flex justify-between text-[10px] text-[var(--text-muted)] mt-0.5">
                      <span>Kullanılan: {wh.current_used}</span>
                      <span>Kapasite: {wh.max_capacity}</span>
                    </div>
                  </div>

                  {/* Items grid */}
                  {wh.items.length > 0 ? (
                    <div className="grid grid-cols-2 gap-2 mb-3">
                      {wh.items.map((item) => (
                        <div
                          key={item.item_id}
                          className="bg-[var(--bg-input)] rounded-lg p-2 flex items-center justify-between"
                        >
                          <div className="flex items-center gap-1.5">
                            <ItemIcon icon={item.icon} itemId={String(item.item_id)} className="text-lg" />
                            <div>
                              <p className="text-[11px] font-medium text-[var(--text-primary)] leading-tight">
                                {item.name}
                              </p>
                              <p className="text-[10px] text-[var(--text-muted)]">
                                x{item.quantity}
                              </p>
                            </div>
                          </div>
                          <button
                            onClick={() => openTransfer(wh, item)}
                            className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--accent)]/20 text-[var(--accent)] hover:bg-[var(--accent)]/30 transition-colors"
                          >
                            ↔️
                          </button>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="mb-3 py-3 text-center text-xs text-[var(--text-muted)] border border-dashed border-[var(--border-default)] rounded-lg">
                      Depoda malzeme yok
                    </div>
                  )}

                  {/* Action buttons */}
                  <div className="flex gap-2">
                    <Button
                      variant="secondary"
                      size="sm"
                      className="flex-1"
                      onClick={() => {
                        if (wh.items.length > 0) {
                          openTransfer(wh, wh.items[0]);
                        } else {
                          addToast("Transfer edilecek malzeme yok", "warning");
                        }
                      }}
                    >
                      ↔️ Transfer
                    </Button>
                    <Button
                      variant="primary"
                      size="sm"
                      className="flex-1"
                      isLoading={isUpgrading}
                      onClick={() => handleUpgrade(wh)}
                    >
                      ⬆️ Genişlet
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* ── Transfer Modal ── */}
      <Modal
        isOpen={transferState !== null}
        onClose={() => setTransferState(null)}
        title="↔️ Malzeme Transfer"
        size="sm"
      >
        {transferState && (
          <div className="space-y-4">
            {/* Item info */}
              <div className="flex items-center gap-3 p-3 bg-[var(--bg-input)] rounded-lg">
              <ItemIcon icon={transferState.item.icon} itemId={String(transferState.item.item_id)} className="text-2xl shrink-0" />
              <div>
                <p className="text-sm font-semibold text-[var(--text-primary)]">
                  {transferState.item.name}
                </p>
                <p className="text-xs text-[var(--text-muted)]">
                  Kaynak: {transferState.fromWarehouse.building_name} •{" "}
                  Mevcut: {transferState.item.quantity}
                </p>
              </div>
            </div>

            {/* Amount */}
            <div>
              <label className="block text-xs text-[var(--text-secondary)] mb-1">
                Transfer Miktarı
              </label>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setTransferState((s) => s && { ...s, amount: Math.max(1, s.amount - 1) })}
                  className="w-8 h-8 rounded-lg bg-[var(--bg-input)] text-[var(--text-primary)] font-bold"
                >
                  −
                </button>
                <input
                  type="number"
                  min={1}
                  max={transferState.item.quantity}
                  value={transferState.amount}
                  onChange={(e) =>
                    setTransferState((s) =>
                      s && {
                        ...s,
                        amount: Math.min(
                          transferState.item.quantity,
                          Math.max(1, parseInt(e.target.value) || 1)
                        ),
                      }
                    )
                  }
                  className="flex-1 px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)] text-center"
                />
                <button
                  onClick={() =>
                    setTransferState((s) =>
                      s && { ...s, amount: Math.min(transferState.item.quantity, s.amount + 1) }
                    )
                  }
                  className="w-8 h-8 rounded-lg bg-[var(--bg-input)] text-[var(--text-primary)] font-bold"
                >
                  +
                </button>
                <button
                  onClick={() =>
                    setTransferState((s) => s && { ...s, amount: transferState.item.quantity })
                  }
                  className="text-xs px-2 py-1 rounded bg-[var(--accent)]/20 text-[var(--accent)]"
                >
                  Tümü
                </button>
              </div>
            </div>

            {/* Destination */}
            <div>
              <label className="block text-xs text-[var(--text-secondary)] mb-1">
                Hedef Depo
              </label>
              <select
                value={transferState.toWarehouseId}
                onChange={(e) =>
                  setTransferState((s) => s && { ...s, toWarehouseId: e.target.value })
                }
                className="w-full px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)] focus:outline-none focus:border-[var(--accent)]"
              >
                {warehouses
                  .filter((w) => w.warehouse_id !== transferState.fromWarehouse.warehouse_id)
                  .map((w) => (
                    <option key={w.warehouse_id} value={w.warehouse_id}>
                      {w.building_icon} {w.building_name} ({w.current_used}/{w.max_capacity})
                    </option>
                  ))}
              </select>
            </div>

            {/* Capacity warning */}
            {(() => {
              const dest = warehouses.find((w) => w.warehouse_id === transferState.toWarehouseId);
              if (dest) {
                const remaining = dest.max_capacity - dest.current_used;
                if (transferState.amount > remaining) {
                  return (
                    <p className="text-xs text-[var(--color-error)]">
                      ⚠️ Hedef depoda yeterli yer yok! ({remaining} birim boş)
                    </p>
                  );
                }
              }
              return null;
            })()}

            {/* Actions */}
            <div className="flex gap-2">
              <Button
                variant="secondary"
                size="sm"
                fullWidth
                onClick={() => setTransferState(null)}
              >
                Vazgeç
              </Button>
              <Button
                variant="primary"
                size="sm"
                fullWidth
                isLoading={isTransferring}
                onClick={handleTransfer}
              >
                Transfer Et
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </motion.div>
  );
}
