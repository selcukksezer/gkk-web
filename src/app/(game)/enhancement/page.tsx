// ============================================================
// Enhancement Page — Kaynak: BlacksmithScreen.gd
// Parşömen tabanlı item güçlendirme: yuva seçimi, başarı oranı,
// maliyet, 3 saniyelik sonuç animasyonu (başarı/başarısız/yok oldu)
// ============================================================

"use client";

import { useState, useMemo, useCallback, useEffect, useRef, type ReactNode } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  DndContext,
  pointerWithin,
  useDroppable,
  useDraggable,
  type DragEndEvent,
} from "@dnd-kit/core";
import { CSS } from "@dnd-kit/utilities";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { api } from "@/lib/api";
import { useEnhancement } from "@/hooks/useEnhancement";
import { formatGold } from "@/lib/utils/string";
import type { InventoryItem } from "@/types/inventory";
import { ItemIcon } from "@/components/game/ItemIcon";

const UPGRADE_CHANCES: Record<number, number> = {
  0: 100,
  1: 100,
  2: 100,
  3: 100,
  4: 70,
  5: 60,
  6: 50,
  7: 35,
  8: 20,
  9: 10,
  10: 3,
};

const UPGRADE_COSTS: Record<number, number> = {
  0: 1000,
  1: 2000,
  2: 3000,
  3: 5000,
  4: 15000,
  5: 35000,
  6: 75000,
  7: 150000,
  8: 500000,
  9: 2000000,
  10: 10000000,
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

function getEnhanceCost(level: number): number {
  return UPGRADE_COSTS[level] ?? 0;
}

function getRiskLabel(level: number): string {
  // Politikaya göre: +6 ve üzeri -> yok olma riski; +4/+5 -> seviye düşer; diğerleri risksiz
  if (level >= 6) return "YOK OLMA RİSKİ";
  if (level >= 4) return "Seviye düşer";
  return "Risksiz";
}

function isEnhanceableItem(item: InventoryItem): boolean {
  const byType = EQUIPMENT_TYPES.has(item.item_type);
  const byEquipSlot = !!item.equip_slot && item.equip_slot !== "none";
  return (byType || byEquipSlot) && (item.enhancement_level ?? 0) < 10;
}

// Item emoji by type
function getItemEmoji(item: InventoryItem): string {
  // If icon is a small emoji-like string (no path), use it. Otherwise prefer type-based emoji.
  if (item.icon && !item.icon.includes("/") && item.icon.length <= 3) return item.icon;
  const map: Record<string, string> = {
    weapon: "⚔️", armor: "🛡️", helmet: "⛑️", gloves: "🧤",
    boots: "👢", accessory: "💍", scroll: "📜", potion: "🧪",
    material: "🪨", consumable: "📦", rune: "🔮", recipe: "📋",
  };
  return map[item.item_type] ?? "📦";
}

type AnimResult = { type: "success"; newLevel: number } | { type: "failure" } | { type: "destroyed" };

const EQUIPMENT_TYPES = new Set(["weapon", "armor", "helmet", "gloves", "boots", "accessory"]);
const SLOT_COUNT = 20;
const COLS = 5;
const SCROLL_SLOT_COUNT = 9;
const SLOT_SIZE_PX = 88;

function DraggableInventoryItem({
  item,
  disabled,
  children,
}: {
  item: InventoryItem;
  disabled?: boolean;
  children: ReactNode;
}) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: `inv-${item.row_id}`,
    disabled,
  });

  const style = {
    transform: transform ? CSS.Translate.toString(transform) : undefined,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div ref={setNodeRef} style={style} {...attributes} {...listeners}>
      {children}
    </div>
  );
}

