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
import { formatGold } from "@/lib/utils/string";
import { PRODUCTION_DURATION_SECONDS } from "@/stores/facilityStore";
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
    config.base_upgrade_cost * Math.pow(config.upgrade_multiplier, facility.level)
  );
  const canUpgrade = gold >= upgradeCost;
  const productionQueue = facility.facility_queue || [];
  const productionStartedAt = facility.production_started_at;
  const productionTargetDate = productionStartedAt
    ? new Date(Date.parse(productionStartedAt) + PRODUCTION_DURATION_SECONDS * 1000).toISOString()
    : null;

  // ── Godot ile birebir: gerçek zamanlı üretilen kaynaklar ──────────────
  // Godot: hours_elapsed * base_rate * facility_level * 10 (test 10x multiplier)
  const [liveResources, setLiveResources] = useState<Array<{ item_id: string; rarity: string; quantity: number }>>([]);

  const calcLiveResources = useCallback(() => {
    if (!productionStartedAt) {
      setLiveResources([]);
      return;
    }
    // Match server RPC `collect_facility_resources_v2` formula from veritabani_schema.sql
    // Server uses a fixed base_rate := 10 and multiplies by level and a 10x multiplier.
    // total_qty = floor((elapsed_seconds / 3600) * (base_rate * level * 10)) capped at 100
    const SERVER_BASE_RATE = 10;
    const durationMs = PRODUCTION_DURATION_SECONDS * 1000;
    const startedTs = Date.parse(productionStartedAt);
    const now = Date.now();
    const elapsedMs = Math.max(0, Math.min(now - startedTs, durationMs));

    const elapsedSeconds = elapsedMs / 1000;
    const baseCalc = (elapsedSeconds / 3600.0) * (SERVER_BASE_RATE * (facility.level || 1) * 10);
    const totalProduced = Math.floor(baseCalc);

    if (totalProduced <= 0) {
      setLiveResources([]);
      return;
    }

    const items = useFacilityStore.getState().calculateIdleResources(
      facilityType,
      facility.level || 1,
      productionStartedAt,
      Math.min(totalProduced, 100)
    );

    // item_id + rarity'ye göre topla
    const agg: Record<string, { item_id: string; rarity: string; quantity: number }> = {};
    for (const it of items) {
      const key = `${it.item_id}::${it.rarity}`;
      if (!agg[key]) agg[key] = { item_id: it.item_id, rarity: it.rarity, quantity: 0 };
      agg[key].quantity += 1;
    }
    setLiveResources(Object.values(agg));
  }, [productionStartedAt, facilityType, facility.level, config.base_rate]);

  // İlk render + her 5 saniyede kaynak hesapla (Godot'ta queue_update_timer gibi)
  useEffect(() => {
    calcLiveResources();
    if (!productionStartedAt) return;
    const id = setInterval(calcLiveResources, 5_000);
    return () => clearInterval(id);
  }, [productionStartedAt, calcLiveResources]);

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

    // Calculate resources that will be collected
    const collectedCount = liveResources.reduce((sum, r) => sum + r.quantity, 0);
    
    // Godot: FacilityManager.gd lines 1070-1077 — Generate deterministic seed
    const hashString = (str: string): number => {
      let hash = 0;
      for (let i = 0; i < str.length; i++) {
        const char = str.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash |= 0;
      }
      return hash;
    };
    const seed = Math.abs(hashString(productionStartedAt || "")) % 2147483647;
    
    console.log("[FacilityDetail] Collecting resources:", {
      facilityId: facility.id,
      collectedCount,
      seed,
      productionStartedAt,
    });

    // Godot: FacilityManager.gd lines 1085-1186
    // Call collectResourcesV2 with deterministic seed
    const collectResult = await useFacilityStore
      .getState()
      .collectResourcesV2(facility.id, seed, collectedCount);

      if (collectResult) {
      // Godot: DetailModal.gd lines 692-696 — Handle admission_occurred
      const admissionOccurred = collectResult.admission_occurred || false;
      
      if (admissionOccurred) {
        // Godot: DetailModal.gd line 693 — Show prison toast, resources lost
        addToast(`⚠️  Hapse Düştünüz! ${collectedCount} kaynak kaybedildi`, "error");
        // Note: In Godot, FacilityManager.collect_facility_resources() calls
        // Scenes.change_scene("PrisonScreen") automatically after admission
        // On Web, we let the app router handle navigation when inPrison becomes true
        await usePlayerStore.getState().refreshData();
      } else {
        // Godot: DetailModal.gd line 695 — Show success toast
        addToast(`✅ Toplandı: ${collectedCount} kaynak`, "success");
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
    <div className="p-4 space-y-4">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => router.back()}
          className="text-[var(--text-secondary)] hover:text-[var(--text-primary)]"
        >
          ←
        </button>
        <span className="text-3xl">{config.icon}</span>
        <div>
          <h2 className="text-lg font-bold text-[var(--text-primary)]">{config.name}</h2>
          <p className="text-xs text-[var(--text-muted)]">Seviye {facility.level} • {config.description}</p>
        </div>
      </div>

      

      {/* Tabs header (Godot modal uses tabs) */}
      <div className="flex gap-2">
        <button
          className={`px-3 py-1 rounded ${activeTab === 'overview' ? 'bg-[var(--accent)] text-white' : 'bg-[var(--bg-darker)]'}`}
          onClick={() => setActiveTab('overview')}
        >
          Genel
        </button>
        <button
          className={`px-3 py-1 rounded ${activeTab === 'queue' ? 'bg-[var(--accent)] text-white' : 'bg-[var(--bg-darker)]'}`}
          onClick={() => setActiveTab('queue')}
        >
          Kuyruk
        </button>
      </div>

      {/* Overview tab: resources, start, upgrade, rarity table */}
      {activeTab === 'overview' && (
        <>
          {/* Üretilebilir Kaynaklar - Non-selectable with current drop rate */}
          <Card variant="elevated">
            <div className="p-4">
              <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">📦 Üretilebilir Kaynaklar (Lv.{facility.level})</h3>
              <div className="grid grid-cols-2 gap-3">
                {config.resources.map((item, idx) => {
                  // Calculate rarity for this resource based on level
                  const weights = useFacilityStore.getState().getRarityWeightsAtLevel(facility.level);
                  const total = Object.values(weights).reduce((s, v) => s + v, 0);
                  // Determine likely rarity (simple heuristic: index determines rarity tier)
                  let rarityKey: keyof typeof weights = 'common';
                  if (idx === 1 || idx === 2) rarityKey = 'uncommon';
                  else if (idx === 3) rarityKey = 'rare';
                  else if (idx === 4) rarityKey = 'legendary';
                  
                  const rarityPercent = (weights[rarityKey] / total) * 100;
                  const rarityEmoji = { common: '⚪', uncommon: '🟢', rare: '🔵', epic: '🟣', legendary: '🟡' }[rarityKey] || '⚪';
                  
                  return (
                    <div key={item} className="p-3 rounded-lg bg-[var(--bg-darker)]">
                      <div className="text-lg mb-1">{rarityEmoji}</div>
                      <p className="text-xs font-medium text-[var(--text-primary)]">{item}</p>
                      <p className="text-[10px] text-[var(--text-muted)]">{rarityPercent.toFixed(1)}%</p>
                    </div>
                  );
                })}
              </div>
            </div>
          </Card>

          {/* Godot: üretim devam ederken başlat butonunu gösterme */}
          {productionStartedAt && !productionTargetDate ? null : productionStartedAt ? (
            <div className="rounded-lg bg-[var(--bg-darker)] border border-[var(--border-default)] p-3">
              <div className="flex items-center justify-between mb-1">
                <span className="text-sm font-medium text-[var(--color-success)]">🟢 Üretim Sürüyor</span>
                <span className="text-xs text-[var(--text-muted)]">
                  ⏱️ <CountdownInline targetDate={productionTargetDate!} />
                </span>
              </div>
              {liveResources.length > 0 && (
                <div className="mt-2 grid grid-cols-2 gap-1">
                  {liveResources.map((r) => (
                    <div key={`${r.item_id}-${r.rarity}`} className="text-[10px] text-[var(--text-muted)] bg-[var(--bg-card)] rounded px-2 py-1">
                      <span className="font-medium text-[var(--text-primary)]">{r.item_id}</span>{" "}
                      <span>×{r.quantity}</span>{" "}
                      <span className="opacity-60">[{r.rarity}]</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ) : (
            <Button variant="primary" fullWidth isLoading={isLoading} onClick={handleStartProduction}>
              ▶️ Üretim Başlat ({facility.level > 0 ? 'Lv.' + facility.level : '?'})
            </Button>
          )}

          {/* Nadirlik Tablo: Levels 1-20 */}
          <Card variant="elevated">
            <div className="p-4">
              <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">✨ Nadirlik Oranları (1-20 Seviye)</h3>
              <div className="space-y-2 max-h-80 overflow-y-auto">
                {Array.from({ length: 20 }, (_, i) => i + 1).map((level) => {
                  const weights = useFacilityStore.getState().getRarityWeightsAtLevel(level);
                  const total = Object.values(weights).reduce((s, v) => s + v, 0);
                  const rarities: Array<{ name: string; key: keyof typeof weights; emoji: string }> = [
                    { name: 'COMMON', key: 'common', emoji: '⚪' },
                    { name: 'UNCOMMON', key: 'uncommon', emoji: '🟢' },
                    { name: 'RARE', key: 'rare', emoji: '🔵' },
                    { name: 'EPIC', key: 'epic', emoji: '🟣' },
                    { name: 'LEGENDARY', key: 'legendary', emoji: '🟡' },
                  ];
                  
                  return (
                    <div key={level} className={`p-2 rounded-lg text-xs ${level === facility.level ? 'bg-[var(--accent)] bg-opacity-20 border border-[var(--accent)]' : 'bg-[var(--bg-darker)]'}`}>
                      <div className="flex items-center justify-between mb-1">
                        <span className="font-medium text-[var(--text-primary)]">Lv.{level}</span>
                        <span className="text-[10px] text-[var(--text-muted)]">{level === facility.level ? '← Mevcut' : ''}</span>
                      </div>
                      <div className="grid grid-cols-5 gap-1">
                        {rarities.map(({ name, key, emoji }) => {
                          const pct = (weights[key] / total) * 100;
                          const fmt = (key === 'epic' || key === 'legendary') ? pct.toFixed(1) : Math.round(pct).toFixed(0);
                          return (
                            <div key={key} className="text-center">
                              <div className="text-sm">{emoji}</div>
                              <p className="text-[9px] text-[var(--text-muted)]">{fmt}%</p>
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

          {/* Yükselt */}
          <Card>
            <div className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-semibold text-[var(--text-primary)]">⬆️ Yükselt → Lv.{facility.level + 1}</h3>
                  <p className="text-xs text-[var(--text-muted)]">Maliyet: 🪙 {formatGold(upgradeCost)}</p>
                </div>
                <Button variant="gold" size="sm" disabled={!canUpgrade || inPrison} onClick={() => setUpgradeConfirm(true)}>
                  Yükselt
                </Button>
              </div>
            </div>
          </Card>
        </>
      )}

      {/* Recipes removed: facilities don't use recipes anymore */}

      {/* Queue tab — Godot DetailModal._populate_queue_tab() gibi 4-case logic */}
      {activeTab === 'queue' && (
        <>
          {/* 1. STATUS HEADER — Godot'taki match{active, expired, stopped} */}
          <Card className="p-4 rounded-lg border">
            <div className="flex items-center justify-between mb-2">
              {productionTargetDate && Date.now() < Date.parse(productionTargetDate) ? (
                <>
                  <span className="text-sm font-medium text-[var(--color-success)]">🟢 Üretim Sürüyor</span>
                  <span className="text-xs text-[var(--text-muted)]">
                    ⏱️ <CountdownInline targetDate={productionTargetDate} />
                  </span>
                </>
              ) : productionTargetDate && Date.now() >= Date.parse(productionTargetDate) && liveResources.length > 0 ? (
                <>
                  <span className="text-sm font-medium text-[var(--color-warning)]">🟡 Süre Doldu! (Yeniden Başlat)</span>
                </>
              ) : (
                <>
                  <span className="text-sm font-medium text-[var(--text-secondary)]">🔴 Üretim Durdu</span>
                </>
              )}
            </div>
          </Card>

          {/* 2. RESOURCES DISPLAY HEADER */}
          <div className="text-sm font-semibold text-[var(--text-primary)] my-3">
            📦 Toplam Kaynak: {liveResources.reduce((sum, r) => sum + r.quantity, 0)}
          </div>

          {/* Live Resources Cards */}
          {liveResources.length > 0 && (
            <div className="grid grid-cols-2 gap-2 mb-4">
              {liveResources.map((r) => {
                const rarityEmoji: Record<string, string> = {
                  common: "⚪",
                  uncommon: "🟢",
                  rare: "🔵",
                  epic: "🟣",
                  legendary: "🟡",
                };
                const rarityColor: Record<string, string> = {
                  common: "text-[var(--text-muted)]",
                  uncommon: "text-[var(--color-success)]",
                  rare: "text-[var(--color-info)]",
                  epic: "text-[var(--color-warning)]",
                  legendary: "text-[var(--color-error)]",
                };
                return (
                  <div
                    key={`${r.item_id}-${r.rarity}`}
                    className="p-3 rounded-lg bg-[var(--bg-darker)] border border-[var(--border-subtle)]"
                  >
                    <div className="flex items-center gap-2 mb-1">
                      <span className={`text-sm ${rarityColor[r.rarity.toLowerCase()] || ""}`}>
                        {rarityEmoji[r.rarity.toLowerCase()] || "⚪"}
                      </span>
                      <span className="text-xs font-medium text-[var(--text-primary)]">{r.item_id}</span>
                    </div>
                    <div className="text-[10px] text-[var(--text-muted)]">×{r.quantity}</div>
                  </div>
                );
              })}
            </div>
          )}

          {/* No resources yet during active production */}
          {liveResources.length === 0 && productionStartedAt && productionTargetDate && Date.now() < Date.parse(productionTargetDate) && (
            <div className="text-center text-xs text-[var(--text-muted)] my-4 py-6">
              🔨 İşçiler çalışıyor...
            </div>
          )}

          {/* Empty depot when no production */}
          {liveResources.length === 0 && !productionStartedAt && (
            <div className="text-center text-xs text-[var(--text-muted)] my-4 py-6">
              Depo boş. Üretimi başlatın.
            </div>
          )}

          {/* Spacing */}
          <div className="my-4" />

          {/* 3. ACTION BUTTONS — Godot'taki 4 cases */}

          {/* CASE A: Resources exist AND duration elapsed -> Can Collect */}
          {liveResources.length > 0 && productionTargetDate && Date.now() >= Date.parse(productionTargetDate) && (
            <>
              <Button
                variant="primary"
                fullWidth
                size="lg"
                disabled={inPrison}
                onClick={() => handleCollect(facility.id)}
              >
                ✅ Kaynakları Topla ({liveResources.reduce((sum, r) => sum + r.quantity, 0)})
              </Button>
              <p className="text-xs text-[var(--text-muted)] text-center mt-2">
                (Yeni üretime başlamak için depoyu boşaltın)
              </p>
            </>
          )}

          {/* CASE B: Resources exist BUT duration NOT elapsed -> Disabled Collect (show timer) */}
          {liveResources.length > 0 && productionTargetDate && Date.now() < Date.parse(productionTargetDate) && (
            <>
              <Button variant="secondary" fullWidth size="lg" disabled>
                ⏳ Bekleyin: <CountdownInline targetDate={productionTargetDate} />
              </Button>
              <p className="text-xs text-[var(--text-muted)] text-center mt-2">
                (Kaynakları toplamak için süresi dolmasını bekleyin)
              </p>
            </>
          )}

          {/* CASE C: Active production but no resources yet - nothing to show (handled above) */}

          {/* CASE D: Stopped/Expired & Empty -> Can Start Production */}
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
              <p className="text-xs text-[var(--text-muted)] text-center mt-2">
                Maliyet: 50 Enerji (Mevcut: {energy || 0})
              </p>
              {energy < 50 && (
                <p className="text-xs text-[var(--color-error)] text-center mt-1">
                  ❌ Yetersiz enerji
                </p>
              )}
            </>
          )}
        </>
      )}

      {/* Upgrade Confirm Modal */}
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

