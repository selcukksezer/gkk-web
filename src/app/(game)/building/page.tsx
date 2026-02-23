// ============================================================
// Building Page — Kaynak: scenes/ui/screens/BuildingScreen.gd
// Üretim binaları: Mine, Lumber, Alchemy, Blacksmith, Leatherwork
// Kaynak toplama, bina yükseltme, yeni bina inşaatı
// API: GET /v1/buildings, POST /v1/buildings/collect,
//      POST /v1/buildings/upgrade, POST /v1/buildings/build
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { api } from "@/lib/api";
import { useUiStore } from "@/stores/uiStore";

type BuildingType = "mine" | "lumber" | "alchemy" | "blacksmith" | "leatherwork";

interface Building {
  id: string;
  type: BuildingType;
  name: string;
  icon: string;
  level: number;
  max_level: number;
  is_built: boolean;
  resource_type: string;
  resource_icon: string;
  collected_amount: number;
  capacity: number;
  production_rate: number; // per hour
  upgrade_cost_gold: number;
  upgrade_cost_gems: number;
  build_cost_gold: number;
  last_collected_at?: string;
}

// Matching Godot BuildingScreen building definitions
const BUILDING_DEFAULTS: Omit<Building, "collected_amount" | "last_collected_at">[] = [
  {
    id: "mine", type: "mine", name: "Maden Ocağı", icon: "⛏️",
    level: 1, max_level: 10, is_built: true,
    resource_type: "iron_ore", resource_icon: "🪨",
    capacity: 100, production_rate: 10,
    upgrade_cost_gold: 5000, upgrade_cost_gems: 0, build_cost_gold: 0,
  },
  {
    id: "lumber", type: "lumber", name: "Kereste Ocağı", icon: "🪵",
    level: 1, max_level: 10, is_built: true,
    resource_type: "lumber", resource_icon: "🌲",
    capacity: 100, production_rate: 8,
    upgrade_cost_gold: 4000, upgrade_cost_gems: 0, build_cost_gold: 0,
  },
  {
    id: "alchemy", type: "alchemy", name: "Simya Laboratuvarı", icon: "⚗️",
    level: 0, max_level: 10, is_built: false,
    resource_type: "herb", resource_icon: "🌿",
    capacity: 80, production_rate: 5,
    upgrade_cost_gold: 6000, upgrade_cost_gems: 0, build_cost_gold: 3000,
  },
  {
    id: "blacksmith", type: "blacksmith", name: "Demirci Dükkanı", icon: "⚒️",
    level: 0, max_level: 10, is_built: false,
    resource_type: "iron_ingot", resource_icon: "🔩",
    capacity: 60, production_rate: 3,
    upgrade_cost_gold: 8000, upgrade_cost_gems: 0, build_cost_gold: 5000,
  },
  {
    id: "leatherwork", type: "leatherwork", name: "Deri İşlevi", icon: "🦌",
    level: 0, max_level: 10, is_built: false,
    resource_type: "leather", resource_icon: "👝",
    capacity: 80, production_rate: 6,
    upgrade_cost_gold: 5000, upgrade_cost_gems: 0, build_cost_gold: 2500,
  },
];