function ItemDropSlot({
  selectedItem,
  currentLevel,
  onClick,
}: {
  selectedItem: InventoryItem | null;
  currentLevel: number;
  onClick: () => void;
}) {
  const { isOver, setNodeRef } = useDroppable({ id: "enh-item-slot" });

  return (
    <button
      ref={setNodeRef as never}
      onClick={onClick}
      className={`w-[88px] h-[88px] mx-auto rounded-xl border-2 border-dashed flex flex-col items-center justify-center gap-1 transition-all ${
        selectedItem
          ? "border-[var(--accent)] bg-[var(--accent)]/10"
          : isOver
          ? "border-[var(--accent)] bg-[var(--accent)]/10"
          : "border-[var(--border-default)] bg-[var(--bg-input)] hover:border-[var(--accent)]/50"
      }`}
    >
      {selectedItem ? (
        <>
          <ItemIcon icon={selectedItem.icon} itemType={selectedItem.item_type} itemId={selectedItem.row_id} className="text-2xl" enhancementLevel={selectedItem.enhancement_level} />
          <span className="text-[9px] text-[var(--text-primary)] font-medium text-center leading-tight px-1 truncate w-full text-center">
            {selectedItem.name}
          </span>
          {/* enhancement badge displayed by ItemIcon; remove duplicate text */}
        </>
      ) : (
        <>
          <span className="text-2xl opacity-30">⚔️</span>
          <span className="text-[9px] text-[var(--text-muted)]">Eşya Seç</span>
        </>
      )}
    </button>
  );
}

function ScrollDropSlot({
  index,
  scroll,
  isCompatible,
  onRemove,
}: {
  index: number;
  scroll: InventoryItem | null;
  isCompatible: boolean;
  onRemove: () => void;
}) {
  const { isOver, setNodeRef } = useDroppable({ id: `enh-scroll-slot-${index}` });

  return (
    <button
      ref={setNodeRef as never}
      onClick={scroll ? onRemove : undefined}
      className={`w-[88px] h-[88px] mx-auto rounded-xl border-2 border-dashed flex flex-col items-center justify-center gap-1 transition-all ${
        scroll && isCompatible
          ? "border-amber-400 bg-amber-400/10"
          : scroll && !isCompatible
          ? "border-red-400 bg-red-400/10"
          : isOver
          ? "border-amber-400/70 bg-amber-900/20"
          : "border-[var(--border-default)] bg-[var(--bg-input)]"
      }`}
    >
      {scroll ? (
        <>
          <ItemIcon icon={scroll.icon} itemType={scroll.item_type} itemId={scroll.row_id} className="text-lg" enhancementLevel={scroll.enhancement_level} />
          <span className="text-[9px] text-[var(--text-primary)] font-medium text-center leading-tight px-1 truncate w-full text-center">
            {scroll.name}
          </span>
          {!isCompatible && <span className="text-[8px] text-red-400">Uyumsuz!</span>}
        </>
      ) : (
        <>
          <span className="text-base opacity-40">📜</span>
          <span className="text-[9px] text-[var(--text-muted)]">Slot {index + 1}</span>
        </>
      )}
    </button>
  );
}

