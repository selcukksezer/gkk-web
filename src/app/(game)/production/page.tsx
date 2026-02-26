// ============================================================
// Production Page — Kaynak: ProductionScreen.gd
// Aktif üretim kuyruğu: canlı geri sayım, ilerleme, topla/iptal
// Tabs: Aktif / Tamamlanan / Geçmiş
// ============================================================

"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { ItemIcon } from "@/components/game/ItemIcon";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { useUiStore } from "@/stores/uiStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { api } from "@/lib/api";
import Link from "next/link";

type ProductionTab = "active" | "completed" | "history";

interface QueueItem {
  id: number;
  item_name: string;
  icon: string;
  quantity: number;
  facility: string;
  facility_type: string;
  status: "active" | "completed" | "cancelled" | "failed";
  started_at: string;      // ISO timestamp
  finishes_at: string;     // ISO timestamp
  total_duration: number;  // seconds
}

interface HistoryItem {
  id: number;
  item_name: string;
  icon: string;
  quantity: number;
  facility: string;
  completed_at: string;
  status: "completed" | "cancelled" | "failed";
}

// ── Fallback data (realistic states) ─────────────────────────
const now = Date.now();
const FALLBACK_QUEUE: QueueItem[] = [
  {
    id: 1, item_name: "Demir Kılıç", icon: "⚔️", quantity: 1, facility: "Demirci",
    facility_type: "blacksmith", status: "active",
    started_at: new Date(now - 300_000).toISOString(),
    finishes_at: new Date(now + 600_000).toISOString(),
    total_duration: 900,
  },
  {
    id: 2, item_name: "Can İksiri", icon: "🧪", quantity: 3, facility: "Simyahane",
    facility_type: "alchemy", status: "completed",
    started_at: new Date(now - 900_000).toISOString(),
    finishes_at: new Date(now - 300_000).toISOString(),
    total_duration: 600,
  },
  {
    id: 3, item_name: "Deri Zırh", icon: "🛡️", quantity: 1, facility: "Dericiler",
    facility_type: "leatherwork", status: "active",
    started_at: new Date(now - 120_000).toISOString(),
    finishes_at: new Date(now + 1_080_000).toISOString(),
    total_duration: 1200,
  },
  {
    id: 4, item_name: "Tahta Kalası", icon: "🪵", quantity: 5, facility: "Kereste",
    facility_type: "lumber", status: "completed",
    started_at: new Date(now - 600_000).toISOString(),
    finishes_at: new Date(now - 60_000).toISOString(),
    total_duration: 540,
  },
  {
    id: 5, item_name: "Büyülü Tılsım", icon: "🔮", quantity: 2, facility: "Sihir Atölyesi",
    facility_type: "magic", status: "active",
    started_at: new Date(now - 60_000).toISOString(),
    finishes_at: new Date(now + 2_940_000).toISOString(),
    total_duration: 3000,
  },
];

const FALLBACK_HISTORY: HistoryItem[] = [
  { id: 10, item_name: "Demir Külçesi", icon: "🔩", quantity: 3, facility: "Demirci", completed_at: new Date(now - 3_600_000).toISOString(), status: "completed" },
  { id: 11, item_name: "Deri Şerit", icon: "🎀", quantity: 6, facility: "Dericiler", completed_at: new Date(now - 7_200_000).toISOString(), status: "completed" },
  { id: 12, item_name: "Zehir İksiri", icon: "☠️", quantity: 1, facility: "Simyahane", completed_at: new Date(now - 10_800_000).toISOString(), status: "failed" },
  { id: 13, item_name: "Ok Destesi", icon: "🏹", quantity: 20, facility: "Marangoz", completed_at: new Date(now - 14_400_000).toISOString(), status: "cancelled" },
  { id: 14, item_name: "Mithril Bilezik", icon: "💫", quantity: 1, facility: "Kuyumcu", completed_at: new Date(now - 86_400_000).toISOString(), status: "completed" },
];