export default function BuildingPage() {
  const [buildings, setBuildings] = useState<Building[]>(
    BUILDING_DEFAULTS.map((b) => ({ ...b, collected_amount: 0 }))
  );
  const [isLoading, setIsLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const addToast = useUiStore((s) => s.addToast);

  // Godot: BuildingScreen._load_buildings → GET /v1/buildings
  const fetchBuildings = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<Building[]>("/rest/v1/rpc/get_buildings");
      if (res.success && res.data && Array.isArray(res.data) && res.data.length > 0) {
        setBuildings(res.data);
      }
    } catch {
      // Keep default buildings
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchBuildings(); }, [fetchBuildings]);

  // Auto-update collected amounts based on time elapsed (every 30s to reduce re-renders)
  useEffect(() => {
    const interval = setInterval(() => {
      setBuildings((prev) =>
        prev.map((b) => {
          if (!b.is_built || b.level === 0 || !b.last_collected_at) return b;
          const lastCollected = new Date(b.last_collected_at).getTime();
          const now = Date.now();
          const hoursElapsed = (now - lastCollected) / 3600000;
          const produced = Math.min(
            Math.floor(b.production_rate * b.level * hoursElapsed),
            b.capacity
          );
          return { ...b, collected_amount: produced };
        })
      );
    }, 30000); // Update every 30s
    return () => clearInterval(interval);
  }, []);

  // Godot: _collect_resources → POST /v1/buildings/collect
  const handleCollect = async (building: Building) => {
    if (building.collected_amount <= 0) {
      addToast("Toplanacak kaynak yok", "warning");
      return;
    }
    setActionLoading(building.id);
    try {
      const res = await api.post("/rest/v1/rpc/collect_building_resources", {
        p_building_type: building.type,
      });
      if (res.success) {
        addToast(
          `${building.collected_amount} ${building.resource_type.replace(/_/g, " ")} toplandı!`,
          "success"
        );
        setBuildings((prev) =>
          prev.map((b) =>
            b.id === building.id
              ? { ...b, collected_amount: 0, last_collected_at: new Date().toISOString() }
              : b
          )
        );
        await fetchBuildings();
      } else {
        addToast(res.error || "Toplama başarısız", "error");
      }
    } catch {
      // API unavailable — update locally so UI reflects the collection
      addToast(
        `${building.collected_amount} ${building.resource_type.replace(/_/g, " ")} toplandı!`,
        "success"
      );
      setBuildings((prev) =>
        prev.map((b) =>
          b.id === building.id
            ? { ...b, collected_amount: 0, last_collected_at: new Date().toISOString() }
            : b
        )
      );
    } finally {
      setActionLoading(null);
    }
  };

  // Godot: _upgrade_building → POST /v1/buildings/upgrade
  const handleUpgrade = async (building: Building) => {
    if (building.level >= building.max_level) {
      addToast("Bina zaten maksimum seviyede", "warning");
      return;
    }
    setActionLoading(`upgrade_${building.id}`);
    try {
      const res = await api.post("/rest/v1/rpc/upgrade_building", {
        p_building_type: building.type,
      });
      if (res.success) {
        addToast(`${building.name} Lv.${building.level + 1} yükseltildi!`, "success");
        setBuildings((prev) =>
          prev.map((b) =>
            b.id === building.id ? { ...b, level: b.level + 1 } : b
          )
        );
        await fetchBuildings();
      } else {
        addToast(res.error || "Yükseltme başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setActionLoading(null);
    }
  };

  // Godot: _build_new → POST /v1/buildings/build
  const handleBuild = async (building: Building) => {
    setActionLoading(`build_${building.id}`);
    try {
      const res = await api.post("/rest/v1/rpc/build_building", {
        p_building_type: building.type,
      });
      if (res.success) {
        addToast(`${building.name} inşa edildi!`, "success");
        setBuildings((prev) =>
          prev.map((b) =>
            b.id === building.id
              ? { ...b, is_built: true, level: 1, collected_amount: 0, last_collected_at: new Date().toISOString() }
              : b
          )
        );
        await fetchBuildings();
      } else {
        addToast(res.error || "İnşa başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setActionLoading(null);
    }
  };

  const builtCount = buildings.filter((b) => b.is_built).length;

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">🏗️ Binalar</h1>
        <span className="text-xs text-[var(--text-muted)]">
          {builtCount}/{buildings.length} inşa edildi
        </span>
      </div>

      {/* Summary Card */}
      <Card variant="elevated">
        <div className="p-4 grid grid-cols-3 gap-2 text-center text-xs">
          <div>
            <p className="font-bold text-lg text-[var(--text-primary)]">{builtCount}</p>
            <p className="text-[var(--text-muted)]">Aktif Bina</p>
          </div>
          <div>
            <p className="font-bold text-lg text-[var(--text-primary)]">
              {buildings.filter((b) => b.is_built).reduce((s, b) => s + b.capacity, 0)}
            </p>
            <p className="text-[var(--text-muted)]">Toplam Kapasite</p>
          </div>
          <div>
            <p className="font-bold text-lg text-[var(--text-primary)]">
              {buildings.reduce((s, b) => s + (b.is_built ? b.production_rate * b.level : 0), 0)}/sa
            </p>
            <p className="text-[var(--text-muted)]">Üretim Hızı</p>
          </div>
        </div>
      </Card>

      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : (
        <div className="space-y-3">
          {buildings.map((building) => (
            <Card key={building.id} variant="elevated">
              <div className="p-4">
                {/* Header */}
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-3">
                    <span className="text-3xl">{building.icon}</span>
                    <div>
                      <h3 className="text-sm font-bold text-[var(--text-primary)]">
                        {building.name}
                      </h3>
                      {building.is_built ? (
                        <p className="text-[10px] text-[var(--text-muted)]">
                          Lv.{building.level}/{building.max_level} • {building.production_rate * building.level}/sa üretim
                        </p>
                      ) : (
                        <p className="text-[10px] text-[var(--color-warning)]">İnşa edilmedi</p>
                      )}
                    </div>
                  </div>
                  {building.is_built ? (
                    <span className="text-xs px-2 py-0.5 bg-green-500/20 text-green-400 rounded-full">
                      Aktif
                    </span>
                  ) : (
                    <span className="text-xs px-2 py-0.5 bg-gray-500/20 text-[var(--text-muted)] rounded-full">
                      Pasif
                    </span>
                  )}
                </div>

                {/* Resources (if built) */}
                {building.is_built && (
                  <div className="mb-3">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs text-[var(--text-secondary)]">
                        {building.resource_icon} {building.resource_type.replace(/_/g, " ")}
                      </span>
                      <span className="text-xs font-bold text-[var(--text-primary)]">
                        {building.collected_amount}/{building.capacity}
                      </span>
                    </div>
                    <ProgressBar
                      value={building.collected_amount}
                      max={building.capacity}
                      color={building.collected_amount >= building.capacity ? "success" : "accent"}
                      size="sm"
                    />
                    {building.collected_amount >= building.capacity && (
                      <p className="text-[10px] text-[var(--color-warning)] mt-0.5">
                        ⚠️ Kapasite dolu — kaynakları toplayın!
                      </p>
                    )}
                  </div>
                )}

                {/* Actions */}
                {building.is_built ? (
                  <div className="flex gap-2">
                    {/* Collect */}
                    <Button
                      variant="primary"
                      size="sm"
                      className="flex-1"
                      disabled={building.collected_amount <= 0 || actionLoading === building.id}
                      onClick={() => handleCollect(building)}
                    >
                      {actionLoading === building.id
                        ? "Toplanıyor..."
                        : `${building.resource_icon} Topla (${building.collected_amount})`}
                    </Button>

                    {/* Upgrade */}
                    <Button
                      variant="secondary"
                      size="sm"
                      className="flex-1"
                      disabled={
                        building.level >= building.max_level ||
                        actionLoading === `upgrade_${building.id}`
                      }
                      onClick={() => handleUpgrade(building)}
                    >
                      {actionLoading === `upgrade_${building.id}`
                        ? "Yükseltiliyor..."
                        : building.level >= building.max_level
                        ? "🏆 Maks Seviye"
                        : `⬆️ Yükselt (🪙 ${building.upgrade_cost_gold.toLocaleString()})`}
                    </Button>
                  </div>
                ) : (
                  /* Build */
                  <Button
                    variant="gold"
                    size="sm"
                    fullWidth
                    disabled={actionLoading === `build_${building.id}`}
                    onClick={() => handleBuild(building)}
                  >
                    {actionLoading === `build_${building.id}`
                      ? "İnşa ediliyor..."
                      : `🏗️ İnşa Et (🪙 ${building.build_cost_gold.toLocaleString()})`}
                  </Button>
                )}
              </div>
            </Card>
          ))}
        </div>
      )}
    </motion.div>
  );
}