export default function EnhancementPage() {
  const items = useInventoryStore((s) => s.items);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);
  const gold = usePlayerStore((s) => s.gold);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);

  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);
  const [selectedScrollSlots, setSelectedScrollSlots] = useState<(InventoryItem | null)[]>(
    Array.from({ length: SCROLL_SLOT_COUNT }, () => null)
  );
  const [isEnhancing, setIsEnhancing] = useState(false);
  const [animResult, setAnimResult] = useState<AnimResult | null>(null);
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
    () => items.filter(isEnhanceableItem),
    [items]
  );

  const scrollItems = useMemo(
    () => items.filter((i) => i.item_type === "scroll" || i.item_id?.includes("scroll")),
    [items]
  );

  const currentLevel = selectedItem?.enhancement_level ?? 0;
  const successChance = UPGRADE_CHANCES[currentLevel] ?? 3;
  const cost = getEnhanceCost(currentLevel);
  const hasEnoughGold = gold >= cost;

  const requiredScrollId = selectedItem ? getScrollId(selectedItem.rarity) : null;
  const requiredScrollLabel = selectedItem ? getScrollLabel(selectedItem.rarity) : null;

  const compatibleScroll = useMemo(() => {
    if (!requiredScrollId) return null;
    return selectedScrollSlots.find((s) => s?.item_id === requiredScrollId) ?? null;
  }, [selectedScrollSlots, requiredScrollId]);

  const canEnhance = !!selectedItem && !!compatibleScroll && hasEnoughGold && !isEnhancing;

  // Output preview item (dimmed, +1 level)
  const previewLevel = currentLevel + 1;

  // ── Handlers ──────────────────────────────────────────────
  const handleSelectFromGrid = useCallback((item: InventoryItem) => {
    if (isEnhanceableItem(item)) {
      setSelectedItem(item);
      setAnimResult(null);
    } else if (item.item_type === "scroll" || item.item_id?.includes("scroll")) {
      setSelectedScrollSlots((prev) => {
        if (prev.some((s) => s?.row_id === item.row_id)) return prev;
        const firstEmpty = prev.findIndex((s) => s === null);
        if (firstEmpty < 0) return prev;
        const next = [...prev];
        next[firstEmpty] = item;
        return next;
      });
    }
  }, []);

  const handleCancel = useCallback(() => {
    setSelectedItem(null);
    setSelectedScrollSlots(Array.from({ length: SCROLL_SLOT_COUNT }, () => null));
    setAnimResult(null);
  }, []);

  const handleDragEnd = useCallback((event: DragEndEvent) => {
    const activeId = String(event.active.id);
    const overId = event.over ? String(event.over.id) : null;
    if (!overId || !activeId.startsWith("inv-")) return;

    const rowId = activeId.replace(/^inv-/, "");
    const dragged = items.find((it) => it.row_id === rowId);
    if (!dragged) return;

    if (overId === "enh-item-slot") {
      if (isEnhanceableItem(dragged)) {
        setSelectedItem(dragged);
        setAnimResult(null);
      }
      return;
    }

    if (overId.startsWith("enh-scroll-slot-")) {
      if (!(dragged.item_type === "scroll" || dragged.item_id?.includes("scroll"))) return;
      const slotIndex = Number.parseInt(overId.replace(/^enh-scroll-slot-/, ""), 10);
      if (Number.isNaN(slotIndex) || slotIndex < 0 || slotIndex >= SCROLL_SLOT_COUNT) return;

      setSelectedScrollSlots((prev) => {
        const sourceIndex = prev.findIndex((s) => s?.row_id === dragged.row_id);
        const next = [...prev];

        if (sourceIndex === slotIndex) return prev;

        if (sourceIndex >= 0) {
          const target = next[slotIndex];
          next[slotIndex] = next[sourceIndex];
          next[sourceIndex] = target;
          return next;
        }

        next[slotIndex] = dragged;
        return next;
      });
    }
  }, [items]);

  const { enhanceItem } = useEnhancement();

  const handleEnhance = useCallback(async () => {
    if (!selectedItem || !canEnhance) return;

    setIsEnhancing(true);
    try {
      // Delegate to centralized enhancement logic (uses inventory RPCs and store)
      const result = await enhanceItem(selectedItem as InventoryItem);

      if (result) {
        if (result.destroyed) {
          setAnimResult({ type: "destroyed" });
        } else if (result.success) {
          setAnimResult({ type: "success", newLevel: result.newLevel });
        } else {
          setAnimResult({ type: "failure" });
        }

        // Refresh inventory from server after enhance
        await fetchInventory();

        // Clear slots after animation
        animTimerRef.current = setTimeout(() => {
          setAnimResult(null);
          setSelectedItem(null);
          setSelectedScrollSlots(Array.from({ length: SCROLL_SLOT_COUNT }, () => null));
        }, 3000);
      } else {
        addToast("Güçlendirme hatası", "error");
      }
    } catch (err) {
      console.error(err);
      addToast("Güçlendirme başarısız — sunucu hatası", "error");
    } finally {
      setIsEnhancing(false);
    }
  }, [selectedItem, canEnhance, enhanceItem, fetchInventory, addToast]);

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

      <DndContext collisionDetection={pointerWithin} onDragEnd={handleDragEnd}>
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
                <ItemDropSlot
                  selectedItem={selectedItem}
                  currentLevel={currentLevel}
                  onClick={() => {}}
                />
              </div>

              {/* Arrow */}
              <div className="flex flex-col items-center gap-1 shrink-0">
                <span className="text-[var(--text-muted)] text-lg">+</span>
              </div>

              {/* Scroll Slots */}
              <div className="flex-[2]">
                <p className="text-[10px] text-[var(--text-muted)] mb-1.5 text-center">Parşömen Slotları (9)</p>
                <div className="grid grid-cols-3 gap-1.5">
                  {selectedScrollSlots.map((scroll, idx) => (
                    <ScrollDropSlot
                      key={idx}
                      index={idx}
                      scroll={scroll}
                      isCompatible={!!(scroll && requiredScrollId && scroll.item_id === requiredScrollId)}
                      onRemove={() => {
                        setSelectedScrollSlots((prev) => {
                          const next = [...prev];
                          next[idx] = null;
                          return next;
                        });
                      }}
                    />
                  ))}
                </div>
              </div>

              {/* Arrow */}
              <div className="flex flex-col items-center gap-1 shrink-0">
                <span className="text-[var(--text-muted)] text-lg">→</span>
              </div>

              {/* Output Preview Slot */}
              <div className="flex-1">
                <p className="text-[10px] text-[var(--text-muted)] mb-1.5 text-center">Önizleme</p>
                <div className={`w-[88px] h-[88px] mx-auto rounded-xl border-2 border-dashed flex flex-col items-center justify-center gap-1 transition-all ${
                  selectedItem
                    ? "border-green-500/40 bg-green-500/5 opacity-60"
                    : "border-[var(--border-default)] bg-[var(--bg-input)] opacity-40"
                }`}>
                  {selectedItem ? (
                    <>
                        <ItemIcon icon={selectedItem.icon} itemType={selectedItem.item_type} itemId={selectedItem.row_id} className="text-2xl" enhancementLevel={previewLevel} />
                        <span className="text-[9px] text-[var(--text-primary)] text-center leading-tight px-1 truncate w-full text-center">
                          {selectedItem.name}
                        </span>
                        {/* enhancement preview shown on ItemIcon badge; duplicate text removed */}
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
                successChance >= 70 ? "text-green-400"
                : successChance >= 35 ? "text-yellow-400"
                : successChance >= 20 ? "text-orange-400"
                : "text-red-400"
              }`}>
                %{successChance}
              </span>
            </div>

            {/* Progress bar for success rate */}
            {selectedItem && (
              <ProgressBar
                value={successChance}
                max={100}
                size="sm"
                color={successChance >= 70 ? "success" : successChance >= 35 ? "warning" : "health"}
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
            {selectedItem && (
              <div className="mt-1 px-3 py-2 rounded-lg bg-[var(--bg-elevated)] border border-[var(--border-default)]">
                <p className="text-[10px] text-[var(--text-secondary)]">
                  ⚠️ Risk: <strong>{getRiskLabel(currentLevel)}</strong>
                </p>
              </div>
            )}

            {/* Scroll compatibility warning */}
            {!compatibleScroll && selectedItem && selectedScrollSlots.some(Boolean) && (
              <div className="mt-1 px-3 py-2 rounded-lg bg-red-500/10 border border-red-500/30">
                <p className="text-[10px] text-red-400">
                  ❌ Slotlardaki parşömenler seçili eşyayla uyumlu değil.
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

        {/* ── Inventory ─────────────────────────────────────── */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)]">Envanter</h3>
            <span className="text-[10px] text-[var(--text-muted)]">Sürükle-bırak aktif</span>
          </div>

          {/* 20-slot grid, 5 columns */}
          <div className="grid gap-1.5 justify-start" style={{ gridTemplateColumns: `repeat(${COLS}, ${SLOT_SIZE_PX}px)` }}>
            {Array.from({ length: SLOT_COUNT }).map((_, slotIdx) => {
              const item = items.find((i) => i.slot_position === slotIdx);
              const isSelectedItem = item && selectedItem?.row_id === item.row_id;
              const isSelectedScroll = item && selectedScrollSlots.some((s) => s?.row_id === item.row_id);
              const isEquip = item && EQUIPMENT_TYPES.has(item.item_type);
              const isScroll = item && (item.item_type === "scroll" || item.item_id?.includes("scroll"));
              const rarityColor = item ? RARITY_COLORS[item.rarity] ?? "var(--text-muted)" : undefined;

              return (
                <div key={slotIdx}>
                  {item ? (
                    <DraggableInventoryItem item={item}>
                      <button
                        onClick={() => handleSelectFromGrid(item)}
                        className={`w-[88px] h-[88px] rounded-lg border flex items-center justify-center transition-all relative overflow-hidden ${
                          isSelectedItem || isSelectedScroll
                            ? "border-[var(--accent)] bg-[var(--accent)]/20 scale-105 shadow-lg shadow-[var(--accent)]/20"
                            : isEquip
                            ? "border-[var(--border-default)] bg-[var(--bg-elevated)] hover:border-[var(--accent)]/50 cursor-pointer"
                            : isScroll
                            ? "border-amber-400/40 bg-amber-900/20 hover:border-amber-400 cursor-pointer"
                            : "border-[var(--border-default)] bg-[var(--bg-elevated)] cursor-pointer"
                        }`}
                        style={{ borderColor: isSelectedItem || isSelectedScroll ? undefined : `${rarityColor}40` }}
                        title={item.enhancement_level > 0 ? `${item.name} (+${item.enhancement_level})` : item.name}
                      >
                        <ItemIcon icon={item.icon} itemType={item.item_type} itemId={item.row_id} className="text-2xl leading-none" enhancementLevel={item.enhancement_level} />
                        {item.quantity > 1 && (
                          <span className="absolute bottom-0.5 right-0.5 text-[7px] bg-[var(--bg-card)] rounded px-0.5 text-[var(--text-muted)] leading-none">
                            {item.quantity}
                          </span>
                        )}
                        <span
                          className="absolute top-0.5 left-0.5 w-1.5 h-1.5 rounded-full"
                          style={{ backgroundColor: rarityColor }}
                        />
                      </button>
                    </DraggableInventoryItem>
                  ) : (
                    <div className="w-[88px] h-[88px] rounded-lg border transition-all relative overflow-hidden border-[var(--border-default)] bg-[var(--bg-input)] cursor-default opacity-40" />
                  )}
                </div>
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
              Güçlendirme Tablosu
            </h3>
            <div className="grid grid-cols-4 gap-1 text-[10px] text-[var(--text-muted)]">
              <span className="font-semibold text-[var(--text-secondary)]">Sev</span>
              <span className="font-semibold text-[var(--text-secondary)]">Şans</span>
              <span className="font-semibold text-[var(--text-secondary)]">Maliyet</span>
              <span className="font-semibold text-[var(--text-secondary)]">Risk</span>
              {Array.from({ length: 11 }, (_, i) => {
                const isCurrent = selectedItem && currentLevel === i;
                return (
                  <div key={`tbl-${i}`} className="contents">
                    <span className={isCurrent ? "text-[var(--accent)] font-bold" : ""}>+{i}</span>
                    <span className={isCurrent ? "text-[var(--accent)] font-bold" : ""}>%{UPGRADE_CHANCES[i]}</span>
                    <span>{formatGold(UPGRADE_COSTS[i])}</span>
                    <span>{getRiskLabel(i)}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </Card>
      </motion.div>
      </DndContext>
    </>
  );
}
