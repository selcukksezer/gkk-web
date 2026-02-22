// ============================================================
// Map Page — Kaynak: scenes/ui/screens/MapScreen.gd
// Bölge listesi, tehlike seviyesi, seyahat, enerji maliyeti
// ============================================================

"use client";

import { useEffect, useState, useCallback } from "react";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";

interface Region {
  id: string;
  name: string;
  description: string;
  danger_level: number; // 1-5
  travel_time_minutes: number;
  energy_cost: number;
  is_current: boolean;
}

const DANGER_LABELS = ["", "Güvenli", "Düşük Risk", "Orta Risk", "Tehlikeli", "Çok Tehlikeli"];
const DANGER_COLORS = ["", "#4ade80", "#facc15", "#f97316", "#ef4444", "#dc2626"];

// Fallback regions matching Godot MapScreen
const FALLBACK_REGIONS: Region[] = [
  { id: "r1", name: "Başlangıç Kasabası", description: "Güvenli bir kasaba. Acemi maceracılar için ideal.", danger_level: 1, travel_time_minutes: 0, energy_cost: 0, is_current: true },
  { id: "r2", name: "Karanlık Orman", description: "Tehlikeli yaratıklarla dolu eski bir orman.", danger_level: 3, travel_time_minutes: 5, energy_cost: 10, is_current: false },
  { id: "r3", name: "Kayıp Madenleri", description: "Eski cüce madenleri. Değerli mineraller bulunabilir.", danger_level: 3, travel_time_minutes: 8, energy_cost: 15, is_current: false },
  { id: "r4", name: "Lanetli Bataklık", description: "Büyülü sislerle kaplı tehlikeli bir bataklık.", danger_level: 4, travel_time_minutes: 12, energy_cost: 20, is_current: false },
  { id: "r5", name: "Ejderha Dağları", description: "Antik ejderhaların yaşadığı efsanevi dağlar.", danger_level: 5, travel_time_minutes: 20, energy_cost: 30, is_current: false },
  { id: "r6", name: "Liman Kenti", description: "Tüccarların buluşma noktası. Pazar ve zanaat fırsatları.", danger_level: 1, travel_time_minutes: 3, energy_cost: 5, is_current: false },
];

export default function MapPage() {
  const [regions, setRegions] = useState<Region[]>(FALLBACK_REGIONS);
  const [travelTarget, setTravelTarget] = useState<Region | null>(null);
  const [isTraveling, setIsTraveling] = useState(false);
  const energy = usePlayerStore((s) => s.energy);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const addToast = useUiStore((s) => s.addToast);

  useEffect(() => {
    (async () => {
      const res = await api.get<Region[]>("/api/v1/map/regions");
      if (res.success && res.data && res.data.length > 0) {
        setRegions(res.data);
      }
    })();
  }, []);

  const handleTravel = useCallback(async () => {
    if (!travelTarget) return;
    if (energy < travelTarget.energy_cost) {
      addToast("Yetersiz enerji!", "error");
      setTravelTarget(null);
      return;
    }
    setIsTraveling(true);
    try {
      // Try server-side travel first
      const res = await api.post("/rest/v1/rpc/travel_to_region", { p_region_id: travelTarget.id });
      if (res.success) {
        consumeEnergy(travelTarget.energy_cost);
      } else {
        // Fallback: client-side travel (no backend yet)
        consumeEnergy(travelTarget.energy_cost);
      }
    } catch {
      // Fallback: client-side travel
      consumeEnergy(travelTarget.energy_cost);
    }
    // Simulate travel animation (shortened for web)
    await new Promise((r) => setTimeout(r, 1500));
    setRegions((prev) =>
      prev.map((r) => ({ ...r, is_current: r.id === travelTarget.id }))
    );
    addToast(`${travelTarget.name} bölgesine ulaştınız!`, "success");
    setIsTraveling(false);
    setTravelTarget(null);
  }, [travelTarget, energy, consumeEnergy, addToast]);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-3 pb-24">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">🗺️ Dünya Haritası</h1>
        <span className="text-xs text-[var(--text-muted)]">
          Konum: {regions.find((r) => r.is_current)?.name ?? "Bilinmeyen"}
        </span>
      </div>

      <div className="space-y-3">
        {regions.map((region) => (
          <Card key={region.id}>
            <div className="p-4">
              <div className="flex items-center justify-between mb-1">
                <h3 className="font-bold text-[var(--text-primary)]">{region.name}</h3>
                <div className="flex gap-0.5">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <span key={i} className="text-xs" style={{ color: i < region.danger_level ? DANGER_COLORS[region.danger_level] : "#444" }}>
                      ⭐
                    </span>
                  ))}
                </div>
              </div>
              <p className="text-xs text-[var(--text-muted)] mb-2">{region.description}</p>
              <div className="flex items-center gap-3 text-[10px] text-[var(--text-secondary)] mb-3">
                <span style={{ color: DANGER_COLORS[region.danger_level] }}>
                  {DANGER_LABELS[region.danger_level]}
                </span>
                <span>⏱ {region.travel_time_minutes} dk</span>
                <span>⚡ {region.energy_cost}</span>
              </div>
              {region.is_current ? (
                <Button variant="secondary" size="sm" fullWidth disabled>
                  📍 Buradasınız
                </Button>
              ) : (
                <Button
                  variant="primary"
                  size="sm"
                  fullWidth
                  onClick={() => setTravelTarget(region)}
                  disabled={energy < region.energy_cost || isTraveling}
                >
                  🚶 SEYAHAT ET
                </Button>
              )}
            </div>
          </Card>
        ))}
      </div>

      <ConfirmDialog
        open={!!travelTarget}
        onCancel={() => setTravelTarget(null)}
        onConfirm={handleTravel}
        title="Seyahat Onayı"
        message={travelTarget ? `${travelTarget.name} bölgesine seyahat etmek istediğinize emin misiniz?\n\nEnerji maliyeti: ⚡${travelTarget.energy_cost}\nSüre: ${travelTarget.travel_time_minutes} dakika` : ""}
        confirmLabel="Seyahat Et"
        cancelLabel="Vazgeç"
      />
    </motion.div>
  );
}
