// ============================================================
// Map Page — Kaynak: scenes/ui/screens/MapScreen.gd
// 6 bölge, tehlike renkleri, seyahat onayı, enerji kontrolü,
// bölge aktiviteleri, mevcut konum vurgusu
// ============================================================

"use client";

import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";

// ── Region definition (Godot: MapScreen region data) ─────────
interface Region {
  id: string;
  name: string;
  description: string;
  icon: string;
  danger: number; // 0-100 numeric danger level
  travel_minutes: number;
  energy_cost: number;
  activities: string[];
  is_current?: boolean;
}

// Color from danger 0-100
function dangerColor(danger: number): string {
  if (danger === 0) return "var(--color-success)";
  if (danger < 30) return "#4ade80";
  if (danger < 50) return "var(--color-warning)";
  if (danger < 70) return "#f97316";
  if (danger < 85) return "var(--color-error)";
  return "#dc2626";
}

function dangerLabel(danger: number): string {
  if (danger === 0) return "Güvenli";
  if (danger < 30) return "Düşük Risk";
  if (danger < 50) return "Orta Risk";
  if (danger < 70) return "Tehlikeli";
  if (danger < 85) return "Çok Tehlikeli";
  return "Ölüm Tuzağı";
}

function dangerEmoji(danger: number): string {
  if (danger === 0) return "🟢";
  if (danger < 30) return "🟡";
  if (danger < 50) return "🟠";
  if (danger < 70) return "🔴";
  return "💀";
}

// Activity tag colors
const ACTIVITY_STYLES: Record<string, { bg: string; color: string }> = {
  zindan: { bg: "var(--rarity-epic)20", color: "var(--rarity-epic)" },
  görev: { bg: "var(--accent)20", color: "var(--accent-light)" },
  pazar: { bg: "var(--color-gold)20", color: "var(--color-gold)" },
  zanaat: { bg: "var(--color-warning)20", color: "var(--color-warning)" },
  ticaret: { bg: "#22c55e20", color: "#22c55e" },
  avlanma: { bg: "var(--color-error)20", color: "var(--color-error)" },
  keşif: { bg: "#06b6d420", color: "#06b6d4" },
  dinlenme: { bg: "var(--color-success)20", color: "var(--color-success)" },
};

// Godot: MapScreen regions (6 bölge, task spec'e göre)
const MAP_REGIONS: Region[] = [
  {
    id: "baslangic_koyu",
    name: "Başlangıç Köyü",
    description: "Huzurlu bir başlangıç köyü. Acemi maceracılar için ideal bir üs. Şifacı, demirci ve tüccarlar burada bulunur.",
    icon: "🏘️",
    danger: 0,
    travel_minutes: 0,
    energy_cost: 0,
    activities: ["görev", "ticaret", "zanaat", "dinlenme"],
    is_current: true,
  },
  {
    id: "orman_bolgesi",
    name: "Orman Bölgesi",
    description: "Geniş ve sık ormanlık alan. Yabani hayvanlar ve küçük canavarlar bu bölgede yaşar. Keşif görevleri için uygun.",
    icon: "🌲",
    danger: 20,
    travel_minutes: 5,
    energy_cost: 5,
    activities: ["avlanma", "keşif", "görev"],
    is_current: false,
  },
  {
    id: "dag_gecidi",
    name: "Dağ Geçidi",
    description: "Sarp kayalıklar ve dar geçitlerle dolu tehlikeli dağ yolu. Değerli madenler ve güçlü düşmanlar burada.",
    icon: "⛰️",
    danger: 45,
    travel_minutes: 10,
    energy_cost: 10,
    activities: ["zanaat", "avlanma", "keşif"],
    is_current: false,
  },
  {
    id: "karanlik_orman",
    name: "Karanlık Orman",
    description: "Lanetli karanlık orman. Güneş ışığı neredeyse hiç girmez. Elite canavarlar ve nadir loot buraya özgü.",
    icon: "🌑",
    danger: 65,
    travel_minutes: 15,
    energy_cost: 15,
    activities: ["zindan", "avlanma", "görev"],
    is_current: false,
  },
  {
    id: "lanetli_topraklar",
    name: "Lanetli Topraklar",
    description: "Antik bir savaşın izlerini taşıyan lanetli bölge. Ölümsüzler ve büyücüler bu topraklarda hüküm sürer.",
    icon: "💀",
    danger: 80,
    travel_minutes: 20,
    energy_cost: 20,
    activities: ["zindan", "görev"],
    is_current: false,
  },
  {
    id: "ejderha_yurdu",
    name: "Ejderha Yurdu",
    description: "Kadim ejderhaların yurdu. Bu bölgeye ancak en güçlü kahramanlar girebilir. Efsanevi ödüller burada gizli.",
    icon: "🐉",
    danger: 95,
    travel_minutes: 30,
    energy_cost: 30,
    activities: ["zindan"],
    is_current: false,
  },
];

