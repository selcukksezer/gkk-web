// ============================================================
// Warehouse Page — Kaynak: scenes/ui/screens/WarehouseScreen.gd (193 satır)
// Malzeme deposu: Maden, Kereste, Simya, Demirci, Deri tabs
// API: GET /v1/warehouses, POST /v1/warehouses/upgrade
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { api } from "@/lib/api";
import { useUiStore } from "@/stores/uiStore";

type WarehouseTab = "all" | "mine" | "lumber" | "alchemy" | "blacksmith" | "leather";

const TABS: { key: WarehouseTab; label: string; icon: string }[] = [
  { key: "all", label: "Tümü", icon: "📦" },
  { key: "mine", label: "Maden", icon: "⛏️" },
  { key: "lumber", label: "Kereste", icon: "🪵" },
  { key: "alchemy", label: "Simya", icon: "⚗️" },
  { key: "blacksmith", label: "Demirci", icon: "⚒️" },
  { key: "leather", label: "Deri", icon: "🦌" },
];

interface WarehouseItem {
  id: string;
  name: string;
  quantity: number;
  capacity?: number;
  category: string;
  icon: string;
}

// Fallback warehouse items matching Godot WarehouseScreen
const FALLBACK_ITEMS: WarehouseItem[] = [
  { id: "w1", name: "Demir Cevheri", quantity: 0, capacity: 100, category: "mine", icon: "🪨" },
  { id: "w2", name: "Altın Cevheri", quantity: 0, capacity: 50, category: "mine", icon: "✨" },
  { id: "w3", name: "Bakır Cevheri", quantity: 0, capacity: 100, category: "mine", icon: "🟤" },
  { id: "w4", name: "Meşe Kerestesi", quantity: 0, capacity: 100, category: "lumber", icon: "🪵" },
  { id: "w5", name: "Çam Kerestesi", quantity: 0, capacity: 100, category: "lumber", icon: "🌲" },
  { id: "w6", name: "Şifalı Bitki", quantity: 0, capacity: 200, category: "alchemy", icon: "🌿" },
  { id: "w7", name: "Zehir Özü", quantity: 0, capacity: 50, category: "alchemy", icon: "☠️" },
  { id: "w8", name: "Demir Külçe", quantity: 0, capacity: 100, category: "blacksmith", icon: "🔩" },
  { id: "w9", name: "Çelik Levha", quantity: 0, capacity: 50, category: "blacksmith", icon: "🛡️" },
  { id: "w10", name: "Ham Deri", quantity: 0, capacity: 100, category: "leather", icon: "🦌" },
  { id: "w11", name: "İşlenmiş Deri", quantity: 0, capacity: 50, category: "leather", icon: "👝" },
];

export default function WarehousePage() {
  const [activeTab, setActiveTab] = useState<WarehouseTab>("all");
  const [items, setItems] = useState<WarehouseItem[]>(FALLBACK_ITEMS);
  const [isLoading, setIsLoading] = useState(true);
  const [isUpgrading, setIsUpgrading] = useState(false);
  const addToast = useUiStore((s) => s.addToast);

  // Fetch from API — Godot: GET /v1/warehouses
  const fetchWarehouse = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<WarehouseItem[]>("/rest/v1/rpc/get_warehouses");
      if (res.success && res.data && Array.isArray(res.data) && res.data.length > 0) {
        setItems(res.data);
      }
    } catch {
      // Keep fallback data
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchWarehouse(); }, [fetchWarehouse]);

  // Upgrade capacity — Godot: POST /v1/warehouses/upgrade
  const upgradeWarehouse = async (category: string) => {
    setIsUpgrading(true);
    try {
      const res = await api.post("/rest/v1/rpc/upgrade_warehouse", { p_category: category });
      if (res.success) {
        addToast("Depo kapasitesi yükseltildi!", "success");
        await fetchWarehouse();
      } else {
        addToast(res.error || "Yükseltme başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setIsUpgrading(false);
    }
  };

  const filtered = activeTab === "all" ? items : items.filter((i) => i.category === activeTab);

  // Calculate total capacity per category
  const categoryStats = TABS.filter((t) => t.key !== "all").map((t) => {
    const catItems = items.filter((i) => i.category === t.key);
    const totalQty = catItems.reduce((s, i) => s + i.quantity, 0);
    const totalCap = catItems.reduce((s, i) => s + (i.capacity || 100), 0);
    return { ...t, totalQty, totalCap };
  });

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">📦 Depo</h1>

      {/* Category Summary Cards */}
      <div className="grid grid-cols-5 gap-1.5">
        {categoryStats.map((cat) => (
          <div key={cat.key} className="bg-[var(--card-bg)] rounded-lg p-2 text-center">
            <span className="text-lg">{cat.icon}</span>
            <p className="text-[9px] text-[var(--text-muted)]">{cat.label}</p>
            <p className="text-[10px] font-bold text-[var(--text-primary)]">{cat.totalQty}/{cat.totalCap}</p>
          </div>
        ))}
      </div>

      {/* Tabs - scrollable */}
      <div className="flex gap-1.5 overflow-x-auto pb-1">
        {TABS.map((tab) => (
          <button key={tab.key}
            className={`flex-shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              activeTab === tab.key ? "bg-[var(--primary)] text-white" : "bg-[var(--card-bg)] text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveTab(tab.key)}>
            {tab.icon} {tab.label}
          </button>
        ))}
      </div>

      {/* Upgrade Button for selected category */}
      {activeTab !== "all" && (
        <Button variant="secondary" size="sm" fullWidth onClick={() => upgradeWarehouse(activeTab)}
          disabled={isUpgrading}>
          {isUpgrading ? "Yükseltiliyor..." : `⬆️ ${TABS.find((t) => t.key === activeTab)?.label} Deposunu Yükselt`}
        </Button>
      )}

      {/* Materials Grid */}
      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : (
        <div className="space-y-2">
          {filtered.map((item) => (
            <Card key={item.id}>
              <div className="p-3">
                <div className="flex items-center justify-between mb-1">
                  <div className="flex items-center gap-3">
                    <span className="text-2xl">{item.icon}</span>
                    <div>
                      <p className="text-sm font-medium text-[var(--text-primary)]">{item.name}</p>
                      <p className="text-[10px] text-[var(--text-muted)]">
                        {TABS.find((t) => t.key === item.category)?.icon} {TABS.find((t) => t.key === item.category)?.label}
                      </p>
                    </div>
                  </div>
                  <span className="text-lg font-bold text-[var(--text-primary)]">{item.quantity}</span>
                </div>
                {item.capacity && (
                  <ProgressBar value={item.quantity} max={item.capacity} color="accent" size="sm"
                    label={`${item.quantity}/${item.capacity}`} />
                )}
              </div>
            </Card>
          ))}
        </div>
      )}
    </motion.div>
  );
}
