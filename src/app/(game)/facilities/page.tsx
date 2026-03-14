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
  const prisonReason = usePlayerStore((s) => s.prisonReason);
  const payBail = usePlayerStore((s) => (s as any).payBail);
  const resetAllProduction = useFacilityStore((s) => (s as any).resetAllProduction);
  const prisonUntil = usePlayerStore((s) => s.prisonUntil);
  const addToast = useUiStore((s) => s.addToast);

  const inPrison = isInPrison(prisonUntil);

  // Global suspicion (average)
  const globalSuspicion = useFacilityStore((s) => s.getGlobalSuspicionRisk());

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
    // Confirm like Godot
    if (!window.confirm(`${config.name} açmak için ${formatGold(config.unlock_cost)} altını harcamak istediğinize emin misiniz?`)) return;
    const ok = await unlockFacility(type);
    if (ok) addToast(`${config.name} açıldı!`, "success");
  };

  const handleBribe = async () => {
    if (gems < 5) {
      addToast("Rüşvet için 5 gem gerekli", "warning");
      return;
    }
    // Bribe using any unlocked facility type (we only track global suspicion)
    const unlocked = facilities.find((f) => !!f);
    if (!unlocked) {
      addToast("Rüşve t için açık tesis yok", "info");
      return;
    }
    if (!window.confirm(`Seçilen tesis: ${unlocked.facility_type}. 5 Gem ile rüşvet vermek istiyor musunuz?`)) return;
    const ok = await bribeOfficials(unlocked.facility_type || "mining", 5);
    if (ok) addToast("Rüşvet verildi, genel şüphe güncellendi!", "success");
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
    <div className="relative overflow-hidden p-4 space-y-4 pb-24">
      <div className="pointer-events-none absolute -top-24 -right-24 w-72 h-72 rounded-full blur-3xl opacity-25 bg-cyan-400" />
      <div className="pointer-events-none absolute top-40 -left-24 w-72 h-72 rounded-full blur-3xl opacity-20 bg-amber-400" />

      <Card className="relative overflow-hidden border border-[var(--border-default)] bg-[linear-gradient(135deg,rgba(30,35,48,0.95),rgba(15,17,24,0.95))]">
        <div className="absolute inset-0 opacity-30 bg-[radial-gradient(circle_at_top_right,rgba(56,189,248,0.35),transparent_55%)]" />
        <div className="relative flex items-start justify-between gap-3">
          <div>
            <p className="text-[11px] tracking-[0.2em] uppercase text-cyan-300">Operasyon Merkezi</p>
            <h2 className="text-xl font-black text-[var(--text-primary)]">Tesis Ağı</h2>
            <p className="text-xs text-[var(--text-secondary)] mt-1">İstasyonları yönet, üretimi ölçekle, riski kontrol et.</p>
          </div>
          <div className="text-right">
            <p className="text-[10px] text-[var(--text-muted)]">Aktif Tesis</p>
            <p className="text-lg font-black text-cyan-300">{facilities.length} / {Object.keys(FACILITY_TYPES).length}</p>
          </div>
        </div>

        <div className="relative mt-4 grid grid-cols-3 gap-2">
          <div className="rounded-xl border border-white/10 bg-black/25 px-3 py-2">
            <p className="text-[10px] text-[var(--text-muted)]">Seviye</p>
            <p className="text-sm font-bold text-white">Lv.{level}</p>
          </div>
          <div className="rounded-xl border border-white/10 bg-black/25 px-3 py-2">
            <p className="text-[10px] text-[var(--text-muted)]">Altın</p>
            <p className="text-sm font-bold text-amber-300">{formatGold(gold)}</p>
          </div>
          <div className="rounded-xl border border-white/10 bg-black/25 px-3 py-2">
            <p className="text-[10px] text-[var(--text-muted)]">Gem</p>
            <p className="text-sm font-bold text-fuchsia-300">{gems}</p>
          </div>
        </div>

        {(process.env.NODE_ENV === "development" || level >= 99) && (
          <div className="relative mt-3 flex justify-end">
            <button
              className="text-xs px-3 py-1.5 rounded-lg border border-white/15 bg-black/25 hover:bg-black/40 transition-colors"
              onClick={async () => {
                const res = await resetAllProduction();
                if (res?.success) {
                  addToast(`✅ Reset: ${res.facilities_reset} tesis, ${res.queue_items_deleted} kuyruk silindi`, "success");
                } else {
                  addToast("Reset başarısız", "error");
                }
              }}
            >
              🔧 TEST: Reset Tüm Üretim
            </button>
          </div>
        )}
      </Card>

      {inPrison && (
        <Card className="border border-red-500/40 bg-[linear-gradient(135deg,rgba(90,20,20,0.45),rgba(20,10,10,0.9))]">
          <div className="p-1 text-sm text-red-200">
            <div className="flex items-center justify-between gap-2">
              <p className="font-semibold">👮 Cezaevindesiniz, operasyonlar kilitli.</p>
              <span className="text-[10px] px-2 py-1 rounded bg-red-950/60 border border-red-700/40">Acil Durum</span>
            </div>
            <p className="mt-2 text-xs text-red-100/90">📄 Gerekçe: {prisonReason || "Bilinmiyor"}</p>
            <div className="mt-3">
              {prisonUntil && (
                <PrisonBailRow
                  prisonUntil={prisonUntil}
                  gems={gems}
                  onPay={async () => {
                    const result = await payBail?.();
                    if (result?.success) {
                      addToast("✅ Kefalet ödendi, serbest bırakıldınız", "success");
                      await fetchFacilities();
                    } else {
                      addToast(result?.error || "Kefalet başarısız", "error");
                    }
                  }}
                />
              )}
            </div>
          </div>
        </Card>
      )}

      <Card className="border border-[var(--border-default)] bg-[linear-gradient(135deg,rgba(8,28,36,0.8),rgba(8,12,20,0.95))]">
        <div className="p-1">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-semibold text-cyan-200">🕵️ Genel Şüphe İndeksi</span>
            <span className="text-xs font-black" style={{ color: suspicionColor(globalSuspicion) }}>
              %{globalSuspicion}
            </span>
          </div>
          <ProgressBar
            value={globalSuspicion}
            max={100}
            color={globalSuspicion >= 80 ? "health" : globalSuspicion >= 50 ? "warning" : "success"}
            size="sm"
          />
          <div className="mt-3 flex items-center justify-between gap-2">
            <p className="text-[11px] text-[var(--text-secondary)]">Yüksek şüphe, baskın ve hapis riskini artırır.</p>
            <Button variant="gold" size="sm" disabled={gems < 5 || inPrison} onClick={handleBribe}>
              💎 5 Rüşvet Ver
            </Button>
          </div>
        </div>
      </Card>

      {tiers.map((tierGroup) => (
        <section key={tierGroup.tier} className="space-y-2">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-[var(--text-primary)]">{tierGroup.label}</h3>
            <span className="text-[10px] text-[var(--text-muted)]">{tierGroup.facilities.length} istasyon</span>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            {tierGroup.facilities.map(({ type, config, playerFacility }) => {
              const isUnlocked = !!playerFacility;
              const canUnlock = level >= config.unlock_level && gold >= config.unlock_cost;
              const productionCount = playerFacility?.facility_queue?.length || 0;

              return (
                <motion.button
                  key={type}
                  whileTap={{ scale: 0.97 }}
                  className={`text-left rounded-2xl border p-3 transition-all ${
                    isUnlocked
                      ? "border-cyan-500/30 bg-[linear-gradient(145deg,rgba(20,27,38,0.95),rgba(11,15,22,0.95))] hover:border-cyan-300/45 hover:-translate-y-0.5"
                      : "border-[var(--border-default)] bg-[linear-gradient(145deg,rgba(18,18,22,0.95),rgba(12,12,16,0.95))] opacity-80"
                  }`}
                  onClick={() => {
                    if (inPrison) {
                      addToast("Cezaevindeyken detaylara erişilemez. Kefalet ödeyerek serbest kalabilirsiniz.", "warning");
                      return;
                    }
                    if (isUnlocked) {
                      router.push(`/facilities/${type}`);
                    } else if (canUnlock) {
                      handleUnlock(type);
                    } else {
                      addToast(
                        level < config.unlock_level
                          ? `Seviye ${config.unlock_level} gerekli`
                          : `${formatGold(config.unlock_cost)} altın gerekli`,
                        "warning"
                      );
                    }
                  }}
                >
                  <div className="flex items-start justify-between gap-2">
                    <span className="text-2xl">{config.icon}</span>
                    {isUnlocked ? (
                      <span className="text-[10px] px-2 py-1 rounded-full bg-emerald-500/15 text-emerald-300 border border-emerald-500/25">
                        Aktif
                      </span>
                    ) : (
                      <span className="text-[10px] px-2 py-1 rounded-full bg-white/10 text-[var(--text-secondary)] border border-white/15">
                        Kilitli
                      </span>
                    )}
                  </div>

                  <p className="mt-2 text-xs font-semibold text-[var(--text-primary)] leading-tight">{config.name}</p>

                  {isUnlocked ? (
                    <div className="mt-2 grid grid-cols-2 gap-2">
                      <div className="rounded-lg bg-black/25 px-2 py-1.5 border border-white/10">
                        <p className="text-[9px] text-[var(--text-muted)]">Seviye</p>
                        <p className="text-[11px] font-bold text-white">Lv.{playerFacility.level}</p>
                      </div>
                      <div className="rounded-lg bg-black/25 px-2 py-1.5 border border-white/10">
                        <p className="text-[9px] text-[var(--text-muted)]">Kuyruk</p>
                        <p className="text-[11px] font-bold text-white">⏳ {productionCount}</p>
                      </div>
                    </div>
                  ) : (
                    <div className="mt-2 space-y-1">
                      <p className="text-[10px] text-[var(--text-muted)]">🔒 Gereken Seviye: {config.unlock_level}</p>
                      <p className="text-[10px] text-[var(--text-muted)]">🪙 Maliyet: {formatGold(config.unlock_cost)}</p>
                    </div>
                  )}
                </motion.button>
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}

function PrisonBailRow({ prisonUntil, gems, onPay }: { prisonUntil: string | null; gems: number; onPay: () => Promise<void> }) {
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  if (!prisonUntil) return null;
  const prisonEndMs = Date.parse(prisonUntil);
  const remainingMs = Math.max(0, prisonEndMs - now);

  if (remainingMs === 0) {
    return (
      <div className="mt-4 text-center text-[var(--color-success)] font-bold">
        ✅ Ceza süreniz doldu! Lütfen sayfayı yenileyin.
      </div>
    );
  }

  const remainingMins = Math.ceil(remainingMs / 60000);
  const bailCost = Math.max(1, remainingMins);

  const hours = Math.floor(remainingMs / (1000 * 60 * 60));
  const mins = Math.floor((remainingMs % (1000 * 60 * 60)) / (1000 * 60));
  const secs = Math.floor((remainingMs % (1000 * 60)) / 1000);
  const timeString = `${hours > 0 ? `${hours}s ` : ""}${mins}dk ${secs}sn`;

  return (
    <div className="mt-4 flex flex-col gap-3">
      <div className="bg-[var(--bg-darker)] p-3 rounded-lg border border-[var(--color-error)] border-opacity-30 relative overflow-hidden">
        <div className="absolute inset-0 bg-red-500/10 animate-pulse"></div>
        <div className="relative z-10 flex flex-col items-center gap-2">
          <div className="text-xs font-semibold text-[var(--color-error)]">
            Hapis Cezası Devam Ediyor
          </div>
          <div className="text-2xl font-mono tabular-nums text-white">
            {timeString}
          </div>
        </div>
      </div>
      <button
        className={`w-full font-bold py-2 rounded transition-colors ${
          gems >= bailCost
            ? "bg-amber-500 hover:bg-amber-400 text-black shadow-[0_0_10px_rgba(245,158,11,0.5)]"
            : "bg-gray-700 text-gray-500 opacity-60 cursor-not-allowed"
        }`}
        disabled={gems < bailCost}
        onClick={async () => await onPay()}
      >
        💎 {bailCost} Gem ile Kefalet Öde
      </button>
    </div>
  );
}
