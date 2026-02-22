// ============================================================
// Enhancement (Anvil) Page — Kaynak: AnvilScreen.gd + BlacksmithScreen.gd
// Item güçlendirme: seçim, rün yuvası, başarı şansı, maliyet, animasyon
// ============================================================

"use client";

import { useState, useMemo, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useEnhancement } from "@/hooks/useEnhancement";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import type { InventoryItem } from "@/types/inventory";

// Upgrade rates matching AnvilScreen.gd
const UPGRADE_RATES = [1.0, 1.0, 1.0, 1.0, 0.7, 0.6, 0.5, 0.35, 0.2, 0.1, 0.03];
const UPGRADE_COSTS = [1000, 2000, 5000, 10000, 25000, 50000, 100000, 250000, 1000000, 5000000, 10000000];

export default function EnhancementPage() {
  const items = useInventoryStore((s) => s.items);
  const gold = usePlayerStore((s) => s.gold);
  const addToast = useUiStore((s) => s.addToast);
  const { enhanceItem, isEnhancing } = useEnhancement();

  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);
  const [result, setResult] = useState<{ success: boolean; message: string } | null>(null);

  // Only equipment can be enhanced
  const enhanceableItems = useMemo(() =>
    items.filter((i) => ["weapon", "armor", "helmet", "gloves", "boots", "accessory"].includes(i.item_type ?? "") && (i.enhancement_level ?? 0) < 10),
    [items]
  );

  const scrolls = useMemo(() =>
    items.filter((i) => i.item_type === "scroll" || i.item_id?.includes("scroll")),
    [items]
  );

  const currentLevel = selectedItem?.enhancement_level ?? 0;
  const successRate = UPGRADE_RATES[currentLevel] ?? 0;
  const cost = UPGRADE_COSTS[currentLevel] ?? 0;
  const hasDestructionRisk = currentLevel >= 8;
  const hasLevelDropRisk = currentLevel >= 7;

  const handleEnhance = useCallback(async () => {
    if (!selectedItem) return;
    if (gold < cost) {
      addToast("Yetersiz altın!", "error");
      return;
    }
    const r = await enhanceItem(selectedItem as any, scrolls[0] ? "none" : "none");
    if (r) {
      setResult({ success: r.success, message: r.success ? `+${r.newLevel} başarılı!` : r.destroyed ? "Eşya yok edildi!" : `Seviye ${r.newLevel}'a düştü` });
      if (r.success) {
        setSelectedItem(null);
      }
    }
  }, [selectedItem, gold, cost, scrolls, enhanceItem, addToast]);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🔥 Güçlendirme (Örs)</h1>

      {/* Selected Item Panel */}
      <Card variant="elevated">
        <div className="p-4 text-center">
          {selectedItem ? (
            <>
              <p className="text-3xl mb-2">⚔️</p>
              <h3 className="font-bold text-[var(--text-primary)]">{selectedItem.name}</h3>
              <p className="text-[var(--accent)] font-bold text-lg">+{currentLevel}</p>
              <div className="mt-3 space-y-2">
                <div className="flex justify-between text-xs">
                  <span className="text-[var(--text-muted)]">Başarı Şansı</span>
                  <span className={successRate >= 0.5 ? "text-green-400" : successRate >= 0.2 ? "text-yellow-400" : "text-red-400"}>
                    %{Math.round(successRate * 100)}
                  </span>
                </div>
                <ProgressBar value={successRate * 100} max={100}
                  color={successRate >= 0.5 ? "success" : successRate >= 0.2 ? "warning" : "health"} size="sm" />
                <div className="flex justify-between text-xs">
                  <span className="text-[var(--text-muted)]">Maliyet</span>
                  <span className="text-[var(--color-gold)]">🪙 {cost.toLocaleString("tr-TR")}</span>
                </div>
                {hasLevelDropRisk && (
                  <p className="text-[10px] text-yellow-400">⚠️ Başarısızlıkta seviye düşebilir</p>
                )}
                {hasDestructionRisk && (
                  <p className="text-[10px] text-red-400">💀 Başarısızlıkta eşya yok olabilir!</p>
                )}
              </div>
              <div className="flex gap-2 mt-4">
                <Button variant="secondary" size="sm" fullWidth onClick={() => setSelectedItem(null)}>
                  İptal
                </Button>
                <Button variant="primary" size="sm" fullWidth onClick={handleEnhance}
                  disabled={isEnhancing || gold < cost}>
                  {isEnhancing ? "⚒️ Dövülüyor..." : "⚒️ Güçlendir"}
                </Button>
              </div>
            </>
          ) : (
            <>
              <p className="text-4xl mb-2">⚒️</p>
              <p className="text-sm text-[var(--text-muted)]">Güçlendirmek için bir eşya seçin</p>
            </>
          )}
        </div>
      </Card>

      {/* Rune Slots */}
      {selectedItem && (
        <Card>
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">🔮 Rün Yuvaları</h3>
            <div className="grid grid-cols-3 gap-2">
              {[0, 1, 2].map((i) => (
                <div key={i} className="aspect-square bg-[var(--bg-input)] border border-dashed border-[var(--border-default)] rounded-lg flex items-center justify-center text-[var(--text-muted)] text-xs">
                  {scrolls[i] ? `📜 ${scrolls[i].name}` : "Boş"}
                </div>
              ))}
            </div>
            <p className="text-[10px] text-[var(--text-muted)] mt-2">
              Rün scroll&#39;ları başarı şansını artırır
            </p>
          </div>
        </Card>
      )}

      {/* Result */}
      <AnimatePresence>
        {result && (
          <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }}>
            <Card>
              <div className={`p-4 text-center ${result.success ? "text-green-400" : "text-red-400"}`}>
                <p className="text-3xl mb-2">{result.success ? "✨" : "💔"}</p>
                <p className="font-bold">{result.message}</p>
                <Button variant="secondary" size="sm" className="mt-3" onClick={() => setResult(null)}>
                  Tamam
                </Button>
              </div>
            </Card>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Item Selection */}
      <div>
        <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">Eşya Seçin</h3>
        {enhanceableItems.length === 0 ? (
          <p className="text-center text-sm text-[var(--text-muted)] py-4">Güçlendirilebilir eşya bulunamadı</p>
        ) : (
          <div className="space-y-2">
            {enhanceableItems.map((item) => (
              <button
                key={item.row_id || item.item_id}
                onClick={() => { setSelectedItem(item); setResult(null); }}
                className={`w-full text-left p-3 rounded-xl border transition-colors ${
                  selectedItem?.row_id === item.row_id
                    ? "border-[var(--accent)] bg-[var(--accent)]/10"
                    : "border-[var(--border-default)] bg-[var(--card-bg)]"
                }`}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-[var(--text-primary)]">{item.name}</p>
                    <p className="text-[10px] text-[var(--text-muted)]">{item.item_type} • {item.rarity}</p>
                  </div>
                  <span className="text-[var(--accent)] font-bold">+{item.enhancement_level ?? 0}</span>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>
    </motion.div>
  );
}
