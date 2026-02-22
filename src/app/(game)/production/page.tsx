// ============================================================
// Production Page — Kaynak: scenes/ui/screens/ProductionScreen.gd (269 satır)
// Aktif üretimler (API), tarifler, geçmiş, hızlandır/iptal
// ============================================================

"use client";

import { useEffect, useState, useCallback } from "react";
import { motion } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";

type ProductionTab = "active" | "recipes" | "history";

interface ProductionChain {
  id: string;
  name: string;
  icon: string;
  building: string;
  time: number; // seconds — matches Godot
  materials: Record<string, number>;
  output: Record<string, number>;
}

interface ActiveProduction {
  id: number;
  item_name: string;
  icon: string;
  total_time: number;
  elapsed_time: number;
  status: string;
}

interface HistoryEntry {
  date: string;
  item_name: string;
  status: string;
}

// Exactly matching Godot PRODUCTION_CHAINS
const PRODUCTION_CHAINS: ProductionChain[] = [
  { id: "iron_ingot", name: "Demir Külçesi", icon: "🔩", building: "blacksmith", time: 300, materials: { iron_ore: 5 }, output: { iron_ingot: 1 } },
  { id: "leather_strip", name: "Deri Şerit", icon: "🎀", building: "leatherwork", time: 240, materials: { leather: 3 }, output: { leather_strip: 2 } },
  { id: "wooden_plank", name: "Tahta Kalası", icon: "🪵", building: "lumber", time: 180, materials: { lumber: 4 }, output: { wooden_plank: 3 } },
  { id: "health_potion", name: "Can İksiri", icon: "🧪", building: "alchemy", time: 600, materials: { herb: 5, water: 2 }, output: { health_potion: 1 } },
  { id: "iron_sword", name: "Demir Kılıç", icon: "⚔️", building: "blacksmith", time: 900, materials: { iron_ingot: 3, wooden_plank: 1 }, output: { iron_sword: 1 } },
];

function formatTime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  return `${m}:${String(s).padStart(2, "0")}`;
}

