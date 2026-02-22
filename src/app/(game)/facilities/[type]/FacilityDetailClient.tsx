// ============================================================
// Facility Detail Client Component — Kaynak: FacilitiesScreen.gd detail modal
// Üretim, kuyruk, tarifler, upgrade (tabs)
// ============================================================

"use client";

import { useEffect, useState, useMemo } from "react";
import { useRouter } from "next/navigation";
import { useFacilityStore } from "@/stores/facilityStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useCountdown } from "@/hooks/useCountdown";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { Modal } from "@/components/ui/Modal";
import { FACILITIES_CONFIG } from "@/data/FacilityConfig";
import { formatGold } from "@/lib/utils/string";
import { PRODUCTION_DURATION_SECONDS } from "@/stores/facilityStore";
import type { FacilityType, ProductionQueueItem, FacilityRecipe } from "@/types/facility";

export default function FacilityDetailClient({ type }: { type: string }) {
  const router = useRouter();
  const facilityType = type as FacilityType;
  const config = FACILITIES_CONFIG[facilityType];

  const facilities = useFacilityStore((s) => s.facilities);
  const recipes = useFacilityStore((s) => s.recipes);
  const fetchRecipes = useFacilityStore((s) => s.fetchRecipes);
  const startProduction = useFacilityStore((s) => s.startProduction);
  const collectProduction = useFacilityStore((s) => s.collectProduction);
  const upgradeFacility = useFacilityStore((s) => s.upgradeFacility);
  const fetchFacilities = useFacilityStore((s) => s.fetchFacilities);
  const isLoading = useFacilityStore((s) => s.isLoading);
  const gold = usePlayerStore((s) => s.gold);
  const inPrison = usePlayerStore((s) => s.inPrison);
  const addToast = useUiStore((s) => s.addToast);

  const [upgradeConfirm, setUpgradeConfirm] = useState(false);
  const [activeTab, setActiveTab] = useState<"overview" | "recipes" | "queue">("overview");

  const facility = useMemo(
    () => facilities.find((f) => f.facility_type === facilityType),
    [facilities, facilityType]
  );

  const facilityRecipes = useMemo(() => recipes[facilityType] || [], [recipes, facilityType]);

  useEffect(() => {
    fetchFacilities();
    fetchRecipes(facilityType);
  }, [fetchFacilities, fetchRecipes, facilityType]);

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
  // Compute live/estimated produced resources when production has started but queue is empty
  const liveResources = useMemo(() => {
    if (!productionStartedAt) return [] as Array<{ item_id: string; rarity: string; quantity: number }>;
    // Estimate total possible produced count during the duration based on base_rate (per hour)
    const baseRate = config.base_rate || 1; // per hour
    const totalPossible = Math.max(1, Math.round(baseRate * (PRODUCTION_DURATION_SECONDS / 3600)));
    // Compute produced so far based on elapsed time
    const startedTs = Date.parse(productionStartedAt);
    const now = Date.now();
    const elapsedMs = Math.max(0, Math.min(now - startedTs, PRODUCTION_DURATION_SECONDS * 1000));
    const producedSoFar = Math.floor((elapsedMs / (PRODUCTION_DURATION_SECONDS * 1000)) * totalPossible);
    const items = useFacilityStore.getState().calculateIdleResources(facilityType, facility.level, productionStartedAt, Math.max(1, producedSoFar));
    // Aggregate counts by item_id and rarity
    const agg: Record<string, { item_id: string; rarity: string; quantity: number }> = {};
    for (const it of items) {
      const key = `${it.item_id}::${it.rarity}`;
      if (!agg[key]) agg[key] = { item_id: it.item_id, rarity: it.rarity, quantity: 0 };
      agg[key].quantity += 1;
    }
    return Object.values(agg);
  }, [productionStartedAt, facilityType, facility.level, config.base_rate]);

  // Poll facility data briefly while production is active so UI updates when complete
  useEffect(() => {
    if (!productionStartedAt) return;
    const startedTs = Date.parse(productionStartedAt);
    const durationMs = PRODUCTION_DURATION_SECONDS * 1000;
    let stopped = false;

    const tick = async () => {
      const now = Date.now();
      const elapsed = now - startedTs;
      // If production finished on server, refetch and stop polling
      if (elapsed >= durationMs) {
        await fetchFacilities();
        stopped = true;
        return;
      }
      // otherwise refresh lightweightly to update UI
      await fetchFacilities();
    };

    const id = setInterval(() => { if (!stopped) tick(); }, 2000);
    // initial tick
    tick();
    return () => clearInterval(id);
  }, [productionStartedAt, fetchFacilities]);
  const globalSuspicion = useFacilityStore((s) => s.getGlobalSuspicionRisk());
  const gems = usePlayerStore((s) => s.gems);
  const payBail = usePlayerStore((s) => s.payBail);

  const handleStartProduction = async () => {
    if (inPrison) {
      addToast("Cezaevindeyken üretim başlatılamaz", "warning");
      return;
    }
    console.log("[FacilityDetail] Starting production, facility:", facility, "recipes:", facilityRecipes);
    // If recipes exist, start the first available recipe by default
    if (facilityRecipes && facilityRecipes.length > 0) {
      const first = facilityRecipes[0];
      console.log("[FacilityDetail] Using first recipe:", first);
      const ok = await startProduction(facility.id, first.id, 1);
      if (ok) addToast("Üretim başlatıldı!", "success");
      else addToast(useFacilityStore.getState().error || "Üretim başlatılamadı", "error");
      return;
    }
    console.log("[FacilityDetail] No recipes, starting without recipe ID");
    const ok = await startProduction(facility.id);
    if (ok) addToast("Üretim başlatıldı!", "success");
    else addToast(useFacilityStore.getState().error || "Üretim başlatılamadı", "error");
  };

  const handleCollect = async (queueItemId: string) => {
    if (inPrison) {
      addToast("Cezaevindeyken toplama yapılamaz", "warning");
      return;
    }
    await collectProduction(facility.id);
    addToast("Üretim toplandı!", "success");
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

        {/* Global suspicion header + bribe */}
        <Card>
          <div className="p-3 space-y-3">
            <div>
              <div className="flex items-center justify-between mb-2">
                <div className="text-sm text-[var(--text-muted)]">🌍 Genel Şüphe</div>
                <div className="text-xs text-[var(--text-muted)]">{globalSuspicion}%</div>
              </div>
              <ProgressBar value={Math.min(100, Math.max(0, globalSuspicion))} />
            </div>

            <div className="flex gap-2 pt-2">
              <Button
                size="sm"
                variant="gold"
                fullWidth
                disabled={inPrison || gems < 5 || globalSuspicion <= 0}
                onClick={async () => {
                  if (inPrison) { addToast('Cezaevindeyken rüşvet verilemez','warning'); return; }
                  // Bribe using any unlocked facility type (server requires a type)
                  const unlocked = useFacilityStore.getState().facilities.find((f) => !!f);
                  const typeToBribe = unlocked?.facility_type || Object.keys(FACILITIES_CONFIG)[0];
                  const ok = await useFacilityStore.getState().bribeOfficials(typeToBribe as any, 5);
                  if (ok) {
                    addToast('Rüşvet verildi', 'success');
                  } else {
                    addToast('Rüşvet başarısız', 'error');
                  }
                }}
              >
                💎 5 Rüşvet Ver
              </Button>
              {inPrison && (
                <Button size="sm" variant="secondary" fullWidth onClick={async () => {
                  const res = await payBail();
                  if (res.success) addToast(`Kefalet ödendi (${res.gems_spent || 0} 💎)`, 'success');
                  else addToast(res.error || 'Kefalet başarısız', 'error');
                }}>💎 Kefaleti Öde</Button>
              )}
            </div>
          </div>
        </Card>

      {/* Tabs header (Godot modal uses tabs) */}
      <div className="flex gap-2">
        <button
          className={`px-3 py-1 rounded ${activeTab === 'overview' ? 'bg-[var(--accent)] text-white' : 'bg-[var(--bg-darker)]'}`}
          onClick={() => setActiveTab('overview')}
        >
          Genel
        </button>
        <button
          className={`px-3 py-1 rounded ${activeTab === 'recipes' ? 'bg-[var(--accent)] text-white' : 'bg-[var(--bg-darker)]'}`}
          onClick={() => setActiveTab('recipes')}
        >
          Tarifler
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

          <Button variant="primary" fullWidth isLoading={isLoading} onClick={handleStartProduction}>
            ▶️ Üretim Başlat ({facility.level > 0 ? 'Lv.' + facility.level : '?'})
          </Button>

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

      {/* Recipes tab: rarity + recipe list */}
      {activeTab === 'recipes' && (
        <>
          {facility && facilityRecipes.length > 0 && (
            <Card variant="elevated">
              <div className="p-4">
                <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">✨ Nadirlik Oranları (Lv. {facility.level})</h3>
                <div className="grid grid-cols-5 gap-2">
                  {facilityRecipes.length > 0 && facilityRecipes[0].rarity_distribution ? (
                    Object.entries(facilityRecipes[0].rarity_distribution).map(([rarity, percent]: [string, any]) => {
                      const rarityColors: Record<string, string> = {
                        COMMON: "text-[var(--text-muted)]",
                        UNCOMMON: "text-[var(--color-success)]",
                        RARE: "text-[var(--color-info)]",
                        EPIC: "text-[var(--color-warning)]",
                        LEGENDARY: "text-[var(--color-error)]",
                      };
                      const rarityEmoji: Record<string, string> = { COMMON: "⚪", UNCOMMON: "🟢", RARE: "🔵", EPIC: "🟣", LEGENDARY: "🟡" };
                      const upper = rarity.toUpperCase();
                      const formatted = (upper === 'EPIC' || upper === 'LEGENDARY') ? Number(percent).toFixed(1) : Number(percent).toFixed(0);
                      return (
                        <div key={rarity} className="text-center">
                          <div className={`text-lg ${rarityColors[rarity] || ""}`}>{rarityEmoji[rarity]}</div>
                          <p className={`text-[10px] font-medium ${rarityColors[rarity] || ""}`}>{rarity}</p>
                          <p className="text-[10px] text-[var(--text-muted)]">{formatted}%</p>
                        </div>
                      );
                    })
                  ) : (
                    <p className="text-xs text-[var(--text-muted)]">Veri yükleniyorum...</p>
                  )}
                </div>
              </div>
            </Card>
          )}

          {/* Fallback rarity display when recipes are missing: compute from store weights */}
          {facilityRecipes.length === 0 && (
            <Card variant="elevated">
              <div className="p-4">
                <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">✨ Nadirlik Oranları (Lv. {facility.level})</h3>
                <div className="grid grid-cols-5 gap-2">
                  {(() => {
                    const weights = (useFacilityStore.getState()).getRarityWeightsAtLevel(facility.level);
                    const total = Object.values(weights).reduce((s, v) => s + v, 0);
                    const order: Array<[string, number]> = [
                      ["COMMON", weights.common],
                      ["UNCOMMON", weights.uncommon],
                      ["RARE", weights.rare],
                      ["EPIC", weights.epic],
                      ["LEGENDARY", weights.legendary],
                    ];
                    return order.map(([k, v]) => {
                      const pct = (v / total) * 100;
                      const formatted = (k === 'EPIC' || k === 'LEGENDARY') ? pct.toFixed(1) : Math.round(pct).toFixed(0);
                      return (
                        <div key={k} className="text-center">
                          <div className={`text-lg`}>{k === 'COMMON' ? '⚪' : k === 'UNCOMMON' ? '🟢' : k === 'RARE' ? '🔵' : k === 'EPIC' ? '🟣' : '🟡'}</div>
                          <p className="text-[10px] font-medium">{k}</p>
                          <p className="text-[10px] text-[var(--text-muted)]">{formatted}%</p>
                        </div>
                      );
                    });
                  })()}
                </div>
              </div>
            </Card>
          )}

          {facilityRecipes.length > 0 && (
            <Card>
              <div className="p-4">
                <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">📜 Mevcut Tarifler ({facilityRecipes.length})</h3>
                <div className="space-y-2 max-h-64 overflow-y-auto">
                  {facilityRecipes.map((recipe) => (
                    <div key={recipe.id} className="p-2 rounded-lg bg-[var(--bg-darker)] text-xs">
                      <div className="flex items-start justify-between mb-1">
                        <div>
                          <span className="font-medium text-[var(--text-primary)]">{recipe.output_item_id}</span>
                          <div className="text-[10px] text-[var(--text-muted)]">Lv. {recipe.required_level} {recipe.min_facility_level > 1 ? `• MinLv.${recipe.min_facility_level}` : ''}</div>
                        </div>
                        <div className="text-right">
                          <div className="text-[var(--color-success)]">×{recipe.output_quantity}</div>
                          <div className="mt-2">
                            <Button size="sm" variant="primary" disabled={inPrison || isLoading} onClick={async () => {
                              // start this specific recipe
                              const ok = await startProduction(facility.id, recipe.id, 1);
                              if (ok) addToast('Üretim başlatıldı', 'success');
                              else addToast('Üretim başlatılamadı', 'error');
                            }}>
                              ▶ Başlat
                            </Button>
                          </div>
                        </div>
                      </div>
                      <div className="grid grid-cols-2 gap-2 text-[10px] text-[var(--text-muted)]">
                        <div>⏱️ {recipe.duration_seconds}s</div>
                        <div>{recipe.gold_cost > 0 ? `💰 ${recipe.gold_cost}` : ""}</div>
                        <div>{recipe.production_speed_bonus ? `⏩ Speed+${recipe.production_speed_bonus}` : ''}</div>
                        <div>✅ {recipe.success_rate}%</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </Card>
          )}
        </>
      )}

      {/* Queue tab — Always show (Godot behavior: status + items or start button) */}
      {activeTab === 'queue' && (
        <>
          {/* Status Header */}
          <Card className="bg-gradient-to-r from-[var(--bg-darker)] to-[var(--bg-card)]">
            <div className="p-3">
              {((productionQueue.length > 0 && !productionQueue.every((q) => q.is_completed)) || (!!productionStartedAt && productionQueue.length === 0)) ? (
                // Active production
                <div>
                  <p className="text-xs text-[var(--text-muted)] mb-1">🟢 Üretim Sürüyor</p>
                  <p className="text-lg font-semibold text-[var(--color-success)]">{productionQueue.length > 0 ? `Kuyruk: ${productionQueue.length} item` : 'İşçiler çalışıyor...'}</p>
                  {productionTargetDate && (
                    <div className="mt-2 text-[12px] text-[var(--text-muted)]">
                      ⏱️ Süre: <CountdownInline targetDate={productionTargetDate} />
                    </div>
                  )}
                </div>
              ) : (productionQueue.length > 0 && productionQueue.some((q) => q.is_completed)) ? (
                // Ready to collect
                <div>
                  <p className="text-xs text-[var(--text-muted)] mb-1">🟡 Toplama Hazır</p>
                  <p className="text-lg font-semibold text-[var(--color-warning)]">{productionQueue.filter((q) => q.is_completed).length} kaynak hazır</p>
                </div>
              ) : (
                // Stopped
                <div>
                  <p className="text-xs text-[var(--text-muted)] mb-1">🔴 Üretim Durdu</p>
                  <p className="text-lg font-semibold text-[var(--text-secondary)]">Depo boş</p>
                </div>
              )}
            </div>
          </Card>

          {/* Queue Items */}
          {productionQueue.length > 0 && (
            <Card>
              <div className="p-4">
                <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">⏳ Üretim Kuyruğu ({productionQueue.length})</h3>
                <div className="space-y-2">
                  {productionQueue.map((item) => (
                    <ProductionQueueRow key={item.id} item={item} onCollect={() => handleCollect(item.id)} />
                  ))}
                </div>
              </div>
            </Card>
          )}

          {/* Start Production Button (shown when queue is empty) */}
          {productionQueue.length === 0 && (
            <div className="space-y-2">
              <Button
                variant="primary"
                fullWidth
                isLoading={isLoading}
                disabled={inPrison}
                onClick={handleStartProduction}
              >
                ⚡ Üretimi Başlat
              </Button>
              <p className="text-xs text-[var(--text-muted)] text-center">
                Enerji harcı: 50
              </p>
            </div>
          )}

          {/* Live resources preview when production started but queue empty */}
          {!!productionStartedAt && productionQueue.length === 0 && (
            <Card>
              <div className="p-4">
                <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">📦 Üretim Önizlemesi</h3>
                {liveResources.length === 0 ? (
                  <p className="text-xs text-[var(--text-muted)]">Kaynak hesaplanıyor...</p>
                ) : (
                  <div className="grid grid-cols-2 gap-2">
                    {liveResources.map((r) => (
                      <div key={`${r.item_id}-${r.rarity}`} className="p-2 rounded-lg bg-[var(--bg-darker)] text-xs">
                        <div className="font-medium text-[var(--text-primary)]">{r.item_id}</div>
                        <div className="text-[10px] text-[var(--text-muted)]">{r.quantity} × {r.rarity}</div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </Card>
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
// Production Queue Row — Countdown + Collect
// ============================================================

function CountdownInline({ targetDate }: { targetDate: string }) {
  const { formatted, isComplete } = useCountdown({ targetDate });
  return <span>{isComplete ? <span className="text-[var(--color-success)]">✅</span> : formatted}</span>;
}

function ProductionQueueRow({
  item,
  onCollect,
}: {
  item: ProductionQueueItem;
  onCollect: () => void;
}) {
  const { formatted, isComplete } = useCountdown({ targetDate: item.completes_at });

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
    <div className="flex items-center justify-between bg-[var(--bg-darker)] rounded-lg p-3">
      <div className="flex-1">
        <div className="flex items-center gap-2 mb-1">
          <span className={`text-sm ${rarityColor[item.rarity.toLowerCase()] || ""}`}>{rarityEmoji[item.rarity.toLowerCase()] || "⚪"}</span>
          <p className="text-xs font-medium text-[var(--text-primary)]">{item.recipe_name}</p>
          <span className="text-[10px] text-[var(--text-muted)]">×{item.quantity}</span>
        </div>
        <p className="text-[10px] text-[var(--text-muted)]">
          {isComplete ? <span className="text-[var(--color-success)]">✅ Hazır!</span> : `⏱️ ${formatted}`}
        </p>
      </div>
      {isComplete && (
        <Button variant="primary" size="sm" onClick={onCollect}>
          Topla
        </Button>
      )}
    </div>
  );
}
