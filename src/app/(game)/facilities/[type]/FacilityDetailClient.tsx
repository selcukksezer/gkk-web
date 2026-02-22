// ============================================================
// Facility Detail Client Component — Kaynak: FacilitiesScreen.gd detail modal
// Üretim, kuyruk, şüphe, upgrade
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
  const addToast = useUiStore((s) => s.addToast);

  const [upgradeConfirm, setUpgradeConfirm] = useState(false);
  const [selectedResource, setSelectedResource] = useState(0);

  const facility = useMemo(
    () => facilities.find((f) => f.facility_type === facilityType),
    [facilities, facilityType]
  );

  const facilityRecipes = useMemo(
    () => recipes[facilityType] || [],
    [recipes, facilityType]
  );

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
  const suspicion = facility.suspicion || 0;

  const handleStartProduction = async () => {
    const resource = config.resources[selectedResource] || config.resources[0];
    if (!resource) return;
    await startProduction(facility.id);
    addToast("Üretim başlatıldı!", "success");
  };

  const handleCollect = async (queueItemId: string) => {
    await collectProduction(facility.id);
    addToast("Üretim toplandı!", "success");
  };

  const handleUpgrade = async () => {
    await upgradeFacility(facilityType);
    addToast(`${config.name} yükseltildi! Lv.${facility.level + 1}`, "success");
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
          <h2 className="text-lg font-bold text-[var(--text-primary)]">
            {config.name}
          </h2>
          <p className="text-xs text-[var(--text-muted)]">
            Seviye {facility.level} • {config.description}
          </p>
        </div>
      </div>

      {/* Suspension */}
      <Card>
        <div className="p-3">
          <div className="flex items-center justify-between mb-1">
            <span className="text-xs text-[var(--text-secondary)]">🕵️ Şüphe</span>
            <span
              className="text-xs font-bold"
              style={{
                color:
                  suspicion >= 80
                    ? "var(--color-error)"
                    : suspicion >= 50
                    ? "var(--color-warning)"
                    : "var(--color-success)",
              }}
            >
              %{suspicion}
            </span>
          </div>
          <ProgressBar
            value={suspicion}
            max={100}
            color={suspicion >= 80 ? "health" : suspicion >= 50 ? "warning" : "success"}
            size="sm"
          />
        </div>
      </Card>

      {/* Rarity Rates — Level-based distribution */}
      {facility && facilityRecipes.length > 0 && (
        <Card variant="elevated">
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">
              ✨ Nadirlik Oranları (Lv. {facility.level})
            </h3>
            <div className="grid grid-cols-5 gap-2">
              {facilityRecipes.length > 0 && facilityRecipes[0].rarity_distribution ? (
                Object.entries(facilityRecipes[0].rarity_distribution).map(
                  ([rarity, percent]: [string, any]) => {
                    const rarityColors: Record<string, string> = {
                      COMMON: "text-[var(--text-muted)]",
                      UNCOMMON: "text-[var(--color-success)]",
                      RARE: "text-[var(--color-info)]",
                      EPIC: "text-[var(--color-warning)]",
                      LEGENDARY: "text-[var(--color-error)]",
                    };
                    const rarityEmoji: Record<string, string> = {
                      COMMON: "⚪",
                      UNCOMMON: "🟢",
                      RARE: "🔵",
                      EPIC: "🟣",
                      LEGENDARY: "🟡",
                    };
                    return (
                      <div key={rarity} className="text-center">
                        <div className={`text-lg ${rarityColors[rarity] || ""}`}>
                          {rarityEmoji[rarity]}
                        </div>
                        <p className={`text-[10px] font-medium ${rarityColors[rarity] || ""}`}>
                          {rarity}
                        </p>
                        <p className="text-[10px] text-[var(--text-muted)]">
                          {Number(percent).toFixed(1)}%
                        </p>
                      </div>
                    );
                  }
                )
              ) : (
                <p className="text-xs text-[var(--text-muted)]">Veri yükleniyorum...</p>
              )}
            </div>
          </div>
        </Card>
      )}

      {/* Resources */}
      <Card variant="elevated">
        <div className="p-4">
          <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-2">
            📦 Üretilebilir Kaynaklar
          </h3>
          <div className="grid grid-cols-2 gap-2">
            {config.resources.map((r, idx) => (
              <button
                key={r}
                className={`text-xs rounded-lg p-2 text-left transition-colors ${
                  selectedResource === idx
                    ? "bg-[var(--accent)] bg-opacity-20 border border-[var(--accent)]"
                    : "bg-[var(--bg-darker)]"
                }`}
                onClick={() => setSelectedResource(idx)}
              >
                <p className="font-medium text-[var(--text-primary)]">{r}</p>
              </button>
            ))}
          </div>
        </div>
      </Card>

      {/* Start Production */}
      <Button
        variant="primary"
        fullWidth
        isLoading={isLoading}
        onClick={handleStartProduction}
      >
        ▶️ Üretim Başlat
      </Button>

      {/* Recipes — Available at current level */}
      {facilityRecipes.length > 0 && (
        <Card>
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">
              📜 Mevcut Tarifler ({facilityRecipes.length})
            </h3>
            <div className="space-y-2 max-h-64 overflow-y-auto">
              {facilityRecipes.map((recipe) => (
                <div
                  key={recipe.id}
                  className="p-2 rounded-lg bg-[var(--bg-darker)] text-xs"
                >
                  <div className="flex items-start justify-between mb-1">
                    <span className="font-medium text-[var(--text-primary)]">
                      {recipe.output_item_id}
                    </span>
                    <span className="text-[var(--color-success)]">
                      ×{recipe.output_quantity}
                    </span>
                  </div>
                  <div className="grid grid-cols-2 gap-2 text-[10px] text-[var(--text-muted)]">
                    <div>⏱️ {recipe.duration_seconds}s</div>
                    <div>
                      {recipe.gold_cost > 0 ? `💰 ${recipe.gold_cost}` : ""}
                    </div>
                    <div>
                      Lv. {recipe.required_level} {recipe.min_facility_level > 1 ? `+Min.${recipe.min_facility_level}` : ""}
                    </div>
                    <div>✅ {recipe.success_rate}%</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </Card>
      )}

      {/* Production Queue */}
      {productionQueue.length > 0 && (
        <Card>
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-2">
              ⏳ Üretim Kuyruğu ({productionQueue.length})
            </h3>
            <div className="space-y-2">
              {productionQueue.map((item) => (
                <ProductionQueueRow
                  key={item.id}
                  item={item}
                  onCollect={() => handleCollect(item.id)}
                />
              ))}
            </div>
          </div>
        </Card>
      )}

      {/* Upgrade */}
      <Card>
        <div className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-sm font-semibold text-[var(--text-primary)]">
                ⬆️ Yükselt → Lv.{facility.level + 1}
              </h3>
              <p className="text-xs text-[var(--text-muted)]">
                Maliyet: 🪙 {formatGold(upgradeCost)}
              </p>
            </div>
            <Button
              variant="gold"
              size="sm"
              disabled={!canUpgrade}
              onClick={() => setUpgradeConfirm(true)}
            >
              Yükselt
            </Button>
          </div>
        </div>
      </Card>

      {/* Upgrade Confirm Modal */}
      <Modal
        isOpen={upgradeConfirm}
        onClose={() => setUpgradeConfirm(false)}
        title="Yükseltme Onayı"
        size="sm"
      >
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            {config.name} tesisini Lv.{facility.level + 1}&apos;e yükseltmek için{" "}
            <strong>{formatGold(upgradeCost)} altın</strong> harcanacak.
          </p>
          <div className="flex gap-2">
            <Button
              variant="secondary"
              size="sm"
              fullWidth
              onClick={() => setUpgradeConfirm(false)}
            >
              Vazgeç
            </Button>
            <Button
              variant="primary"
              size="sm"
              fullWidth
              isLoading={isLoading}
              onClick={handleUpgrade}
            >
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
          <span className={`text-sm ${rarityColor[item.rarity.toLowerCase()] || ""}`}>
            {rarityEmoji[item.rarity.toLowerCase()] || "⚪"}
          </span>
          <p className="text-xs font-medium text-[var(--text-primary)]">
            {item.recipe_name}
          </p>
          <span className="text-[10px] text-[var(--text-muted)]">×{item.quantity}</span>
        </div>
        <p className="text-[10px] text-[var(--text-muted)]">
          {isComplete ? (
            <span className="text-[var(--color-success)]">✅ Hazır!</span>
          ) : (
            `⏱️ ${formatted}`
          )}
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