export default function ProductionPage() {
  const [activeTab, setActiveTab] = useState<ProductionTab>("recipes");
  const [activeProductions, setActiveProductions] = useState<ActiveProduction[]>([]);
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const addToast = useUiStore((s) => s.addToast);

  const loadActiveProductions = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<{ productions: ActiveProduction[] }>("/v1/production/active");
      setActiveProductions(res.data?.productions || []);
    } catch {
      // Fallback: no active productions
      setActiveProductions([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const loadHistory = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<{ history: HistoryEntry[] }>("/v1/production/history?limit=20");
      setHistory(res.data?.history || []);
    } catch {
      setHistory([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (activeTab === "active") loadActiveProductions();
    if (activeTab === "history") loadHistory();
  }, [activeTab, loadActiveProductions, loadHistory]);

  // Godot: _start_production
  const startProduction = async (chain: ProductionChain) => {
    try {
      await api.post("/v1/production/start", {
        recipe_id: chain.id,
        building_type: chain.building,
      });
      addToast(`${chain.name} üretimi başlatıldı!`, "success");
      setActiveTab("active");
      loadActiveProductions();
    } catch {
      addToast("Başlatma başarısız", "error");
    }
  };

  // Godot: _speedup_production (💎 50)
  const speedupProduction = async (prodId: number) => {
    try {
      await api.post("/v1/production/speedup", { production_id: prodId });
      addToast("Üretim hızlandırıldı!", "success");
      loadActiveProductions();
    } catch {
      addToast("Hızlandırma başarısız", "error");
    }
  };

  // Godot: _cancel_production
  const cancelProduction = async (prodId: number) => {
    try {
      await api.post("/v1/production/cancel", { production_id: prodId });
      addToast("Üretim iptal edildi", "success");
      loadActiveProductions();
    } catch {
      addToast("İptal başarısız", "error");
    }
  };

  const tabs: { key: ProductionTab; label: string }[] = [
    { key: "active", label: `Aktif (${activeProductions.length})` },
    { key: "recipes", label: "Tarifler" },
    { key: "history", label: "Geçmiş" },
  ];

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">⚙️ Üretim</h1>

      {/* Tabs */}
      <div className="flex gap-2">
        {tabs.map((t) => (
          <button key={t.key}
            className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
              activeTab === t.key ? "bg-[var(--accent)] text-white" : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveTab(t.key)}>
            {t.label}
          </button>
        ))}
      </div>

      {/* Active — Godot: _populate_active_list with progress, speedup, cancel */}
      {activeTab === "active" && (
        <div className="space-y-3">
          {isLoading ? (
            <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
          ) : activeProductions.length === 0 ? (
            <p className="text-center text-sm text-[var(--text-muted)] py-8">Aktif üretim yok</p>
          ) : (
            activeProductions.map((p) => {
              const progress = p.total_time > 0 ? Math.min(p.elapsed_time / p.total_time, 1) : 0;
              const remaining = Math.max(0, p.total_time - p.elapsed_time);
              return (
                <Card key={p.id}>
                  <div className="p-3">
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-medium text-sm text-[var(--text-primary)]">{p.icon || "⚙️"} {p.item_name}</span>
                      <span className="text-[10px] text-[var(--text-muted)]">{Math.round(progress * 100)}%</span>
                    </div>
                    <ProgressBar value={progress * 100} max={100} color="accent" size="sm" />
                    <p className="text-xs text-[var(--text-muted)] mt-1">Kalan Süre: {formatTime(remaining)}</p>
                    <div className="flex gap-2 mt-2">
                      <Button variant="secondary" size="sm" onClick={() => speedupProduction(p.id)}>
                        Hızlandır (💎 50)
                      </Button>
                      <Button variant="danger" size="sm" onClick={() => cancelProduction(p.id)}>
                        İptal
                      </Button>
                    </div>
                  </div>
                </Card>
              );
            })
          )}
        </div>
      )}

      {/* Recipes — Godot: _populate_recipes */}
      {activeTab === "recipes" && (
        <div className="space-y-3">
          {PRODUCTION_CHAINS.map((chain) => (
            <Card key={chain.id}>
              <div className="p-4">
                <div className="flex items-center justify-between mb-2">
                  <h3 className="font-bold text-sm text-[var(--text-primary)]">{chain.icon} {chain.name}</h3>
                  <span className="text-[10px] text-[var(--text-muted)]">⏱ {formatTime(chain.time)}</span>
                </div>
                <div className="flex items-center gap-2 text-xs text-[var(--text-secondary)] mb-2 flex-wrap">
                  <span>Malzemeler:</span>
                  {Object.entries(chain.materials).map(([mat, amt]) => (
                    <span key={mat} className="bg-[var(--bg-input)] px-1.5 py-0.5 rounded">{mat.replace(/_/g, " ")} x{amt}</span>
                  ))}
                </div>
                <div className="flex items-center gap-2 text-xs text-green-400 mb-3 flex-wrap">
                  <span>Çıktı:</span>
                  {Object.entries(chain.output).map(([out, amt]) => (
                    <span key={out} className="bg-green-500/10 px-1.5 py-0.5 rounded">{out.replace(/_/g, " ")} x{amt}</span>
                  ))}
                </div>
                <Button variant="primary" size="sm" fullWidth onClick={() => startProduction(chain)}>
                  BAŞLAT
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* History — Godot: _load_history + _populate_history */}
      {activeTab === "history" && (
        <div className="space-y-2">
          {isLoading ? (
            <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
          ) : history.length === 0 ? (
            <p className="text-center text-sm text-[var(--text-muted)] py-8">Geçmiş üretim kaydı bulunamadı</p>
          ) : (
            history.map((h, i) => (
              <Card key={i}>
                <div className="p-3 text-sm text-[var(--text-primary)]">
                  {h.date} - {h.item_name} ({h.status})
                </div>
              </Card>
            ))
          )}
        </div>
      )}
    </motion.div>
  );
}
