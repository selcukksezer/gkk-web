// ============================================================
// Facilities Page — Kaynak: scenes/FacilitiesScreen.gd
// 15 tesis ızgara görünümü, tier bazlı gruplama
// ============================================================

"use client";

import { useEffect, useState, useMemo } from "react";
import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { useFacilityStore } from "@/stores/facilityStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { FACILITIES_CONFIG, getFacilitiesByTier, FACILITY_TYPES } from "@/data/FacilityConfig";
import { isInPrison } from "@/lib/utils/validation";
import { formatGold } from "@/lib/utils/string";
import type { FacilityType } from "@/types/facility";

const tierLabels: Record<number, string> = {
  1: "🏚️ Tier 1 — Başlangıç",
  2: "🏗️ Tier 2 — Gelişmiş",
  3: "🏰 Tier 3 — İleri",
};

const suspicionColor = (value: number): string => {
  if (value >= 80) return "var(--color-error)";
  if (value >= 50) return "var(--color-warning)";
  return "var(--color-success)";
};

export default function FacilitiesPage() {
  const router = useRouter();
  const facilities = useFacilityStore((s) => s.facilities);
  const fetchFacilities = useFacilityStore((s) => s.fetchFacilities);
  const unlockFacility = useFacilityStore((s) => s.unlockFacility);
  const bribeOfficials = useFacilityStore((s) => s.bribeOfficials);
  const isLoading = useFacilityStore((s) => s.isLoading);
  const level = usePlayerStore((s) => s.level);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const prisonUntil = usePlayerStore((s) => s.prisonUntil);
  const addToast = useUiStore((s) => s.addToast);

  const inPrison = isInPrison(prisonUntil);

  // Global suspicion (average)
  const globalSuspicion = useMemo(() => {
    if (facilities.length === 0) return 0;
    const total = facilities.reduce((sum, f) => sum + (f.suspicion || 0), 0);
    return Math.round(total / facilities.length);
  }, [facilities]);

  useEffect(() => {
    fetchFacilities();
  }, [fetchFacilities]);

  const handleUnlock = async (type: FacilityType) => {
    const config = FACILITIES_CONFIG[type];
    if (!config) return;
    if (gold < config.unlock_cost) {
      addToast("Yeterli altın yok", "warning");
      return;
    }
    if (level < config.unlock_level) {
      addToast(`Seviye ${config.unlock_level} gerekli`, "warning");
      return;
    }
    await unlockFacility(type);
    addToast(`${config.name} açıldı!`, "success");
  };

  const handleBribe = async () => {
    if (gems < 5) {
      addToast("Rüşvet için 5 gem gerekli", "warning");
      return;
    }
    // Bribe the facility with highest suspicion
    const highestSuspicion = [...facilities]
      .filter((f) => f.suspicion > 0)
      .sort((a, b) => b.suspicion - a.suspicion)[0];
    if (!highestSuspicion) {
      addToast("Şüphe zaten sıfır", "info");
      return;
    }
    await bribeOfficials(highestSuspicion.facility_type || "mining", 5);
    addToast("Rüşvet verildi, şüphe düştü!", "success");
  };

  // Group by tier
  const tierKeys = ["basic", "organic", "mystical"] as const;
  const tiers = useMemo(() => {
    return tierKeys.map((tierKey, idx) => {
      const tierTypes = getFacilitiesByTier(tierKey);
      return {
        tier: idx + 1,
        label: tierLabels[idx + 1],
        facilities: tierTypes.map((type) => {
          const config = FACILITIES_CONFIG[type];
          const playerFacility = facilities.find((f) => f.facility_type === type);
          return { type, config, playerFacility };
        }),
      };
    });
  }, [facilities]);

  return (
    <div className="p-4 space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-[var(--text-primary)]">🏭 Tesisler</h2>
        <span className="text-xs text-[var(--text-muted)]">
          {facilities.length} / {Object.keys(FACILITY_TYPES).length} aktif
        </span>
      </div>

      {inPrison && (
        <Card>
          <div className="p-3 text-center text-sm text-[var(--color-error)]">
            👮 Cezaevindeyken tesis işlemleri yapılamaz!
          </div>
        </Card>
      )}

      {/* Global Suspicion */}
      <Card>
        <div className="p-3">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-[var(--text-primary)]">
              🕵️ Genel Şüphe
            </span>
            <span
              className="text-xs font-bold"
              style={{ color: suspicionColor(globalSuspicion) }}
            >
              %{globalSuspicion}
            </span>
          </div>
          <ProgressBar
            value={globalSuspicion}
            max={100}
            color={globalSuspicion >= 80 ? "health" : globalSuspicion >= 50 ? "warning" : "success"}
            size="sm"
          />
          <div className="mt-2 flex justify-end">
            <Button
              variant="gold"
              size="sm"
              disabled={gems < 5 || inPrison}
              onClick={handleBribe}
            >
              💎5 Rüşvet Ver
            </Button>
          </div>
        </div>
      </Card>

      {/* Tier Groups */}
      {tiers.map((tierGroup) => (
        <div key={tierGroup.tier}>
          <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">
            {tierGroup.label}
          </h3>
          <div className="grid grid-cols-3 gap-2">
            {tierGroup.facilities.map(({ type, config, playerFacility }) => {
              const isUnlocked = !!playerFacility;
              const canUnlock = level >= config.unlock_level && gold >= config.unlock_cost;
              const productionCount = playerFacility?.facility_queue?.length || 0;

              return (
                <motion.div
                  key={type}
                  whileTap={{ scale: 0.95 }}
                  className={`rounded-lg border p-2 text-center transition-all cursor-pointer ${
                    isUnlocked
                      ? "bg-[var(--bg-card)] border-[var(--border-default)]"
                      : "bg-[var(--bg-darker)] border-[var(--border-subtle)] opacity-60"
                  }`}
                  onClick={() => {
                    if (isUnlocked) {
                      router.push(`/facilities/${type}`);
                    } else if (canUnlock && !inPrison) {
                      handleUnlock(type);
                    } else if (!canUnlock) {
                      addToast(
                        level < config.unlock_level
                          ? `Seviye ${config.unlock_level} gerekli`
                          : `${formatGold(config.unlock_cost)} altın gerekli`,
                        "warning"
                      );
                    }
                  }}
                >
                  <span className="text-2xl">{config.icon}</span>
                  <p className="text-[10px] font-medium text-[var(--text-primary)] mt-1 truncate">
                    {config.name}
                  </p>
                  {isUnlocked ? (
                    <div className="mt-1">
                      <p className="text-[9px] text-[var(--text-muted)]">
                        Lv.{playerFacility.level}
                        {productionCount > 0 && ` • ⏳${productionCount}`}
                      </p>
                      {(playerFacility.suspicion || 0) > 0 && (
                        <div className="w-full h-1 rounded-full bg-[var(--bg-darker)] mt-1">
                          <div
                            className="h-full rounded-full transition-all"
                            style={{
                              width: `${playerFacility.suspicion}%`,
                              backgroundColor: suspicionColor(playerFacility.suspicion || 0),
                            }}
                          />
                        </div>
                      )}
                    </div>
                  ) : (
                    <p className="text-[9px] text-[var(--text-muted)] mt-1">
                      🔒 Lv.{config.unlock_level}
                    </p>
                  )}
                </motion.div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