// ── Helpers ───────────────────────────────────────────────────
function formatDuration(seconds: number): string {
  if (seconds <= 0) return "0:00";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}s ${String(m).padStart(2, "0")}d ${String(s).padStart(2, "0")}sn`;
  return `${m}d ${String(s).padStart(2, "0")}sn`;
}

function formatRelative(isoDate: string): string {
  const diff = Date.now() - new Date(isoDate).getTime();
  const h = Math.floor(diff / 3_600_000);
  const m = Math.floor((diff % 3_600_000) / 60_000);
  if (h > 0) return `${h} saat önce`;
  if (m > 0) return `${m} dakika önce`;
  return "az önce";
}

function getElapsed(item: QueueItem): number {
  return Math.floor((Date.now() - new Date(item.started_at).getTime()) / 1000);
}

function getRemaining(item: QueueItem): number {
  return Math.max(0, Math.floor((new Date(item.finishes_at).getTime() - Date.now()) / 1000));
}

function getProgress(item: QueueItem): number {
  const elapsed = getElapsed(item);
  return Math.min(1, elapsed / item.total_duration);
}

const facilityEmoji: Record<string, string> = {
  blacksmith: "⚒️", alchemy: "⚗️", leatherwork: "🧵", lumber: "🪵",
  magic: "🔮", jewelry: "💎", cooking: "🍖", farming: "🌾",
};

function getFacilityEmoji(type: string): string {
  return facilityEmoji[type] ?? "🏭";
}

const statusConfig = {
  active:    { label: "Üretiliyor", color: "text-blue-400",   bg: "bg-blue-400/10",   icon: "⚙️" },
  completed: { label: "✅ Hazır",   color: "text-green-400",  bg: "bg-green-400/10",  icon: "✅" },
  cancelled: { label: "İptal",     color: "text-gray-400",   bg: "bg-gray-400/10",   icon: "❌" },
  failed:    { label: "Başarısız", color: "text-red-400",    bg: "bg-red-400/10",    icon: "💀" },
};

// ── Live Countdown Hook ───────────────────────────────────────
function useTick(interval = 1000) {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const t = setInterval(() => setTick((n) => n + 1), interval);
    return () => clearInterval(t);
  }, [interval]);
  return tick;
}

// ── Main Component ────────────────────────────────────────────
export default function ProductionPage() {
  const [activeTab, setActiveTab] = useState<ProductionTab>("active");
  const [queue, setQueue] = useState<QueueItem[]>([]);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [collectingId, setCollectingId] = useState<number | null>(null);
  const [cancellingId, setCancellingId] = useState<number | null>(null);
  const addToast = useUiStore((s) => s.addToast);
  const tick = useTick(1000); // re-render every second for countdown

  // ── Fetch queue ─────────────────────────────────────────────
  const loadQueue = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<{ items: QueueItem[] }>("/rest/v1/rpc/get_production_queue");
      if (res.success && res.data) {
        const data = res.data as unknown as { items?: QueueItem[] } | QueueItem[];
        if (Array.isArray(data)) setQueue(data);
        else if ((data as { items?: QueueItem[] }).items) setQueue((data as { items: QueueItem[] }).items);
        else setQueue(FALLBACK_QUEUE);
      } else {
        setQueue(FALLBACK_QUEUE);
      }
    } catch {
      setQueue(FALLBACK_QUEUE);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const loadHistory = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<HistoryItem[]>("/rest/v1/rpc/get_production_history");
      if (res.success && res.data) {
        const data = res.data as unknown as HistoryItem[];
        if (Array.isArray(data) && data.length > 0) setHistory(data);
        else setHistory(FALLBACK_HISTORY);
      } else {
        setHistory(FALLBACK_HISTORY);
      }
    } catch {
      setHistory(FALLBACK_HISTORY);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (activeTab === "active" || activeTab === "completed") loadQueue();
    if (activeTab === "history") loadHistory();
  }, [activeTab, loadQueue, loadHistory]);

  // ── Actions ──────────────────────────────────────────────────
  const handleCollect = async (item: QueueItem) => {
    // CAPACITY CHECK: ensure inventory has space for collection
    const invStore = useInventoryStore.getState();
    const capacityCheck = invStore.canAddItem("placeholder", item.quantity);
    if (!capacityCheck.canAdd) {
      addToast(capacityCheck.reason || "Envanter dolu! Ürün toplanamıyor.", "error");
      return;
    }
    
    setCollectingId(item.id);
    try {
      const res = await api.rpc("collect_production", { queue_id: item.id });
      if (res.success) {
        addToast(`${item.item_name} ×${item.quantity} envanterinize eklendi!`, "success");
        setQueue((prev) => prev.filter((q) => q.id !== item.id));
      } else {
        addToast(res.error ?? "Toplama başarısız", "error");
      }
    } catch {
      addToast("Toplama sırasında hata oluştu", "error");
    } finally {
      setCollectingId(null);
    }
  };

  const handleCancel = async (item: QueueItem) => {
    setCancellingId(item.id);
    try {
      const res = await api.rpc("cancel_production", { queue_id: item.id });
      if (res.success) {
        addToast(`${item.item_name} üretimi iptal edildi`, "info" as any);
        setQueue((prev) => prev.filter((q) => q.id !== item.id));
      } else {
        addToast(res.error ?? "İptal başarısız", "error");
      }
    } catch {
      addToast("İptal sırasında hata oluştu", "error");
    } finally {
      setCancellingId(null);
    }
  };

  // ── Derived ──────────────────────────────────────────────────
  const activeItems = queue.filter((q) => q.status === "active");
  const completedItems = queue.filter((q) => q.status === "completed");

  const totalInQueue = activeItems.length;
  const totalCompleted = completedItems.length;
  const nextCompletion = activeItems.reduce<QueueItem | null>((earliest, item) => {
    if (!earliest) return item;
    return new Date(item.finishes_at) < new Date(earliest.finishes_at) ? item : earliest;
  }, null);

  const tabs: { key: ProductionTab; label: string; count?: number }[] = [
    { key: "active",    label: "Aktif",      count: totalInQueue    },
    { key: "completed", label: "Tamamlanan", count: totalCompleted  },
    { key: "history",   label: "Geçmiş"                             },
  ];

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-28">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">⚙️ Üretim Kuyruğu</h1>
        <Link href="/crafting">
          <Button variant="primary" size="sm">+ Yeni Üretim</Button>
        </Link>
      </div>

      {/* Summary stats */}
      <div className="grid grid-cols-3 gap-2">
        <Card>
          <div className="p-3 text-center">
            <p className="text-xl font-bold text-[var(--accent)]">{totalInQueue}</p>
            <p className="text-[10px] text-[var(--text-muted)] mt-0.5">Aktif</p>
          </div>
        </Card>
        <Card>
          <div className="p-3 text-center">
            <p className="text-xl font-bold text-green-400">{totalCompleted}</p>
            <p className="text-[10px] text-[var(--text-muted)] mt-0.5">Toplanacak</p>
          </div>
        </Card>
        <Card>
          <div className="p-3 text-center">
            <p className="text-sm font-bold text-[var(--text-primary)] truncate">
              {nextCompletion ? formatDuration(getRemaining(nextCompletion)) : "—"}
            </p>
            <p className="text-[10px] text-[var(--text-muted)] mt-0.5">Sonraki Bitişe</p>
          </div>
        </Card>
      </div>

      {/* Tabs */}
      <div className="flex gap-2">
        {tabs.map((t) => (
          <button
            key={t.key}
            className={`flex-1 py-2 rounded-lg text-xs font-medium transition-colors relative ${
              activeTab === t.key
                ? "bg-[var(--accent)] text-white"
                : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveTab(t.key)}
          >
            {t.label}
            {t.count !== undefined && t.count > 0 && (
              <span className={`ml-1 px-1.5 py-0.5 rounded-full text-[9px] font-bold ${
                activeTab === t.key ? "bg-white/20" : "bg-[var(--accent)]/20 text-[var(--accent)]"
              }`}>
                {t.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* ── Active Tab ────────────────────────────────────────── */}
      {activeTab === "active" && (
        <div className="space-y-3">
          {isLoading ? (
            <div className="text-center py-12 space-y-2">
              <div className="text-3xl animate-spin inline-block">⚙️</div>
              <p className="text-sm text-[var(--text-muted)]">Yükleniyor...</p>
            </div>
          ) : activeItems.length === 0 ? (
            <div className="text-center py-12 space-y-3">
              <p className="text-4xl">🏭</p>
              <p className="text-sm text-[var(--text-muted)]">
                Aktif üretim yok. Üretim başlatmak için tesisleri ziyaret edin.
              </p>
              <Link href="/crafting">
                <Button variant="primary" size="sm">Zanaat Ekranına Git</Button>
              </Link>
            </div>
          ) : (
            activeItems.map((item) => {
              const remaining = getRemaining(item);
              const progress = getProgress(item);
              const isCollecting = collectingId === item.id;
              const isCancelling = cancellingId === item.id;

              return (
                <AnimatePresence key={item.id}>
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, height: 0 }}
                  >
                    <Card variant="elevated">
                      <div className="p-4">
                        {/* Top row */}
                        <div className="flex items-start justify-between mb-3">
                          <div className="flex items-center gap-2">
                            <ItemIcon icon={item.icon} itemId={String(item.id)} className="text-2xl" />
                            <div>
                              <p className="font-bold text-sm text-[var(--text-primary)]">
                                {item.item_name}
                                {item.quantity > 1 && (
                                  <span className="ml-1.5 text-xs text-[var(--text-muted)]">×{item.quantity}</span>
                                )}
                              </p>
                              <p className="text-[10px] text-[var(--text-muted)]">
                                {getFacilityEmoji(item.facility_type)} {item.facility}
                              </p>
                            </div>
                          </div>
                          <div className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${statusConfig[item.status].bg} ${statusConfig[item.status].color}`}>
                            {statusConfig[item.status].label}
                          </div>
                        </div>

                        {/* Progress */}
                        <div className="space-y-1.5 mb-3">
                          <div className="flex justify-between text-xs text-[var(--text-muted)]">
                            <span>İlerleme</span>
                            <span className="font-medium text-[var(--text-primary)]">{Math.round(progress * 100)}%</span>
                          </div>
                          <ProgressBar value={progress * 100} max={100} color="accent" size="sm" />
                          <div className="flex justify-between text-[10px] text-[var(--text-muted)]">
                            <span>Kalan: <strong className="text-[var(--text-secondary)]">{formatDuration(remaining)}</strong></span>
                            <span>Toplam: {formatDuration(item.total_duration)}</span>
                          </div>
                        </div>

                        {/* Actions */}
                        <div className="flex gap-2">
                          <Button
                            variant="danger"
                            size="sm"
                            onClick={() => handleCancel(item)}
                            isLoading={isCancelling}
                            disabled={isCollecting}
                          >
                            İptal
                          </Button>
                        </div>
                      </div>
                    </Card>
                  </motion.div>
                </AnimatePresence>
              );
            })
          )}
        </div>
      )}

      {/* ── Completed Tab ─────────────────────────────────────── */}
      {activeTab === "completed" && (
        <div className="space-y-3">
          {isLoading ? (
            <div className="text-center py-12">
              <p className="text-sm text-[var(--text-muted)]">Yükleniyor...</p>
            </div>
          ) : completedItems.length === 0 ? (
            <div className="text-center py-12 space-y-2">
              <p className="text-4xl">📭</p>
              <p className="text-sm text-[var(--text-muted)]">Toplanacak tamamlanmış üretim yok.</p>
            </div>
          ) : (
            completedItems.map((item) => {
              const isCollecting = collectingId === item.id;
              const isCancelling = cancellingId === item.id;
              return (
                <AnimatePresence key={item.id}>
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, height: 0 }}
                  >
                    <Card variant="elevated">
                      <div className="p-4">
                        <div className="flex items-start justify-between mb-3">
                          <div className="flex items-center gap-2">
                            <ItemIcon icon={item.icon} itemId={String(item.id)} className="text-2xl" />
                            <div>
                              <p className="font-bold text-sm text-[var(--text-primary)]">
                                {item.item_name}
                                {item.quantity > 1 && (
                                  <span className="ml-1.5 text-xs text-[var(--text-muted)]">×{item.quantity}</span>
                                )}
                              </p>
                              <p className="text-[10px] text-[var(--text-muted)]">
                                {getFacilityEmoji(item.facility_type)} {item.facility}
                              </p>
                            </div>
                          </div>
                          <motion.div
                            animate={{ scale: [1, 1.05, 1] }}
                            transition={{ repeat: Infinity, duration: 2 }}
                            className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-green-400/20 text-green-400"
                          >
                            ✅ Hazır!
                          </motion.div>
                        </div>

                        {/* Full progress bar */}
                        <ProgressBar value={100} max={100} color="success" size="sm" />
                        <p className="text-[10px] text-[var(--text-muted)] mt-1 mb-3">
                          Tamamlandı • Toplanmayı bekliyor
                        </p>

                        {/* Collect button */}
                        <Button
                          variant="primary"
                          size="sm"
                          fullWidth
                          onClick={() => handleCollect(item)}
                          isLoading={isCollecting}
                          disabled={isCancelling}
                        >
                          {isCollecting ? "Toplanıyor..." : "🎁 Topla"}
                        </Button>
                      </div>
                    </Card>
                  </motion.div>
                </AnimatePresence>
              );
            })
          )}
        </div>
      )}

      {/* ── History Tab ───────────────────────────────────────── */}
      {activeTab === "history" && (
        <div className="space-y-2">
          {isLoading ? (
            <div className="text-center py-12">
              <p className="text-sm text-[var(--text-muted)]">Yükleniyor...</p>
            </div>
          ) : history.length === 0 ? (
            <div className="text-center py-12 space-y-2">
              <p className="text-4xl">📜</p>
              <p className="text-sm text-[var(--text-muted)]">Geçmiş üretim kaydı bulunamadı.</p>
            </div>
          ) : (
            <>
              {history.map((h) => {
                const cfg = statusConfig[h.status] ?? statusConfig.completed;
                return (
                  <Card key={h.id}>
                    <div className="p-3 flex items-center gap-3">
                      <span className="text-xl shrink-0">{h.icon}</span>
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-medium text-[var(--text-primary)] truncate">
                          {h.item_name} {h.quantity > 1 ? `×${h.quantity}` : ""}
                        </p>
                        <p className="text-[10px] text-[var(--text-muted)]">
                          {h.facility} • {formatRelative(h.completed_at)}
                        </p>
                      </div>
                      <span className={`text-[10px] font-medium px-2 py-0.5 rounded-full shrink-0 ${cfg.bg} ${cfg.color}`}>
                        {cfg.icon} {cfg.label}
                      </span>
                    </div>
                  </Card>
                );
              })}

              <p className="text-center text-[10px] text-[var(--text-muted)] py-2">
                Son 30 günlük kayıtlar gösteriliyor
              </p>
            </>
          )}
        </div>
      )}

      {/* ── Refresh button ────────────────────────────────────── */}
      <div className="flex justify-center pt-2">
        <button
          onClick={() => {
            if (activeTab === "history") loadHistory();
            else loadQueue();
          }}
          className="text-xs text-[var(--text-muted)] underline"
        >
          🔄 Yenile
        </button>
      </div>

      {/* ── CTA if no productions ────────────────────────────── */}
      {activeTab === "active" && !isLoading && activeItems.length === 0 && completedItems.length === 0 && (
        <Card>
          <div className="p-4 text-center space-y-3">
            <p className="text-2xl">⚒️</p>
            <p className="text-sm font-medium text-[var(--text-primary)]">Yeni Üretim Başlat</p>
            <p className="text-xs text-[var(--text-muted)]">
              Zanaat ekranından malzeme seçerek üretim başlatabilirsiniz.
            </p>
            <Link href="/crafting">
              <Button variant="primary" size="sm" fullWidth>
                Yeni Üretim Başlat →
              </Button>
            </Link>
          </div>
        </Card>
      )}
    </motion.div>
  );
}
