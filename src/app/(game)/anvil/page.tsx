// ============================================================
// Anvil Page — Kaynak: AnvilScreen.gd
// Ekipman güçlendirme +0→+10, rün yuvaları, risk seviyeleri,
// başarı oranı, maliyet, animasyonlu sonuç paneli
// ============================================================

"use client";

import { useEffect, useState, useMemo, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { formatGold } from "@/lib/utils/string";
import type { InventoryItem } from "@/types/inventory";

// ── Constants from AnvilScreen.gd ───────────────────────────

const UPGRADE_CHANCES: Record<number, number> = {
  0: 100, 1: 100, 2: 100, 3: 100,
  4: 70,  5: 60,  6: 50,  7: 35,
  8: 20,  9: 10,  10: 3,
};

const UPGRADE_COSTS: Record<number, number> = {
  0: 1000,     1: 2000,     2: 3000,
  3: 5000,     4: 15000,    5: 35000,
  6: 75000,    7: 150000,   8: 500000,
  9: 2000000,  10: 10000000,
};

// Rune bonus per slot — Godot: each rune adds +5%
const RUNE_SUCCESS_BONUS = 5; // percent per rune slot

// Max rune slots — Godot: 3 rune slots
const MAX_RUNE_SLOTS = 3; // used for runeSlots array initialization

// Max enhancement level
const MAX_ENHANCEMENT_LEVEL = 10;

// ── Types ───────────────────────────────────────────────────

type UpgradeOutcome = "success" | "failure" | "destroyed" | "drop";

interface UpgradeResult {
  outcome: UpgradeOutcome;
  newLevel: number;
  message: string;
}

// ── Risk text helpers ────────────────────────────────────────

function getRiskLabel(level: number): { text: string; color: string } {
  if (level >= 8) {
    return { text: "⚠️ YOK OLMA RİSKİ", color: "var(--color-error)" };
  }
  if (level >= 7) {
    return { text: "⚠️ Seviye düşebilir", color: "var(--color-warning)" };
  }
  if (level >= 4) {
    return { text: "Seviye düşmez", color: "var(--color-warning)" };
  }
  return { text: "Risksiz", color: "var(--color-success)" };
}

function getSuccessColor(rate: number): string {
  if (rate >= 70) return "var(--color-success)";
  if (rate >= 35) return "var(--color-warning)";
  return "var(--color-error)";
}

function getProgressBarColor(rate: number): "success" | "warning" | "health" {
  if (rate >= 70) return "success";
  if (rate >= 35) return "warning";
  return "health";
}

// ── Enhancement level badge ──────────────────────────────────

function EnhancementBadge({ level }: { level: number }) {
  const color =
    level === 0
      ? "var(--text-muted)"
      : level < 4
      ? "var(--color-success)"
      : level < 7
      ? "var(--color-warning)"
      : level < 9
      ? "var(--color-error)"
      : "var(--rarity-legendary)";

  return (
    <span
      className="text-sm font-bold tabular-nums"
      style={{ color }}
    >
      +{level}
    </span>
  );
}

// ── Item selection panel ─────────────────────────────────────

function ItemSelectPanel({
  items,
  selected,
  onSelect,
}: {
  items: InventoryItem[];
  selected: InventoryItem | null;
  onSelect: (item: InventoryItem) => void;
}) {
  const [search, setSearch] = useState("");

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return items.filter((i) =>
      !q || i.name.toLowerCase().includes(q) || i.item_id.toLowerCase().includes(q)
    );
  }, [items, search]);

  return (
    <div className="space-y-2">
      <input
        type="text"
        placeholder="🔍 Eşya ara…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="w-full px-3 py-2 rounded-lg text-sm bg-[var(--bg-input)] text-[var(--text-primary)] border border-[var(--border-default)] focus:outline-none focus:border-[var(--accent)]"
      />
      {filtered.length === 0 ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-4">
          Güçlendirilebilir eşya bulunamadı.
        </p>
      ) : (
        <div className="space-y-1.5 max-h-52 overflow-y-auto pr-1">
          {filtered.map((item) => {
            const level = item.enhancement_level ?? 0;
            const isSelected = selected?.row_id === item.row_id;
            const maxed = level >= MAX_ENHANCEMENT_LEVEL;

            return (
              <button
                key={item.row_id}
                onClick={() => !maxed && onSelect(item)}
                disabled={maxed}
                className={[
                  "w-full text-left px-3 py-2 rounded-lg border transition-all text-sm",
                  isSelected
                    ? "border-[var(--accent)] bg-[var(--accent)]/10"
                    : "border-[var(--border-default)] bg-[var(--bg-elevated)] hover:border-[var(--accent)]/50",
                  maxed ? "opacity-40 cursor-not-allowed" : "cursor-pointer",
                ].join(" ")}
              >
                <div className="flex items-center justify-between">
                  <div className="min-w-0">
                    <p className="font-medium text-[var(--text-primary)] truncate">
                      {item.icon} {item.name}
                    </p>
                    <p className="text-[10px] text-[var(--text-muted)] capitalize">
                      {item.item_type} • {item.rarity}
                      {item.is_equipped && (
                        <span className="ml-1 text-[var(--color-success)]">[Kuşanılmış]</span>
                      )}
                    </p>
                  </div>
                  <div className="ml-2 shrink-0">
                    <EnhancementBadge level={level} />
                    {maxed && (
                      <span className="ml-1 text-[10px] text-[var(--text-muted)]">MAX</span>
                    )}
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ── Rune slot ────────────────────────────────────────────────

function RuneSlot({
  index,
  rune,
  onAdd,
  onRemove,
}: {
  index: number;
  rune: InventoryItem | null;
  onAdd: () => void;
  onRemove: () => void;
}) {
  return (
    <button
      onClick={rune ? onRemove : onAdd}
      className={[
        "flex flex-col items-center justify-center w-full h-16 rounded-lg border-2 border-dashed transition-all text-xs gap-1",
        rune
          ? "border-[var(--accent)] bg-[var(--accent)]/10 text-[var(--accent-light)]"
          : "border-[var(--border-default)] text-[var(--text-muted)] hover:border-[var(--accent)]/50",
      ].join(" ")}
    >
      {rune ? (
        <>
          <span className="text-lg">{rune.icon || "💎"}</span>
          <span className="truncate w-full text-center px-1">{rune.name}</span>
          <span className="text-[10px] text-[var(--color-error)]">Kaldır</span>
        </>
      ) : (
        <>
          <span className="text-xl">+</span>
          <span>Rün {index + 1}</span>
        </>
      )}
    </button>
  );
}

// ── Animated outcome panel ───────────────────────────────────

function OutcomePanel({
  upgradeResult,
  item,
  onClose,
}: {
  upgradeResult: UpgradeResult;
  item: InventoryItem;
  onClose: () => void;
}) {
  const emoji =
    upgradeResult.outcome === "success"
      ? "✨"
      : upgradeResult.outcome === "destroyed"
      ? "💥"
      : upgradeResult.outcome === "drop"
      ? "📉"
      : "😞";

  const titleColor =
    upgradeResult.outcome === "success"
      ? "var(--color-success)"
      : upgradeResult.outcome === "destroyed"
      ? "var(--color-error)"
      : upgradeResult.outcome === "drop"
      ? "var(--color-warning)"
      : "var(--text-secondary)";

  const titleText =
    upgradeResult.outcome === "success"
      ? "BAŞARILI!"
      : upgradeResult.outcome === "destroyed"
      ? "EŞYA YOK OLDU!"
      : upgradeResult.outcome === "drop"
      ? "SEVİYE DÜŞTÜ"
      : "BAŞARISIZ";

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.8 }}
      transition={{ type: "spring", stiffness: 280, damping: 22 }}
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
    >
      <div className="w-full max-w-sm">
        <Card variant="elevated">
          <div className="p-6 text-center space-y-4">
            <motion.div
              initial={{ scale: 0, rotate: -180 }}
              animate={{ scale: 1, rotate: 0 }}
              transition={{ type: "spring", delay: 0.1, stiffness: 260, damping: 18 }}
              className="text-6xl"
            >
              {emoji}
            </motion.div>

            <h2 className="text-2xl font-bold" style={{ color: titleColor }}>
              {titleText}
            </h2>

            {upgradeResult.outcome !== "destroyed" ? (
              <div className="space-y-1">
                <p className="text-sm text-[var(--text-secondary)]">{item.name}</p>
                <p className="text-3xl font-bold text-[var(--text-primary)]">
                  <EnhancementBadge level={upgradeResult.newLevel} />
                </p>
              </div>
            ) : (
              <p className="text-sm text-[var(--color-error)]">
                {item.name} tamamen yok edildi!
              </p>
            )}

            <p className="text-xs text-[var(--text-muted)]">{upgradeResult.message}</p>

            <Button variant="primary" size="md" fullWidth onClick={onClose}>
              Tamam
            </Button>
          </div>
        </Card>
      </div>
    </motion.div>
  );
}

// ── Main Anvil Page ──────────────────────────────────────────

export default function AnvilPage() {
  const gold = usePlayerStore((s) => s.gold);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);
  const items = useInventoryStore((s) => s.items);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);

  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);
  const [runeSlots, setRuneSlots] = useState<(InventoryItem | null)[]>(
    Array.from({ length: MAX_RUNE_SLOTS }, () => null)
  );
  const [isUpgrading, setIsUpgrading] = useState(false);
  const [upgradeResult, setUpgradeResult] = useState<UpgradeResult | null>(null);
  const [showItemSelect, setShowItemSelect] = useState(false);
  const [runePickSlot, setRunePickSlot] = useState<number | null>(null);

  // Fetch inventory on mount
  useEffect(() => {
    fetchInventory().catch(() => {});
  }, [fetchInventory]);

  // Enhanceable items — equipment, not maxed out
  const enhanceableItems = useMemo(() =>
    items.filter((i) =>
      ["weapon", "armor", "helmet", "gloves", "boots", "accessory", "shield"].includes(
        i.item_type ?? ""
      ) && (i.enhancement_level ?? 0) <= MAX_ENHANCEMENT_LEVEL
    ),
    [items]
  );

  // Rune items — item_type === "rune" or contains "rune" in item_id
  const runeItems = useMemo(() =>
    items.filter(
      (i) =>
        i.item_type === "rune" ||
        (i.item_id ?? "").toLowerCase().includes("rune") ||
        (i.name ?? "").toLowerCase().includes("rün")
    ),
    [items]
  );

  // Current upgrade stats
  const currentLevel = selectedItem?.enhancement_level ?? 0;
  const baseSuccessRate = UPGRADE_CHANCES[currentLevel] ?? 0;
  const runeCount = runeSlots.filter(Boolean).length;
  const totalSuccessRate = Math.min(100, baseSuccessRate + runeCount * RUNE_SUCCESS_BONUS);
  const upgradeCost = UPGRADE_COSTS[currentLevel] ?? 0;
  const risk = getRiskLabel(currentLevel);
  const canAfford = gold >= upgradeCost;
  const atMax = currentLevel >= MAX_ENHANCEMENT_LEVEL;

  // ── Rune slot management ────────────────────────────────────

  const handleRuneAdd = useCallback((slotIndex: number) => {
    setRunePickSlot(slotIndex);
  }, []);

  const handleRuneRemove = useCallback((slotIndex: number) => {
    setRuneSlots((prev) => {
      const next = [...prev];
      next[slotIndex] = null;
      return next;
    });
  }, []);

  const handleRunePick = useCallback(
    (rune: InventoryItem) => {
      if (runePickSlot === null) return;
      // Prevent same rune in two slots
      if (runeSlots.some((r) => r?.row_id === rune.row_id)) {
        addToast("Bu rün zaten kullanılıyor", "warning");
        return;
      }
      setRuneSlots((prev) => {
        const next = [...prev];
        next[runePickSlot] = rune;
        return next;
      });
      setRunePickSlot(null);
    },
    [runePickSlot, runeSlots, addToast]
  );

  // ── Upgrade ─────────────────────────────────────────────────

  const handleUpgrade = useCallback(async () => {
    if (!selectedItem) return;
    if (!canAfford) {
      addToast("Yetersiz altın!", "error");
      return;
    }
    if (atMax) {
      addToast("Bu eşya zaten maksimum seviyede!", "warning");
      return;
    }

    setIsUpgrading(true);

    const runeIds = runeSlots
      .filter((r): r is InventoryItem => r !== null)
      .map((r) => r.row_id);

    try {
      const res = await api.rpc<{
        success: boolean;
        destroyed?: boolean;
        new_level?: number;
        gold_spent?: number;
        error?: string;
      }>("anvil_upgrade", {
        item_row_id: selectedItem.row_id,
        rune_ids: runeIds,
      });

      if (!res.success) {
        throw new Error(res.error ?? "Güçlendirme başarısız");
      }

      const d = res.data;
      const goldSpent = d?.gold_spent ?? upgradeCost;
      updateGold(-goldSpent, true);

      let outcome: UpgradeOutcome;
      let newLevel: number;
      let message: string;

      if (d?.destroyed) {
        outcome = "destroyed";
        newLevel = 0;
        message = "Eşya güçlendirme sırasında yok edildi.";
        // Remove item from local store after destroy
        setSelectedItem(null);
        setRuneSlots([null, null, null]);
      } else if (d?.success) {
        newLevel = d.new_level ?? currentLevel + 1;
        outcome = "success";
        message = `${selectedItem.name} başarıyla +${newLevel} oldu!`;
        // Update local item level
        setSelectedItem((prev) =>
          prev ? { ...prev, enhancement_level: newLevel } : null
        );
      } else {
        // Failure — may drop level
        if (currentLevel >= 7) {
          newLevel = Math.max(0, currentLevel - 1);
          outcome = "drop";
          message = `Başarısız! Seviye ${currentLevel}'den ${newLevel}'e düştü.`;
          setSelectedItem((prev) =>
            prev ? { ...prev, enhancement_level: newLevel } : null
          );
        } else {
          newLevel = currentLevel;
          outcome = "failure";
          message = "Güçlendirme başarısız oldu. Seviye korundu.";
        }
      }

      setUpgradeResult({ outcome, newLevel, message });
      // Clear runes after use
      setRuneSlots([null, null, null]);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Güçlendirme sırasında hata oluştu";
      addToast(msg, "error");
    } finally {
      setIsUpgrading(false);
    }
  }, [
    selectedItem,
    canAfford,
    atMax,
    runeSlots,
    upgradeCost,
    currentLevel,
    updateGold,
    addToast,
  ]);

  const handleResultClose = useCallback(() => {
    setUpgradeResult(null);
    // Refresh inventory to sync server state
    fetchInventory().catch(() => {});
  }, [fetchInventory]);

  // ── Render ──────────────────────────────────────────────────

  return (
    <div className="p-4 space-y-4 pb-24">
      {/* Title */}
      <div className="flex items-center gap-3">
        <h2 className="text-lg font-bold text-[var(--text-primary)]">
          🔨 Örs — Ekipman Güçlendirme
        </h2>
      </div>

      {/* Gold display */}
      <Card>
        <div className="p-3 flex items-center justify-between text-sm">
          <span className="text-[var(--text-secondary)]">💰 Altın</span>
          <span className="text-[var(--color-gold)] font-semibold">
            {formatGold(gold)}
          </span>
        </div>
      </Card>

      {/* Item selection */}
      <Card variant="elevated">
        <div className="p-4 space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-[var(--text-primary)]">
              ⚔️ Güçlendirilecek Eşya
            </h3>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setShowItemSelect(!showItemSelect)}
            >
              {showItemSelect ? "Gizle" : "Seç"}
            </Button>
          </div>

          {/* Currently selected item */}
          {selectedItem ? (
            <div className="flex items-center gap-3 px-3 py-2 rounded-lg bg-[var(--bg-elevated)] border border-[var(--accent)]/40">
              <span className="text-2xl">{selectedItem.icon || "🗡️"}</span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-[var(--text-primary)] truncate">
                  {selectedItem.name}
                </p>
                <p className="text-xs text-[var(--text-muted)] capitalize">
                  {selectedItem.item_type} • {selectedItem.rarity}
                </p>
              </div>
              <div className="text-right">
                <EnhancementBadge level={currentLevel} />
                {currentLevel < MAX_ENHANCEMENT_LEVEL && (
                  <p className="text-[10px] text-[var(--text-muted)] mt-0.5">
                    → +{currentLevel + 1}
                  </p>
                )}
              </div>
            </div>
          ) : (
            <div
              className="border-2 border-dashed border-[var(--border-default)] rounded-lg p-4 text-center text-sm text-[var(--text-muted)] cursor-pointer hover:border-[var(--accent)]/50 transition-colors"
              onClick={() => setShowItemSelect(true)}
            >
              Eşya seçmek için tıkla
            </div>
          )}

          {/* Item list dropdown */}
          <AnimatePresence>
            {showItemSelect && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: "auto" }}
                exit={{ opacity: 0, height: 0 }}
                className="overflow-hidden"
              >
                <ItemSelectPanel
                  items={enhanceableItems}
                  selected={selectedItem}
                  onSelect={(item) => {
                    setSelectedItem(item);
                    setShowItemSelect(false);
                    setRuneSlots([null, null, null]);
                  }}
                />
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </Card>

      {/* Rune slots */}
      {selectedItem && (
        <Card variant="elevated">
          <div className="p-4 space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-bold text-[var(--text-primary)]">
                💎 Rün Yuvaları
              </h3>
              <span className="text-xs text-[var(--text-muted)]">
                Her rün +{RUNE_SUCCESS_BONUS}% başarı
              </span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {runeSlots.map((rune, i) => (
                <RuneSlot
                  key={i}
                  index={i}
                  rune={rune}
                  onAdd={() => handleRuneAdd(i)}
                  onRemove={() => handleRuneRemove(i)}
                />
              ))}
            </div>

            {/* Rune picker inline */}
            <AnimatePresence>
              {runePickSlot !== null && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  className="overflow-hidden border-t border-[var(--border-default)] pt-3"
                >
                  <p className="text-xs text-[var(--text-secondary)] mb-2">
                    Rün seç (Slot {runePickSlot + 1}):
                  </p>
                  {runeItems.length === 0 ? (
                    <p className="text-xs text-[var(--text-muted)] text-center py-3">
                      Envanterinde rün bulunmuyor.
                    </p>
                  ) : (
                    <div className="space-y-1 max-h-36 overflow-y-auto">
                      {runeItems.map((rune) => {
                        const alreadyUsed = runeSlots.some(
                          (r) => r?.row_id === rune.row_id
                        );
                        return (
                          <button
                            key={rune.row_id}
                            onClick={() => !alreadyUsed && handleRunePick(rune)}
                            disabled={alreadyUsed}
                            className={[
                              "w-full text-left px-3 py-1.5 rounded-lg text-xs flex items-center gap-2 transition-all",
                              alreadyUsed
                                ? "opacity-40 cursor-not-allowed bg-[var(--bg-elevated)]"
                                : "bg-[var(--bg-elevated)] hover:bg-[var(--accent)]/10 cursor-pointer",
                            ].join(" ")}
                          >
                            <span>{rune.icon || "💎"}</span>
                            <span className="text-[var(--text-primary)]">
                              {rune.name}
                            </span>
                            {alreadyUsed && (
                              <span className="ml-auto text-[var(--text-muted)]">
                                Kullanılıyor
                              </span>
                            )}
                          </button>
                        );
                      })}
                    </div>
                  )}
                  <Button
                    variant="ghost"
                    size="sm"
                    className="mt-2"
                    onClick={() => setRunePickSlot(null)}
                  >
                    İptal
                  </Button>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </Card>
      )}

      {/* Stats panel */}
      {selectedItem && (
        <Card variant="elevated">
          <div className="p-4 space-y-4">
            <h3 className="text-sm font-bold text-[var(--text-primary)]">
              📊 Güçlendirme Detayları
            </h3>

            {/* Current → Target level */}
            <div className="flex items-center justify-center gap-4">
              <div className="text-center">
                <p className="text-xs text-[var(--text-muted)]">Mevcut</p>
                <p className="text-2xl font-bold text-[var(--text-primary)]">
                  <EnhancementBadge level={currentLevel} />
                </p>
              </div>
              <motion.div
                animate={{ x: [0, 4, 0] }}
                transition={{ duration: 1, repeat: Infinity }}
                className="text-xl text-[var(--text-muted)]"
              >
                →
              </motion.div>
              <div className="text-center">
                <p className="text-xs text-[var(--text-muted)]">Hedef</p>
                <p className="text-2xl font-bold">
                  <EnhancementBadge level={atMax ? currentLevel : currentLevel + 1} />
                </p>
              </div>
            </div>

            {/* Success rate bar */}
            <div className="space-y-1">
              <div className="flex justify-between text-xs">
                <span className="text-[var(--text-secondary)]">Başarı Oranı</span>
                <span
                  className="font-bold"
                  style={{ color: getSuccessColor(totalSuccessRate) }}
                >
                  %{totalSuccessRate}
                  {runeCount > 0 && (
                    <span className="text-[var(--text-muted)] font-normal ml-1">
                      (Baz: %{baseSuccessRate} + Rün: +%{runeCount * RUNE_SUCCESS_BONUS})
                    </span>
                  )}
                </span>
              </div>
              <ProgressBar
                value={totalSuccessRate / 100}
                color={getProgressBarColor(totalSuccessRate)}
                size="md"
              />
            </div>

            {/* Cost */}
            <div className="flex items-center justify-between text-sm">
              <span className="text-[var(--text-secondary)]">💰 Maliyet</span>
              <span
                className="font-semibold"
                style={{
                  color: canAfford
                    ? "var(--color-gold)"
                    : "var(--color-error)",
                }}
              >
                {formatGold(upgradeCost)}
                {!canAfford && (
                  <span className="ml-1 text-xs text-[var(--color-error)]">
                    (Yetersiz)
                  </span>
                )}
              </span>
            </div>

            {/* Risk */}
            <div className="flex items-center justify-between text-sm">
              <span className="text-[var(--text-secondary)]">⚠️ Risk</span>
              <span className="font-semibold" style={{ color: risk.color }}>
                {risk.text}
              </span>
            </div>

            {/* Risk explanation */}
            {currentLevel >= 7 && (
              <div
                className={[
                  "rounded-lg px-3 py-2 text-xs",
                  currentLevel >= 8
                    ? "bg-red-500/10 text-[var(--color-error)]"
                    : "bg-yellow-500/10 text-[var(--color-warning)]",
                ].join(" ")}
              >
                {currentLevel >= 8
                  ? "⚠️ Başarısız olursan eşyan tamamen yok olabilir!"
                  : "⚠️ Başarısız olursan eşyanın seviyesi bir düşebilir."}
              </div>
            )}
          </div>
        </Card>
      )}

      {/* Upgrade button */}
      {selectedItem && (
        <Button
          variant={canAfford && !atMax ? "primary" : "secondary"}
          size="lg"
          fullWidth
          isLoading={isUpgrading}
          disabled={!canAfford || atMax || isUpgrading}
          onClick={handleUpgrade}
        >
          {atMax
            ? "✅ Maksimum Seviye"
            : !canAfford
            ? `❌ Yetersiz Altın (${formatGold(upgradeCost)} gerekli)`
            : `🔨 Güçlendir +${currentLevel} → +${currentLevel + 1}`}
        </Button>
      )}

      {/* Empty state */}
      {!selectedItem && !showItemSelect && (
        <Card>
          <div className="p-8 text-center space-y-3">
            <p className="text-4xl">🔨</p>
            <p className="text-sm text-[var(--text-secondary)]">
              Güçlendirmek istediğin eşyayı seç.
            </p>
            <p className="text-xs text-[var(--text-muted)]">
              +4 ve üzeri seviyelerde risk artar.
            </p>
            <Button
              variant="primary"
              size="sm"
              onClick={() => setShowItemSelect(true)}
            >
              Eşya Seç
            </Button>
          </div>
        </Card>
      )}

      {/* Upgrade chance table */}
      <Card variant="bordered">
        <div className="p-4 space-y-2">
          <h3 className="text-xs font-bold text-[var(--text-secondary)] mb-3">
            📋 Güçlendirme Tablosu
          </h3>
          <div className="grid grid-cols-4 gap-1 text-[10px] text-[var(--text-muted)]">
            <span className="font-semibold text-[var(--text-secondary)]">Sev</span>
            <span className="font-semibold text-[var(--text-secondary)]">Şans</span>
            <span className="font-semibold text-[var(--text-secondary)]">Maliyet</span>
            <span className="font-semibold text-[var(--text-secondary)]">Risk</span>
            {Array.from({ length: 11 }, (_, i) => {
              const r = getRiskLabel(i);
              const isCurrentLevel = i === currentLevel;
              return (
                <>
                  <span
                    key={`lv-${i}`}
                    className={isCurrentLevel ? "text-[var(--accent)] font-bold" : ""}
                  >
                    +{i}
                  </span>
                  <span
                    key={`ch-${i}`}
                    style={{ color: getSuccessColor(UPGRADE_CHANCES[i]) }}
                  >
                    %{UPGRADE_CHANCES[i]}
                  </span>
                  <span key={`co-${i}`}>
                    {formatGold(UPGRADE_COSTS[i])}
                  </span>
                  <span key={`ri-${i}`} style={{ color: r.color }} className="truncate">
                    {r.text.replace("⚠️ ", "")}
                  </span>
                </>
              );
            })}
          </div>
        </div>
      </Card>

      {/* Result overlay */}
      <AnimatePresence>
        {upgradeResult && selectedItem && (
          <OutcomePanel
            upgradeResult={upgradeResult}
            item={selectedItem}
            onClose={handleResultClose}
          />
        )}
        {upgradeResult && !selectedItem && (
          // Destroyed case — item no longer exists
          <OutcomePanel
            upgradeResult={upgradeResult}
            item={{ name: "Eşya", icon: "💥" } as InventoryItem}
            onClose={handleResultClose}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