export default function MapPage() {
  const [regions, setRegions] = useState<Region[]>(MAP_REGIONS);
  const [travelTarget, setTravelTarget] = useState<Region | null>(null);
  const [isTraveling, setIsTraveling] = useState(false);
  const [justArrived, setJustArrived] = useState<string | null>(null);

  const energy = usePlayerStore((s) => s.energy);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const addToast = useUiStore((s) => s.addToast);

  const currentRegion = regions.find((r) => r.is_current);

  // Try loading from API
  useEffect(() => {
    (async () => {
      try {
        const res = await api.get<Region[]>("/api/v1/map/regions");
        if (res.success && res.data && res.data.length > 0) {
          setRegions(res.data);
        }
      } catch { /* keep local data */ }
    })();
  }, []);

  const openTravelConfirm = useCallback(
    (region: Region) => {
      if (energy < region.energy_cost) {
        addToast(`Yetersiz enerji! ${region.name} için ⚡${region.energy_cost} gerekli.`, "error");
        return;
      }
      setTravelTarget(region);
    },
    [energy, addToast]
  );

  const handleTravel = useCallback(async () => {
    if (!travelTarget) return;
    if (energy < travelTarget.energy_cost) {
      addToast("Yetersiz enerji!", "error");
      setTravelTarget(null);
      return;
    }

    setIsTraveling(true);
    try {
      // Godot: MapScreen.travel_to_region -> api.rpc("travel_to_region", {region_id})
      await api.rpc("travel_to_region", { region_id: travelTarget.id });
      consumeEnergy(travelTarget.energy_cost);
    } catch {
      // Fallback: client-side travel if server not available
      consumeEnergy(travelTarget.energy_cost);
    }

    // Simulate travel animation
    await new Promise((r) => setTimeout(r, 1200));

    setRegions((prev) =>
      prev.map((r) => ({ ...r, is_current: r.id === travelTarget.id }))
    );
    setJustArrived(travelTarget.id);
    addToast(`✅ Seyahat Tamamlandı! ${travelTarget.name} bölgesine ulaştın.`, "success");

    setTimeout(() => setJustArrived(null), 3000);
    setIsTraveling(false);
    setTravelTarget(null);
  }, [travelTarget, energy, consumeEnergy, addToast]);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">🗺️ Dünya Haritası</h1>
        <span className="text-xs text-[var(--text-muted)]">⚡ {energy}</span>
      </div>

      {/* Current location banner */}
      <Card variant="elevated">
        <div className="p-4">
          <div className="flex items-center gap-3">
            <div className="relative">
              <span className="text-3xl">{currentRegion?.icon ?? "📍"}</span>
              <motion.span
                className="absolute -bottom-1 -right-1 text-xs"
                animate={{ scale: [1, 1.3, 1] }}
                transition={{ repeat: Infinity, duration: 2 }}
              >
                📍
              </motion.span>
            </div>
            <div className="flex-1">
              <p className="text-xs text-[var(--text-muted)]">Mevcut Konum</p>
              <h2 className="text-base font-bold text-[var(--text-primary)]">
                {currentRegion?.name ?? "Bilinmiyor"}
              </h2>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="text-xs" style={{ color: dangerColor(currentRegion?.danger ?? 0) }}>
                  {dangerEmoji(currentRegion?.danger ?? 0)} {dangerLabel(currentRegion?.danger ?? 0)}
                </span>
              </div>
            </div>
          </div>
          {currentRegion && currentRegion.activities.length > 0 && (
            <div className="flex flex-wrap gap-1 mt-3">
              {currentRegion.activities.map((act) => {
                const style = ACTIVITY_STYLES[act] ?? { bg: "var(--bg-input)", color: "var(--text-secondary)" };
                return (
                  <span
                    key={act}
                    className="text-[10px] font-medium px-2 py-0.5 rounded-full"
                    style={{ backgroundColor: style.bg, color: style.color }}
                  >
                    {act}
                  </span>
                );
              })}
            </div>
          )}
        </div>
      </Card>

      {/* Travel loading overlay message */}
      {isTraveling && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="text-center py-4"
        >
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ repeat: Infinity, duration: 1.5, ease: "linear" }}
            className="text-3xl inline-block mb-2"
          >
            🧭
          </motion.div>
          <p className="text-sm text-[var(--text-secondary)]">Seyahat ediliyor...</p>
        </motion.div>
      )}

      {/* Region list */}
      <div className="space-y-3">
        {regions.map((region) => {
          const isCurrent = region.is_current;
          const hasEnergy = energy >= region.energy_cost;
          const isArrived = justArrived === region.id;

          return (
            <motion.div
              key={region.id}
              layout
              animate={isArrived ? { scale: [1, 1.02, 1] } : {}}
              transition={{ duration: 0.4 }}
            >
              <Card
                variant={isCurrent ? "elevated" : "default"}
                className={isCurrent ? "border border-[var(--accent)]/40" : ""}
              >
                <div className="p-4">
                  {/* Region header */}
                  <div className="flex items-start gap-3 mb-3">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center text-xl flex-shrink-0"
                      style={{
                        backgroundColor: `${dangerColor(region.danger)}15`,
                      }}
                    >
                      {region.icon}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <h3 className="text-sm font-bold text-[var(--text-primary)]">
                          {region.name}
                        </h3>
                        {isCurrent && (
                          <motion.span
                            className="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-[var(--accent)]/20 text-[var(--accent-light)]"
                            animate={{ opacity: [1, 0.6, 1] }}
                            transition={{ repeat: Infinity, duration: 2 }}
                          >
                            📍 Burada
                          </motion.span>
                        )}
                      </div>
                      <p className="text-xs text-[var(--text-muted)] mt-0.5 line-clamp-2">
                        {region.description}
                      </p>
                    </div>
                  </div>

                  {/* Danger bar */}
                  <div className="mb-3">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-[10px] text-[var(--text-muted)]">Tehlike Seviyesi</span>
                      <span
                        className="text-[10px] font-semibold"
                        style={{ color: dangerColor(region.danger) }}
                      >
                        {dangerEmoji(region.danger)} {dangerLabel(region.danger)} ({region.danger}%)
                      </span>
                    </div>
                    <div className="w-full h-1.5 bg-[var(--bg-card)] rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all"
                        style={{
                          width: `${region.danger}%`,
                          backgroundColor: dangerColor(region.danger),
                        }}
                      />
                    </div>
                  </div>

                  {/* Travel info */}
                  {!isCurrent && (
                    <div className="flex items-center gap-4 text-xs text-[var(--text-secondary)] mb-3">
                      <span>⏱ {region.travel_minutes} dk</span>
                      <span
                        style={{ color: hasEnergy ? "var(--color-warning)" : "var(--color-error)" }}
                      >
                        ⚡ {region.energy_cost} enerji
                      </span>
                    </div>
                  )}

                  {/* Activities */}
                  {region.activities.length > 0 && (
                    <div className="flex flex-wrap gap-1 mb-3">
                      {region.activities.map((act) => {
                        const style = ACTIVITY_STYLES[act] ?? { bg: "var(--bg-input)", color: "var(--text-secondary)" };
                        return (
                          <span
                            key={act}
                            className="text-[10px] font-medium px-2 py-0.5 rounded-full"
                            style={{ backgroundColor: style.bg, color: style.color }}
                          >
                            {act}
                          </span>
                        );
                      })}
                    </div>
                  )}

                  {/* Action button */}
                  {isCurrent ? (
                    <Button variant="secondary" size="sm" fullWidth disabled>
                      📍 Mevcut Konumunuz
                    </Button>
                  ) : (
                    <Button
                      variant={hasEnergy ? "primary" : "secondary"}
                      size="sm"
                      fullWidth
                      disabled={!hasEnergy || isTraveling}
                      onClick={() => openTravelConfirm(region)}
                    >
                      {!hasEnergy
                        ? `⚡ ${region.energy_cost} Enerji Gerekli`
                        : isTraveling
                        ? "Seyahat Ediliyor..."
                        : `🚶 ${region.name}'a Seyahat Et`}
                    </Button>
                  )}
                </div>
              </Card>
            </motion.div>
          );
        })}
      </div>

      {/* Travel Confirmation Modal */}
      <Modal
        isOpen={!!travelTarget}
        onClose={() => setTravelTarget(null)}
        title="🗺️ Seyahat Onayı"
        size="sm"
      >
        {travelTarget && (
          <div className="space-y-4">
            {/* Destination info */}
            <div className="flex items-center gap-3 bg-[var(--bg-input)] rounded-xl p-3">
              <span className="text-3xl">{travelTarget.icon}</span>
              <div>
                <h3 className="text-sm font-bold text-[var(--text-primary)]">{travelTarget.name}</h3>
                <span
                  className="text-xs"
                  style={{ color: dangerColor(travelTarget.danger) }}
                >
                  {dangerEmoji(travelTarget.danger)} {dangerLabel(travelTarget.danger)}
                </span>
              </div>
            </div>

            {/* Travel cost summary */}
            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-[var(--text-muted)]">⚡ Enerji Maliyeti</span>
                <span
                  className="font-semibold"
                  style={{ color: energy >= travelTarget.energy_cost ? "var(--color-warning)" : "var(--color-error)" }}
                >
                  {travelTarget.energy_cost} / {energy} mevcut
                </span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-[var(--text-muted)]">⏱ Seyahat Süresi</span>
                <span className="text-[var(--text-secondary)] font-semibold">
                  {travelTarget.travel_minutes} dakika
                </span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-[var(--text-muted)]">☠️ Tehlike</span>
                <span
                  className="font-semibold"
                  style={{ color: dangerColor(travelTarget.danger) }}
                >
                  %{travelTarget.danger}
                </span>
              </div>
            </div>

            {travelTarget.danger >= 65 && (
              <div className="bg-[var(--color-error)]/10 border border-[var(--color-error)]/30 rounded-xl p-3">
                <p className="text-xs text-[var(--color-error)]">
                  ⚠️ Uyarı: Bu bölge son derece tehlikeli. Yeterince güçlü olduğundan emin ol!
                </p>
              </div>
            )}

            <div className="flex gap-2">
              <Button
                variant="secondary"
                size="sm"
                fullWidth
                onClick={() => setTravelTarget(null)}
              >
                Vazgeç
              </Button>
              <Button
                variant="primary"
                size="sm"
                fullWidth
                isLoading={isTraveling}
                disabled={energy < travelTarget.energy_cost}
                onClick={handleTravel}
              >
                🚶 Seyahat Et
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </motion.div>
  );
}
