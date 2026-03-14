// ============================================================
// Facility Detail Client Component — Kaynak: FacilitiesScreen.gd detail modal
// Üretim, kuyruk, tarifler, upgrade (tabs)
// ============================================================

"use client";

import { useEffect, useState, useMemo, useRef, useCallback } from "react";
import { useRouter } from "next/navigation";
import { useFacilityStore } from "@/stores/facilityStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import { useCountdown } from "@/hooks/useCountdown";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { Modal } from "@/components/ui/Modal";
import { FACILITIES_CONFIG } from "@/data/FacilityConfig";
import { getResourceDefinition, RESOURCE_RARITIES } from "@/data/ResourceCatalog";
import { formatGold } from "@/lib/utils/string";
import { PRODUCTION_DURATION_SECONDS, RARITY_UNLOCK_LEVELS } from "@/stores/facilityStore";
import type { FacilityType, ProductionQueueItem } from "@/types/facility";

export default function FacilityDetailClient({ type }: { type: string }) {
  const router = useRouter();
  const facilityType = type as FacilityType;
  const config = FACILITIES_CONFIG[facilityType];

  const facilities = useFacilityStore((s) => s.facilities);
  const startProduction = useFacilityStore((s) => s.startProduction);
  const collectProduction = useFacilityStore((s) => s.collectProduction);
  const upgradeFacility = useFacilityStore((s) => s.upgradeFacility);
  const fetchFacilities = useFacilityStore((s) => s.fetchFacilities);
  const isLoading = useFacilityStore((s) => s.isLoading);
  const gold = usePlayerStore((s) => s.gold);
  const energy = usePlayerStore((s) => s.energy);
  const inPrison = usePlayerStore((s) => s.inPrison);
  const addToast = useUiStore((s) => s.addToast);

  const [upgradeConfirm, setUpgradeConfirm] = useState(false);
  const [activeTab, setActiveTab] = useState<"overview" | "queue">("overview");
  const lastBaseProducedRef = useRef<number>(0);

  const facility = useMemo(
    () => facilities.find((f) => f.facility_type === facilityType),
    [facilities, facilityType]
  );

  useEffect(() => {
    fetchFacilities();
  }, [fetchFacilities, facilityType]);

  if (!config) {
    return (
      <div className="p-4 text-center text-[var(--text-muted)]">
        Tesis bulunamadı
      </div>
    );
  }

  if (!facility) {
    return (
      <div className="p-4 text-center">
        <p className="text-[var(--text-muted)] mb-4">Bu tesis henüz açılmamış</p>
        <Button variant="secondary" onClick={() => router.back()}>
          ← Geri
        </Button>
      </div>
    );
  }

  const upgradeCost = Math.floor(
    config.base_upgrade_cost * Math.pow(config.upgrade_multiplier, Math.max(0, facility.level - 1))
  );
  const productionStartedAt = facility.production_started_at;
  const canUpgrade = gold >= upgradeCost && (facility.level ?? 0) < 10 && !productionStartedAt;
  const productionTargetDate = productionStartedAt
    ? new Date(Date.parse(productionStartedAt) + PRODUCTION_DURATION_SECONDS * 1000).toISOString()
    : null;

  // ── Godot ile birebir: gerçek zamanlı üretilen kaynaklar ──────────────
  // Canlı üretim için detaylı konsol log (3s aralık)
  const [liveResources, setLiveResources] = useState<Array<{ item_id: string; rarity: string; quantity: number }>>([]);

  const hashString = useCallback((str: string): number => {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash |= 0;
    }
    return hash;
  }, []);

  const calcLiveResources = useCallback(() => {
    // Clear previous logs so console shows the latest snapshot only
    console.clear();

    if (!productionStartedAt) {
      console.log('[FacilityDetail] No active production for', facilityType);
      setLiveResources([]);
      return;
    }

    const baseRate = config.base_rate || 10;
    const durationMs = PRODUCTION_DURATION_SECONDS * 1000;
    const startedTs = Date.parse(productionStartedAt);
    const now = Date.now();
    const elapsedMs = Math.max(0, Math.min(now - startedTs, durationMs));

    const elapsedSeconds = elapsedMs / 1000;
    const effectiveElapsedSeconds = elapsedSeconds >= 115 ? PRODUCTION_DURATION_SECONDS : elapsedSeconds;
    const baseCalc = (effectiveElapsedSeconds / 3600.0) * (baseRate * (facility.level || 1) * 10);
    const baseProduced = Math.round(baseCalc);
    lastBaseProducedRef.current = baseProduced;

    const seed = Math.abs(hashString(productionStartedAt || "")) % 2147483647;
    let jitterStep = 0;
    let totalProduced = baseProduced;

    // Keep small batches stable; apply soft percentage variance only for larger batches.
    if (baseProduced >= 20) {
      jitterStep = (seed % 11) - 5; // -5..+5
      totalProduced = Math.max(0, Math.round(baseProduced * (1 + jitterStep / 100)));
      const upperBound = baseProduced + Math.ceil(baseProduced * 0.1);
      totalProduced = Math.min(totalProduced, upperBound);
    }

    const items = totalProduced > 0
      ? useFacilityStore.getState().calculateIdleResources(
          facilityType,
          facility.level || 1,
          productionStartedAt,
          Math.min(totalProduced, 1000000) // allow calculateIdleResources to clamp by duration
        )
      : [];

    // Aggregate by item_id + rarity
    const agg: Record<string, { item_id: string; rarity: string; quantity: number }> = {};
    for (const it of items) {
      const key = `${it.item_id}::${it.rarity}`;
      if (!agg[key]) agg[key] = { item_id: it.item_id, rarity: it.rarity, quantity: 0 };
      agg[key].quantity += 1;
    }
    // Sort aggregated results by rarity/value (legendary -> epic -> rare -> uncommon -> common)
    const rarityRank: Record<string, number> = { mythic: 6, legendary: 5, epic: 4, rare: 3, uncommon: 2, common: 1 };
    const aggregated = Object.values(agg).sort((a, b) => {
      const ra = rarityRank[a.rarity] || 0;
      const rb = rarityRank[b.rarity] || 0;
      if (ra !== rb) return rb - ra; // higher rarity first
      return b.quantity - a.quantity; // then by quantity
    });
    setLiveResources(aggregated);

    // Detailed console output
    console.log('[FacilityDetail] Production snapshot — facility:', facilityType, 'level:', facility.level);
    console.log('[FacilityDetail] production_started_at:', productionStartedAt, 'now:', new Date(now).toISOString());
    console.log('[FacilityDetail] elapsed_seconds:', elapsedSeconds.toFixed(2), 'effective_elapsed_seconds:', effectiveElapsedSeconds.toFixed(2), 'duration_seconds:', durationMs / 1000);
    console.log('[FacilityDetail] baseCalc:', baseCalc.toFixed(3), 'baseProduced:', baseProduced, 'jitterStepPercent:', jitterStep, 'totalProduced:', totalProduced);
    console.log('[FacilityDetail] aggregated preview items count:', aggregated.reduce((s, a) => s + a.quantity, 0));
    console.table(aggregated.slice(0, 50));
  }, [productionStartedAt, facilityType, facility.level, hashString]);

  // İlk render + her 3 saniyede kaynak hesapla (detaylı konsol log için)
  useEffect(() => {
    calcLiveResources();
    if (!productionStartedAt) return;
    const id = setInterval(calcLiveResources, 3_000);
    return () => clearInterval(id);
  }, [productionStartedAt, calcLiveResources]);

  // Not: `calcLiveResources` her 3 saniyede çalışarak önizlemeyi güncelliyor —
  // bu sadece UI güncelleme sıklığıdır. Üretim süresi `PRODUCTION_DURATION_SECONDS`
  // ile tanımlanır (varsayılan 120s) ve üretim bu süre tamamlanana dek sürer.

  // ── Üretim sürüyorken polling (forceRefresh=true ile cache atlatılır) ──
  useEffect(() => {
    if (!productionStartedAt) return;
    const startedTs = Date.parse(productionStartedAt);
    const durationMs = PRODUCTION_DURATION_SECONDS * 1000;
    let stopped = false;

    const tick = async () => {
      if (stopped) return;
      const elapsed = Date.now() - startedTs;
      // Üretim tamamlandıysa force refresh ile son veriyi çek
      await fetchFacilities(true);
      if (elapsed >= durationMs) {
        stopped = true;
      }
    };

    // Her 10 saniyede sunucudan taze veri al (Godot: facilities_updated signal)
    const id = setInterval(tick, 10_000);
    tick(); // ilk anında da çalıştır
    return () => {
      stopped = true;
      clearInterval(id);
    };
  }, [productionStartedAt, fetchFacilities]);

  const handleStartProduction = async () => {
    if (inPrison) {
      addToast("Cezaevindeyken üretim başlatılamaz", "warning");
      return;
    }
    console.log("[FacilityDetail] Starting production, facility:", facility);
    const ok = await startProduction(facility.id);
    if (ok) addToast("Üretim başlatıldı!", "success");
    else addToast(useFacilityStore.getState().error || "Üretim başlatılamadı", "error");
  };

  const handleCollect = async (queueItemId: string) => {
    // Godot: DetailModal.gd line 682 — Prison check
    if (inPrison) {
      addToast("Cezaevindeyken toplama yapılamaz", "warning");
      return;
    }

    // Send base produced count to server; server applies deterministic jitter once.
    const requestCount = lastBaseProducedRef.current;

    // Godot: FacilityManager.gd lines 1070-1077 — Generate deterministic seed
    const seed = Math.abs(hashString(productionStartedAt || "")) % 2147483647;
    
    console.log("[FacilityDetail] Collecting resources:", {
      facilityId: facility.id,
      requestCount,
      seed,
      productionStartedAt,
    });

    // Godot: FacilityManager.gd lines 1085-1186
    // Call collectResourcesV2 with deterministic seed
    const collectResult = await useFacilityStore
      .getState()
      .collectResourcesV2(facility.id, seed, requestCount);

      if (collectResult) {
      // Godot: DetailModal.gd lines 692-696 — Handle admission_occurred
      const result = collectResult as Record<string, unknown>;
      const admissionOccurred = result.admission_occurred || false;
      const serverCollectedCount = Number(result.count || 0);
      
      if (admissionOccurred) {
        // Godot: DetailModal.gd line 693 — Show prison toast, resources lost
        const prisonReason = String(result.prison_reason || "Bilinmiyor");
        addToast(`⚠️ Hapse düştünüz! Gerekçe: ${prisonReason}`, "error");
        // Note: In Godot, FacilityManager.collect_facility_resources() calls
        // Scenes.change_scene("PrisonScreen") automatically after admission
        // On Web, we let the app router handle navigation when inPrison becomes true
        await usePlayerStore.getState().refreshData();
      } else {
        // Godot: DetailModal.gd line 695 — Show success toast
        addToast(`✅ Toplandı: ${serverCollectedCount} kaynak`, "success");
      }
      
      // Godot: DetailModal.gd line 696 — _populate_queue_tab() (refresh UI)
      // On Web, we refresh facilities, player and inventory (inventory only when not imprisoned)
      await fetchFacilities(true);
      await usePlayerStore.getState().refreshData();

      // Always attempt inventory refresh — server authoritative will reflect no-change when admission occurred
      await useInventoryStore.getState().fetchInventory();
    } else {
      const error = useFacilityStore.getState().error;
      addToast(`❌ ${error || "Toplama başarısız"}`, "error");
    }
  };

  const handleUpgrade = async () => {
    const ok = await upgradeFacility(facility.id);
    if (ok) addToast(`${config.name} yükseltildi! Lv.${facility.level + 1}`, "success");
    else addToast(`${config.name} yükseltilemedi`, "error");
    setUpgradeConfirm(false);
  };

  return (
    <div className="relative p-4 space-y-4 pb-24 overflow-hidden">
      <div className="pointer-events-none absolute -top-16 -right-16 w-60 h-60 rounded-full blur-3xl opacity-25 bg-cyan-500" />
      <div className="pointer-events-none absolute top-1/3 -left-20 w-64 h-64 rounded-full blur-3xl opacity-20 bg-amber-500" />

      <Card className="relative overflow-hidden border border-[var(--border-default)] bg-[linear-gradient(140deg,rgba(26,33,47,0.95),rgba(11,14,21,0.95))]">
        <div className="absolute inset-0 opacity-30 bg-[radial-gradient(circle_at_top_right,rgba(56,189,248,0.32),transparent_55%)]" />
        <div className="relative flex items-start justify-between gap-3">
          <div className="flex items-start gap-3">
            <button
              onClick={() => router.back()}
              className="mt-0.5 text-[var(--text-secondary)] hover:text-[var(--text-primary)]"
            >
              ←
            </button>
            <span className="text-4xl">{config.icon}</span>
            <div>
              <p className="text-[11px] uppercase tracking-[0.2em] text-cyan-300">Tesis Konsolu</p>
              <h2 className="text-xl font-black text-[var(--text-primary)]">{config.name}</h2>
              <p className="text-xs text-[var(--text-secondary)] mt-1">{config.description}</p>
            </div>
          </div>
          <span className="text-xs px-2 py-1 rounded-full border border-cyan-400/30 text-cyan-200 bg-cyan-900/25">
            Lv.{facility.level}
          </span>
        </div>

        <div className="relative mt-4 grid grid-cols-3 gap-2">
          <div className="rounded-xl border border-white/10 bg-black/25 px-3 py-2">
            <p className="text-[10px] text-[var(--text-muted)]">Enerji</p>
            <p className="text-sm font-bold text-cyan-300">{energy}</p>
          </div>
          <div className="rounded-xl border border-white/10 bg-black/25 px-3 py-2">
            <p className="text-[10px] text-[var(--text-muted)]">Altın</p>
            <p className="text-sm font-bold text-amber-300">{formatGold(gold)}</p>
          </div>
          <div className="rounded-xl border border-white/10 bg-black/25 px-3 py-2">
            <p className="text-[10px] text-[var(--text-muted)]">Durum</p>
            <p className="text-sm font-bold text-white">{productionStartedAt ? "Üretimde" : "Boşta"}</p>
          </div>
        </div>
      </Card>

      <div className="rounded-2xl border border-[var(--border-default)] bg-black/20 p-1.5 flex gap-1">
        <button
          className={`flex-1 px-3 py-2 text-sm rounded-xl transition-all ${activeTab === 'overview' ? 'bg-cyan-500/20 border border-cyan-400/35 text-cyan-100 font-semibold' : 'text-[var(--text-secondary)] hover:bg-white/5'}`}
          onClick={() => setActiveTab('overview')}
        >
          Genel Bakış
        </button>
        <button
          className={`flex-1 px-3 py-2 text-sm rounded-xl transition-all ${activeTab === 'queue' ? 'bg-cyan-500/20 border border-cyan-400/35 text-cyan-100 font-semibold' : 'text-[var(--text-secondary)] hover:bg-white/5'}`}
          onClick={() => setActiveTab('queue')}
        >
          Üretim Kuyruğu
        </button>
      </div>

      {activeTab === 'overview' && (
        <>
          {productionStartedAt && productionTargetDate ? (
            <Card className="border border-emerald-500/30 bg-[linear-gradient(135deg,rgba(8,45,34,0.72),rgba(8,16,18,0.94))]">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-semibold text-emerald-200">🟢 Üretim Devam Ediyor</span>
                <span className="text-xs text-emerald-100">⏱️ <CountdownInline targetDate={productionTargetDate} /></span>
              </div>
              {liveResources.length > 0 && (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 mt-3">
                  {liveResources.map((r) => (
                    <div key={`${r.item_id}-${r.rarity}`} className="rounded-lg border border-white/10 bg-black/25 px-3 py-2 text-[11px]">
                      <span className="font-semibold text-[var(--text-primary)]">{getResourceDefinition(r.item_id)?.name ?? r.item_id}</span>
                      <span className="ml-1 text-[var(--text-secondary)]">×{r.quantity}</span>
                      <span className="ml-2 text-[10px] uppercase tracking-wide text-cyan-300">{r.rarity}</span>
                    </div>
                  ))}
                </div>
              )}
            </Card>
          ) : (
            <Button variant="primary" fullWidth size="lg" isLoading={isLoading} disabled={inPrison || energy < 50} onClick={handleStartProduction}>
              ⚡ Üretimi Başlat
            </Button>
          )}

          <Card variant="elevated" className="border border-[var(--border-default)] bg-[linear-gradient(150deg,rgba(22,24,36,0.95),rgba(12,14,20,0.95))]">
            <div className="p-1">
              <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">📦 Üretilebilir Kaynaklar</h3>
              <div className="grid grid-cols-2 gap-3">
                {config.resources.map((item) => {
                  const resource = getResourceDefinition(item);
                  const weights = useFacilityStore.getState().getRarityWeightsAtLevel(facility.level);
                  const total = Object.values(weights).reduce((s, v) => s + v, 0);
                  const inherentTier = resource?.rarity ?? 'common';
                  const isUnlocked = facility.level >= RARITY_UNLOCK_LEVELS[inherentTier];
                  const rarityPercent = total > 0 ? (weights[inherentTier] ?? 0) / total * 100 : 0;
                  const rarityEmoji = { common: '⚪', uncommon: '🟢', rare: '🔵', epic: '🟣', legendary: '🟡', mythic: '🌈' }[inherentTier] || '⚪';

                  return (
                    <div key={item} className="p-3 rounded-xl border border-white/10 bg-black/20">
                      <div className="text-lg mb-1">{rarityEmoji}</div>
                      <p className="text-xs font-semibold text-[var(--text-primary)]">{resource?.name ?? item}</p>
                      {resource?.name_tr && <p className="text-[10px] text-[var(--text-muted)]">{resource.name_tr}</p>}
                      <p className="text-[10px] text-cyan-300 mt-1">{rarityPercent.toFixed(1)}% {isUnlocked ? '' : '(kilitli)'}</p>
                    </div>
                  );
                })}
              </div>
            </div>
          </Card>

          <Card className="border border-[var(--border-default)] bg-[linear-gradient(150deg,rgba(17,20,30,0.95),rgba(10,12,18,0.95))]">
            <div className="p-1">
              <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">✨ Nadirlik Simülatörü (Lv.1-10)</h3>
              <div className="space-y-2 max-h-80 overflow-y-auto pr-1">
                {Array.from({ length: 10 }, (_, i) => i + 1).map((level) => {
                  const weights = useFacilityStore.getState().getRarityWeightsAtLevel(level);
                  const total = Object.values(weights).reduce((s, v) => s + v, 0);
                  const isCurrent = level === facility.level;

                  return (
                    <div key={level} className={`rounded-xl border px-3 py-2 ${isCurrent ? 'border-cyan-400/45 bg-cyan-500/10' : 'border-white/10 bg-black/15'}`}>
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-xs font-semibold text-[var(--text-primary)]">Lv.{level}</span>
                        {isCurrent && <span className="text-[10px] text-cyan-200">Mevcut Seviye</span>}
                      </div>
                      <div className="grid grid-cols-2 gap-2">
                        {RESOURCE_RARITIES.map((rarity) => {
                          const pct = total > 0 ? (weights[rarity] / total) * 100 : 0;
                          const rarityLabel = { common: 'Common', uncommon: 'Uncommon', rare: 'Rare', epic: 'Epic', legendary: 'Legendary', mythic: 'Mythic' }[rarity];
                          return (
                            <div key={rarity} className="rounded-lg border border-white/10 bg-black/20 px-2 py-1.5">
                              <div className="flex items-center justify-between text-[10px] text-[var(--text-secondary)]">
                                <span>{rarityLabel}</span>
                                <span>{pct.toFixed(rarity === 'common' || rarity === 'uncommon' || rarity === 'rare' ? 0 : 1)}%</span>
                              </div>
                              <div className="mt-1 h-1.5 rounded-full bg-white/10 overflow-hidden">
                                <div className="h-full rounded-full bg-gradient-to-r from-cyan-400 to-emerald-400" style={{ width: `${Math.max(2, Math.min(100, pct))}%` }} />
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </Card>

          <Card className="border border-amber-500/30 bg-[linear-gradient(140deg,rgba(45,28,8,0.68),rgba(18,14,10,0.94))]">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h3 className="text-sm font-semibold text-amber-100">⬆️ Yükseltme Paneli</h3>
                <p className="text-xs text-amber-200/90 mt-1">
                  Hedef: {facility.level >= 10 ? 'Maksimum Seviye' : `Lv.${facility.level + 1}`} • Maliyet: {formatGold(upgradeCost)} altın
                </p>
                {productionStartedAt && <p className="text-[10px] text-[var(--color-warning)] mt-1">Önce mevcut üretimi tamamlayın.</p>}
              </div>
              <Button variant="gold" size="sm" disabled={!canUpgrade || inPrison} onClick={() => setUpgradeConfirm(true)}>
                Yükselt
              </Button>
            </div>
          </Card>
        </>
      )}

      {activeTab === 'queue' && (
        <>
          <Card className="border border-[var(--border-default)] bg-[linear-gradient(145deg,rgba(20,24,34,0.95),rgba(10,12,18,0.95))]">
            <div className="flex items-center justify-between">
              {productionTargetDate && Date.now() < Date.parse(productionTargetDate) ? (
                <>
                  <span className="text-sm font-semibold text-emerald-300">🟢 Üretim Sürüyor</span>
                  <span className="text-xs text-[var(--text-secondary)]">⏱️ <CountdownInline targetDate={productionTargetDate} /></span>
                </>
              ) : productionTargetDate && Date.now() >= Date.parse(productionTargetDate) && liveResources.length > 0 ? (
                <span className="text-sm font-semibold text-amber-300">🟡 Süre doldu, toplama hazır</span>
              ) : (
                <span className="text-sm font-semibold text-[var(--text-secondary)]">🔴 Üretim durdu</span>
              )}
            </div>
          </Card>

          <Card className="border border-[var(--border-default)] bg-[linear-gradient(145deg,rgba(16,19,28,0.95),rgba(9,11,16,0.95))]">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-semibold text-[var(--text-primary)]">📦 Depo</h3>
              <span className="text-xs text-cyan-300">Toplam: {liveResources.reduce((sum, r) => sum + r.quantity, 0)}</span>
            </div>

            {liveResources.length > 0 && (
              <div className="grid grid-cols-2 gap-2 mb-4">
                {liveResources.map((r) => (
                  <div key={`${r.item_id}-${r.rarity}`} className="p-3 rounded-xl border border-white/10 bg-black/20">
                    <div className="text-xs font-semibold text-[var(--text-primary)] truncate">{getResourceDefinition(r.item_id)?.name ?? r.item_id}</div>
                    <div className="mt-1 text-[10px] text-[var(--text-secondary)] uppercase tracking-wide">{r.rarity}</div>
                    <div className="text-[11px] font-bold text-cyan-200">×{r.quantity}</div>
                  </div>
                ))}
              </div>
            )}

            {liveResources.length === 0 && productionStartedAt && productionTargetDate && Date.now() < Date.parse(productionTargetDate) && (
              <div className="text-center text-xs text-[var(--text-muted)] my-4 py-6">🔨 İşçiler üretime devam ediyor...</div>
            )}

            {liveResources.length === 0 && !productionStartedAt && (
              <div className="text-center text-xs text-[var(--text-muted)] my-4 py-6">Depo boş. Üretimi başlatın.</div>
            )}

            <div className="mt-4 space-y-2">
              {liveResources.length > 0 && productionTargetDate && Date.now() >= Date.parse(productionTargetDate) && (
                <>
                  <Button variant="primary" fullWidth size="lg" disabled={inPrison} onClick={() => handleCollect(facility.id)}>
                    ✅ Kaynakları Topla ({liveResources.reduce((sum, r) => sum + r.quantity, 0)})
                  </Button>
                  <p className="text-xs text-[var(--text-muted)] text-center">Toplama sonrası yeni üretim başlatabilirsiniz.</p>
                </>
              )}

              {liveResources.length > 0 && productionTargetDate && Date.now() < Date.parse(productionTargetDate) && (
                <>
                  <Button variant="secondary" fullWidth size="lg" disabled>
                    ⏳ Bekleyin: <CountdownInline targetDate={productionTargetDate} />
                  </Button>
                  <p className="text-xs text-[var(--text-muted)] text-center">Süre dolunca toplama aktif olur.</p>
                </>
              )}

              {liveResources.length === 0 && !productionStartedAt && (
                <>
                  <Button
                    variant="primary"
                    fullWidth
                    size="lg"
                    isLoading={isLoading}
                    disabled={inPrison || energy < 50}
                    onClick={handleStartProduction}
                  >
                    ⚡ Üretimi Başlat
                  </Button>
                  <p className="text-xs text-[var(--text-muted)] text-center">Maliyet: 50 Enerji (Mevcut: {energy || 0})</p>
                  {energy < 50 && <p className="text-xs text-[var(--color-error)] text-center">❌ Yetersiz enerji</p>}
                </>
              )}
            </div>
          </Card>
        </>
      )}

      <Modal isOpen={upgradeConfirm} onClose={() => setUpgradeConfirm(false)} title="Yükseltme Onayı" size="sm">
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            {config.name} tesisini Lv.{facility.level + 1}&apos;e yükseltmek için <strong>{formatGold(upgradeCost)} altın</strong> harcanacak.
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setUpgradeConfirm(false)}>
              Vazgeç
            </Button>
            <Button variant="primary" size="sm" fullWidth isLoading={isLoading} onClick={handleUpgrade} disabled={inPrison}>
              Onayla
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}

// ============================================================
// Countdown Inline — MM:SS format
// ============================================================

function CountdownInline({ targetDate }: { targetDate: string }) {
  const { formatted, isComplete } = useCountdown({ targetDate });
  return (
    <span>
      {isComplete ? <span className="text-[var(--color-success)]">✅</span> : <span>{formatted}</span>}
    </span>
  );
}

