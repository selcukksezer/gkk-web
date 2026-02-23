// ============================================================
// Enhancement Page — Kaynak: BlacksmithScreen.gd
// Parşömen tabanlı item güçlendirme: yuva seçimi, başarı oranı,
// maliyet, 3 saniyelik sonuç animasyonu (başarı/başarısız/yok oldu)
// ============================================================

"use client";

import { useState, useMemo, useCallback, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { api } from "@/lib/api";
import { formatGold } from "@/lib/utils/string";
import type { InventoryItem } from "@/types/inventory";

// BlacksmithScreen.gd — BASE_SUCCESS_RATES per enhancement level
const BASE_SUCCESS_RATES: Record<number, { min: number; max: number }> = {
  0:  { min: 95,  max: 100 },
  1:  { min: 90,  max: 95  },
  2:  { min: 85,  max: 90  },
  3:  { min: 75,  max: 85  },
  4:  { min: 60,  max: 75  },
  5:  { min: 45,  max: 60  },
  6:  { min: 30,  max: 45  },
  7:  { min: 20,  max: 30  },
  8:  { min: 10,  max: 20  },
  9:  { min: 5,   max: 10  },
  10: { min: 1,   max: 5   },
};

// Rarity → required scroll_id (BlacksmithScreen.gd)
function getScrollId(rarity: string): string {
  if (["common", "uncommon"].includes(rarity)) return "scroll_upgrade_low";
  if (["rare", "epic"].includes(rarity)) return "scroll_upgrade_middle";
  return "scroll_upgrade_high";
}

// Rarity → scroll display label (Türkçe)
function getScrollLabel(rarity: string): string {
  if (["common", "uncommon"].includes(rarity)) return "Düşük Sınıf Parşömen";
  if (["rare", "epic"].includes(rarity)) return "Orta Sınıf Parşömen";
  return "Yüksek Sınıf Parşömen";
}

// Rarity → color
const RARITY_COLORS: Record<string, string> = {
  common:   "var(--text-muted)",
  uncommon: "#4ade80",
  rare:     "#60a5fa",
  epic:     "#c084fc",
  legendary:"#fbbf24",
  mythic:   "#f43f5e",
};

// Enhancement level → gold cost (1000 * (level + 1))
function getEnhanceCost(level: number): number {
  return 1000 * (level + 1);
}

// Item emoji by type
function getItemEmoji(item: InventoryItem): string {
  if (item.icon) return item.icon;
  const map: Record<string, string> = {
    weapon: "⚔️", armor: "🛡️", helmet: "⛑️", gloves: "🧤",
    boots: "👢", accessory: "💍", scroll: "📜", potion: "🧪",
    material: "🪨", consumable: "📦", rune: "🔮", recipe: "📋",
  };
  return map[item.item_type] ?? "📦";
}

type AnimResult = { type: "success"; newLevel: number } | { type: "failure" } | { type: "destroyed" };
type InventoryFilter = "all" | "equipment" | "scroll";

const EQUIPMENT_TYPES = new Set(["weapon", "armor", "helmet", "gloves", "boots", "accessory"]);
const SLOT_COUNT = 20;
const COLS = 5;

export default function EnhancementPage() {
  const items = useInventoryStore((s) => s.items);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);
  const gold = usePlayerStore((s) => s.gold);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);

  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);
  const [selectedScroll, setSelectedScroll] = useState<InventoryItem | null>(null);
  const [isEnhancing, setIsEnhancing] = useState(false);
  const [animResult, setAnimResult] = useState<AnimResult | null>(null);
  const [inventoryFilter, setInventoryFilter] = useState<InventoryFilter>("all");
  const animTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Load inventory on mount if empty
  useEffect(() => {
    if (items.length === 0) fetchInventory();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Clear animation timer on unmount to prevent state updates on unmounted component
  useEffect(() => {
    return () => {
      if (animTimerRef.current) clearTimeout(animTimerRef.current);
    };
  }, []);

  // ── Derived data ──────────────────────────────────────────
  const enhanceableItems = useMemo(
    () => items.filter((i) => EQUIPMENT_TYPES.has(i.item_type) && (i.enhancement_level ?? 0) < 10),
    [items]
  );

  const scrollItems = useMemo(
    () => items.filter((i) => i.item_type === "scroll" || i.item_id?.includes("scroll")),
    [items]
  );

  const currentLevel = selectedItem?.enhancement_level ?? 0;
  const successRange = BASE_SUCCESS_RATES[currentLevel] ?? { min: 1, max: 5 };
  const cost = getEnhanceCost(currentLevel);
  const hasEnoughGold = gold >= cost;

  const requiredScrollId = selectedItem ? getScrollId(selectedItem.rarity) : null;
  const requiredScrollLabel = selectedItem ? getScrollLabel(selectedItem.rarity) : null;

  // Auto-select compatible scroll when item is selected
  useEffect(() => {
    if (!selectedItem) { setSelectedScroll(null); return; }
    const scrollId = getScrollId(selectedItem.rarity);
    const compatible = scrollItems.find((s) => s.item_id === scrollId);
    setSelectedScroll(compatible ?? null);
  }, [selectedItem, scrollItems]);

  const isScrollCompatible = selectedScroll && requiredScrollId && selectedScroll.item_id === requiredScrollId;
  const canEnhance = !!selectedItem && !!isScrollCompatible && hasEnoughGold && !isEnhancing;

  // Output preview item (dimmed, +1 level)
  const previewLevel = currentLevel + 1;

  // Filtered inventory for grid
  const filteredItems = useMemo(() => {
    if (inventoryFilter === "equipment") return enhanceableItems;
    if (inventoryFilter === "scroll") return scrollItems;
    return items;
  }, [inventoryFilter, items, enhanceableItems, scrollItems]);

  // ── Handlers ──────────────────────────────────────────────
  const handleSelectFromGrid = useCallback((item: InventoryItem) => {
    if (EQUIPMENT_TYPES.has(item.item_type)) {
      setSelectedItem(item);
      setAnimResult(null);
    } else if (item.item_type === "scroll" || item.item_id?.includes("scroll")) {
      setSelectedScroll(item);
    }
  }, []);

  const handleCancel = useCallback(() => {
    setSelectedItem(null);
    setSelectedScroll(null);
    setAnimResult(null);
  }, []);

  const handleEnhance = useCallback(async () => {
    if (!selectedItem || !selectedScroll || !canEnhance) return;

    setIsEnhancing(true);
    try {
      const res = await api.rpc<{
        success: boolean;
        destroyed?: boolean;
        new_level?: number;
        gold_spent?: number;
      }>("enhance_item", {
        item_row_id: selectedItem.row_id,
        scroll_row_id: selectedScroll.row_id,
      });

      const data = res.data;
      if (res.success && data) {
        // Deduct gold locally (server-authoritative result)
        updateGold(-cost, true);

        if (data.success) {
          setAnimResult({ type: "success", newLevel: data.new_level ?? currentLevel + 1 });
          addToast(`Güçlendirme başarılı! +${data.new_level ?? previewLevel}`, "success");
        } else if (data.destroyed) {
          setAnimResult({ type: "destroyed" });
          addToast("Eşya güçlendirme sırasında yok oldu!", "error");
        } else {
          setAnimResult({ type: "failure" });
          addToast("Güçlendirme başarısız!", "warning");
        }

        // Refresh inventory from server after enhance
        await fetchInventory();
        // Clear slots after animation
        animTimerRef.current = setTimeout(() => {
          setAnimResult(null);
          setSelectedItem(null);
          setSelectedScroll(null);
        }, 3000);
      } else {
        addToast(res.error ?? "Güçlendirme hatası", "error");
      }
    } catch {
      addToast("Güçlendirme başarısız — sunucu hatası", "error");
    } finally {
      setIsEnhancing(false);
    }
  }, [selectedItem, selectedScroll, canEnhance, cost, currentLevel, previewLevel, updateGold, fetchInventory, addToast]);

  // ── Result Animation Overlay ───────────────────────────────
  const ResultOverlay = () => {
    if (!animResult) return null;
    const isSuccess = animResult.type === "success";
    const isDestroyed = animResult.type === "destroyed";

    return (
      <motion.div
        initial={{ opacity: 0, scale: 0.7 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 1.2 }}
        transition={{ type: "spring", damping: 12 }}
        className="fixed inset-0 z-50 flex items-center justify-center bg-black/70"
      >
        <div className={`text-center px-8 py-10 rounded-3xl border-4 ${
          isSuccess ? "border-green-400 bg-green-900/60 shadow-[0_0_60px_#4ade80]"
          : isDestroyed ? "border-red-500 bg-red-900/60 shadow-[0_0_60px_#ef4444]"
          : "border-orange-400 bg-orange-900/60 shadow-[0_0_60px_#fb923c]"
        }`}>
          <motion.p
            initial={{ scale: 0 }} animate={{ scale: 1 }}
            transition={{ delay: 0.1, type: "spring", damping: 8 }}
            className="text-7xl mb-4"
          >
            {isSuccess ? "✨" : isDestroyed ? "💥" : "💨"}
          </motion.p>
          {isSuccess && animResult.type === "success" && (
            <motion.p
              initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 0.2 }}
              className="text-5xl font-black text-green-300 mb-2"
            >
              +{animResult.newLevel}
            </motion.p>
          )}
          <motion.p
            initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.3 }}
            className={`text-2xl font-bold ${
              isSuccess ? "text-green-300" : isDestroyed ? "text-red-300" : "text-orange-300"
            }`}
          >
            {isSuccess ? "GÜÇLENDIRME BAŞARILI!" : isDestroyed ? "YANARAK YOK OLDU" : "BAŞARISIZ"}
          </motion.p>
          <motion.p
            initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="text-xs text-white/60 mt-4"
          >
            Otomatik kapanıyor...
          </motion.p>
        </div>
      </motion.div>
    );
  };

  return (
    <>
      <AnimatePresence>{animResult && <ResultOverlay />}</AnimatePresence>

      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-28">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h1 className="text-xl font-bold text-[var(--gold)]">🔥 Güçlendirme</h1>
          <span className="text-xs text-[var(--text-muted)] bg-[var(--bg-elevated)] px-3 py-1 rounded-full">
            Demirci Ekranı
          </span>
        </div>

        {/* ── Three Slot Panel ──────────────────────────────── */}
        <Card variant="elevated">
          <div className="p-4">
            <h3 className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider mb-3">
              Güçlendirme Yuvaları
            </h3>
            <div className="flex items-center gap-3">
              {/* Input Slot — item to enhance */}
              <div className="flex-1">
                <p className="text-[10px] text-[var(--text-muted)] mb-1.5 text-center">Eşya</p>
                <button
                  onClick={() => setInventoryFilter("equipment")}
                  className={`w-full aspect-square rounded-xl border-2 border-dashed flex flex-col items-center justify-center gap-1 transition-all ${
                    selectedItem
                      ? "border-[var(--accent)] bg-[var(--accent)]/10"
                      : "border-[var(--border-default)] bg-[var(--bg-input)] hover:border-[var(--accent)]/50"
                  }`}
                >
                  {selectedItem ? (
                    <>
                      <span className="text-2xl">{getItemEmoji(selectedItem)}</span>
                      <span className="text-[9px] text-[var(--text-primary)] font-medium text-center leading-tight px-1 truncate w-full text-center">
                        {selectedItem.name}
                      </span>
                      <span className="text-[10px] font-bold text-[var(--accent)]">
                        +{currentLevel}
                      </span>
                    </>
                  ) : (
                    <>
                      <span className="text-2xl opacity-30">⚔️</span>
                      <span className="text-[9px] text-[var(--text-muted)]">Eşya Seç</span>
                    </>
                  )}
                </button>
              </div>

              {/* Arrow */}
              <div className="flex flex-col items-center gap-1 shrink-0">
                <span className="text-[var(--text-muted)] text-lg">+</span>
              </div>

              {/* Scroll Slot */}
              <div className="flex-1">
                <p className="text-[10px] text-[var(--text-muted)] mb-1.5 text-center">Parşömen</p>
                <button
                  onClick={() => setInventoryFilter("scroll")}
                  className={`w-full aspect-square rounded-xl border-2 border-dashed flex flex-col items-center justify-center gap-1 transition-all ${
                    selectedScroll && isScrollCompatible
                      ? "border-amber-400 bg-amber-400/10"
                      : selectedScroll && !isScrollCompatible
                      ? "border-red-400 bg-red-400/10"
                      : "border-[var(--border-default)] bg-[var(--bg-input)] hover:border-amber-400/50"
                  }`}
                >
                  {selectedScroll ? (
                    <>
                      <span className="text-2xl">📜</span>
                      <span className="text-[9px] text-[var(--text-primary)] font-medium text-center leading-tight px-1 truncate w-full text-center">
                        {selectedScroll.name}
                      </span>
                      {!isScrollCompatible && (
                        <span className="text-[8px] text-red-400">Uyumsuz!</span>
                      )}
                    </>
                  ) : (
                    <>
                      <span className="text-2xl opacity-30">📜</span>
                      <span className="text-[9px] text-[var(--text-muted)]">Parşömen</span>
                    </>
                  )}
                </button>
              </div>

              {/* Arrow */}
              <div className="flex flex-col items-center gap-1 shrink-0">
                <span className="text-[var(--text-muted)] text-lg">→</span>
              </div>

              {/* Output Preview Slot */}
              <div className="flex-1">
                <p className="text-[10px] text-[var(--text-muted)] mb-1.5 text-center">Önizleme</p>
                <div className={`w-full aspect-square rounded-xl border-2 border-dashed flex flex-col items-center justify-center gap-1 transition-all ${
                  selectedItem
                    ? "border-green-500/40 bg-green-500/5 opacity-60"
                    : "border-[var(--border-default)] bg-[var(--bg-input)] opacity-40"
                }`}>
                  {selectedItem ? (
                    <>
                      <span className="text-2xl">{getItemEmoji(selectedItem)}</span>
                      <span className="text-[9px] text-[var(--text-primary)] text-center leading-tight px-1 truncate w-full text-center">
                        {selectedItem.name}
                      </span>
                      <span className="text-[10px] font-bold text-green-400">
                        +{previewLevel}
                      </span>
                    </>
                  ) : (
                    <>
                      <span className="text-2xl opacity-20">✨</span>
                      <span className="text-[9px] text-[var(--text-muted)]">Sonuç</span>
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>
        </Card>

        {/* ── Info Panel ────────────────────────────────────── */}
        <Card>
          <div className="p-4 space-y-2.5">
            <h3 className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider mb-1">
              Güçlendirme Bilgisi
            </h3>

            {/* Required scroll */}
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--text-secondary)]">Gerekli Parşömen</span>
              <span className={`font-medium ${selectedItem ? "text-amber-400" : "text-[var(--text-muted)]"}`}>
                {requiredScrollLabel ?? "— Eşya Seçin —"}
              </span>
            </div>

            {/* Success rate range */}
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--text-secondary)]">Başarı Şansı</span>
              <span className={`font-bold ${
                successRange.min >= 75 ? "text-green-400"
                : successRange.min >= 45 ? "text-yellow-400"
                : successRange.min >= 20 ? "text-orange-400"
                : "text-red-400"
              }`}>
                %{successRange.min} – %{successRange.max}
              </span>
            </div>

            {/* Progress bar for success rate */}
            {selectedItem && (
              <ProgressBar
                value={successRange.min}
                max={100}
                size="sm"
                color={successRange.min >= 75 ? "success" : successRange.min >= 45 ? "warning" : "health"}
              />
            )}

            {/* Cost */}
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--text-secondary)]">Maliyet</span>
              <span className="font-bold text-[var(--color-gold)]">
                🪙 {formatGold(cost)}
              </span>
            </div>

            {/* Gold balance */}
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--text-secondary)]">Altın Bakiyesi</span>
              <span className={`font-bold ${hasEnoughGold ? "text-green-400" : "text-red-400"}`}>
                🪙 {formatGold(gold)}
                {!hasEnoughGold && " ⚠️ Yetersiz!"}
              </span>
            </div>

            {/* Level warnings */}
            {selectedItem && currentLevel >= 7 && (
              <div className="mt-1 px-3 py-2 rounded-lg bg-red-500/10 border border-red-500/30">
                <p className="text-[10px] text-red-400 font-medium">
                  ⚠️ Seviye {currentLevel} üzerinde başarısızlık eşyayı yok edebilir!
                </p>
              </div>
            )}
            {selectedItem && currentLevel >= 5 && currentLevel < 7 && (
              <div className="mt-1 px-3 py-2 rounded-lg bg-orange-500/10 border border-orange-500/30">
                <p className="text-[10px] text-orange-400">
                  ⚠️ Başarısızlık durumunda seviye düşebilir.
                </p>
              </div>
            )}

            {/* Scroll compatibility warning */}
            {selectedScroll && selectedItem && !isScrollCompatible && (
              <div className="mt-1 px-3 py-2 rounded-lg bg-red-500/10 border border-red-500/30">
                <p className="text-[10px] text-red-400">
                  ❌ Bu parşömen seçili eşyayla uyumlu değil.
                  Gereken: <strong>{requiredScrollLabel}</strong>
                </p>
              </div>
            )}
          </div>
        </Card>

        {/* ── Action Buttons ────────────────────────────────── */}
        <div className="flex gap-3">
          <Button
            variant="secondary"
            size="md"
            fullWidth
            onClick={handleCancel}
            disabled={isEnhancing}
          >
            İptal
          </Button>
          <Button
            variant={canEnhance ? "primary" : "secondary"}
            size="md"
            fullWidth
            onClick={handleEnhance}
            disabled={!canEnhance}
            isLoading={isEnhancing}
          >
            {isEnhancing ? "⚒️ Güçlendiriliyor..." : "⚒️ Güçlendir"}
          </Button>
        </div>

        {/* ── Inventory Filter Tabs ─────────────────────────── */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)]">Envanter</h3>
            <div className="flex gap-1.5">
              {(["all", "equipment", "scroll"] as InventoryFilter[]).map((f) => (
                <button
                  key={f}
                  onClick={() => setInventoryFilter(f)}
                  className={`px-2.5 py-1 text-[10px] rounded-lg font-medium transition-colors ${
                    inventoryFilter === f
                      ? "bg-[var(--accent)] text-white"
                      : "bg-[var(--bg-elevated)] text-[var(--text-muted)]"
                  }`}
                >
                  {f === "all" ? "Tümü" : f === "equipment" ? "⚔️ Ekipman" : "📜 Parşömen"}
                </button>
              ))}
            </div>
          </div>

          {/* 20-slot grid, 5 columns */}
          <div className="grid gap-1.5" style={{ gridTemplateColumns: `repeat(${COLS}, 1fr)` }}>
            {Array.from({ length: SLOT_COUNT }).map((_, slotIdx) => {
              const item = filteredItems.find((i) => i.slot_position === slotIdx);
              const isSelectedItem = item && selectedItem?.row_id === item.row_id;
              const isSelectedScroll = item && selectedScroll?.row_id === item.row_id;
              const isEquip = item && EQUIPMENT_TYPES.has(item.item_type);
              const isScroll = item && (item.item_type === "scroll" || item.item_id?.includes("scroll"));
              const rarityColor = item ? RARITY_COLORS[item.rarity] ?? "var(--text-muted)" : undefined;

              return (
                <button
                  key={slotIdx}
                  onClick={() => item && handleSelectFromGrid(item)}
                  className={`aspect-square rounded-lg border flex flex-col items-center justify-center gap-0.5 transition-all relative overflow-hidden ${
                    !item
                      ? "border-[var(--border-default)] bg-[var(--bg-input)] cursor-default opacity-40"
                      : isSelectedItem || isSelectedScroll
                      ? "border-[var(--accent)] bg-[var(--accent)]/20 scale-105 shadow-lg shadow-[var(--accent)]/20"
                      : isEquip
                      ? "border-[var(--border-default)] bg-[var(--bg-elevated)] hover:border-[var(--accent)]/50 cursor-pointer"
                      : isScroll
                      ? "border-amber-400/40 bg-amber-900/20 hover:border-amber-400 cursor-pointer"
                      : "border-[var(--border-default)] bg-[var(--bg-elevated)] cursor-pointer"
                  }`}
                  style={item ? { borderColor: isSelectedItem || isSelectedScroll ? undefined : `${rarityColor}40` } : {}}
                  title={item ? `${item.name} (+${item.enhancement_level ?? 0})` : "Boş"}
                >
                  {item ? (
                    <>
                      <span className="text-base leading-none">{getItemEmoji(item)}</span>
                      {/* Enhancement level badge */}
                      {(item.enhancement_level ?? 0) > 0 && (
                        <span className="text-[8px] font-bold text-[var(--accent)] leading-none">
                          +{item.enhancement_level}
                        </span>
                      )}
                      {/* Quantity badge */}
                      {item.quantity > 1 && (
                        <span className="absolute bottom-0.5 right-0.5 text-[7px] bg-[var(--bg-card)] rounded px-0.5 text-[var(--text-muted)] leading-none">
                          {item.quantity}
                        </span>
                      )}
                      {/* Rarity dot */}
                      <span
                        className="absolute top-0.5 left-0.5 w-1.5 h-1.5 rounded-full"
                        style={{ backgroundColor: rarityColor }}
                      />
                    </>
                  ) : null}
                </button>
              );
            })}
          </div>

          {/* Legend */}
          <div className="flex items-center gap-4 mt-2 px-1">
            {Object.entries(RARITY_COLORS).slice(0, 5).map(([rarity, color]) => (
              <div key={rarity} className="flex items-center gap-1">
                <span className="w-2 h-2 rounded-full" style={{ backgroundColor: color }} />
                <span className="text-[9px] text-[var(--text-muted)] capitalize">{rarity}</span>
              </div>
            ))}
          </div>
        </div>

        {/* ── Enhancement Table ─────────────────────────────── */}
        <Card>
          <div className="p-4">
            <h3 className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider mb-3">
              Başarı Oranı Tablosu
            </h3>
            <div className="space-y-1">
              {Object.entries(BASE_SUCCESS_RATES).map(([lvl, rate]) => {
                const lvlNum = parseInt(lvl);
                const isCurrentLevel = lvlNum === currentLevel && selectedItem;
                return (
                  <div
                    key={lvl}
                    className={`flex items-center gap-2 px-2 py-1.5 rounded-lg text-xs transition-colors ${
                      isCurrentLevel ? "bg-[var(--accent)]/15 border border-[var(--accent)]/30" : ""
                    }`}
                  >
                    <span className={`w-6 text-right font-bold shrink-0 ${isCurrentLevel ? "text-[var(--accent)]" : "text-[var(--text-muted)]"}`}>
                      +{lvl}
                    </span>
                    <div className="flex-1 bg-[var(--bg-input)] rounded-full h-2 overflow-hidden">
                      <div
                        className="h-full rounded-full"
                        style={{
                          width: `${rate.max}%`,
                          background: rate.min >= 75 ? "#4ade80"
                            : rate.min >= 45 ? "#facc15"
                            : rate.min >= 20 ? "#fb923c"
                            : "#ef4444",
                        }}
                      />
                    </div>
                    <span className={`text-right shrink-0 w-20 ${isCurrentLevel ? "text-[var(--accent)] font-semibold" : "text-[var(--text-secondary)]"}`}>
                      %{rate.min}–%{rate.max}
                    </span>
                    <span className="text-right shrink-0 text-[var(--text-muted)] w-16 text-[10px]">
                      🪙{formatGold(getEnhanceCost(lvlNum))}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </Card>
      </motion.div>
    </>
  );
}
