// ============================================================
// Home Page — Kaynak: HomeScreen.gd
// Dashboard: oyuncu bilgisi, enerji/tolerans, görevler,
// bildirimler, iksir modal, hızlı işlemler, son aktivite
// ============================================================

"use client";

import { useMemo, useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { usePotion } from "@/hooks/usePotion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ItemIcon } from "@/components/game/ItemIcon";
import { Modal } from "@/components/ui/Modal";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { formatGold, formatCompact } from "@/lib/utils/string";
import { isInHospital, isInPrison } from "@/lib/utils/validation";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import Link from "next/link";
import type { InventoryItem } from "@/types/inventory";
import type { ItemData } from "@/types/item";

const stagger = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.07 } },
};

const fadeUp = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

// HomeScreen.gd quick actions — reduced to 8 primary actions
const PRIMARY_ACTIONS = [
  { path: "/dungeon",    label: "Zindan",  icon: "🏰" },
  { path: "/trade",     label: "Pazar",   icon: "🛒" },
  { path: "/production",label: "Üretim",  icon: "⚙️" },
  { path: "/guild",     label: "Lonca",   icon: "⚔️" },
  { path: "/pvp",       label: "PvP",     icon: "🥊" },
  { path: "/map",       label: "Harita",  icon: "🗺️" },
  { path: "/shop",      label: "Mağaza",  icon: "💰" },
  { path: "/facilities",label: "Tesis",   icon: "🏭" },
];

// Secondary actions — all other features
const SECONDARY_ACTIONS = [
  { path: "/quests",      label: "Görevler",    icon: "📜" },
  { path: "/crafting",    label: "Zanaat",      icon: "🔨" },
  { path: "/enhancement", label: "Güçlendirme", icon: "🔥" },
  { path: "/equipment",   label: "Teçhizat",    icon: "🛡️" },
  { path: "/inventory",   label: "Envanter",    icon: "🎒" },
  { path: "/character",   label: "Karakter",    icon: "🧙" },
  { path: "/bank",        label: "Banka",       icon: "🏦" },
  { path: "/leaderboard", label: "Sıralama",    icon: "🏆" },
  { path: "/season",      label: "Sezon",       icon: "🌟" },
  { path: "/achievements",label: "Başarımlar",  icon: "🏅" },
  { path: "/events",      label: "Etkinlikler", icon: "🎉" },
  { path: "/warehouse",   label: "Depo",        icon: "📦" },
];

// Mock recent activity entries
const MOCK_ACTIVITY = [
  { id: "a1", icon: "⚔️", text: "Karanlık Orman Zindanı tamamlandı", time: "5dk önce",  color: "text-green-400"  },
  { id: "a2", icon: "🛒", text: "Demir Kılıç satın alındı — 2.500 🪙", time: "18dk önce", color: "text-blue-400"   },
  { id: "a3", icon: "⬆️", text: "Seviye 24'e yükseldildi!", time: "1s önce",  color: "text-yellow-400" },
  { id: "a4", icon: "🧪", text: "Can İksiri kullanıldı — +50 enerji", time: "2s önce",  color: "text-purple-400" },
  { id: "a5", icon: "📜", text: "Görev tamamlandı: Demir Madeni", time: "3s önce",  color: "text-amber-400"  },
];

// Suspicion level → label + color
function getSuspicionInfo(level: number): { label: string; color: string; bg: string } {
  if (level >= 80) return { label: "Kritik", color: "text-red-400",    bg: "bg-red-400/10"    };
  if (level >= 60) return { label: "Yüksek", color: "text-orange-400", bg: "bg-orange-400/10" };
  if (level >= 40) return { label: "Orta",   color: "text-yellow-400", bg: "bg-yellow-400/10" };
  if (level >= 20) return { label: "Düşük",  color: "text-green-400",  bg: "bg-green-400/10"  };
  return { label: "Temiz", color: "text-blue-400", bg: "bg-blue-400/10" };
}

export default function HomePage() {
  const router = useRouter();
  const player = usePlayerStore((s) => s.player);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const level = usePlayerStore((s) => s.level);
  const xp = usePlayerStore((s) => s.xp);
  const nextLevelXp = usePlayerStore((s) => s.nextLevelXp);
  const tolerance = usePlayerStore((s) => s.tolerance);
  const hospitalUntil = usePlayerStore((s) => s.hospitalUntil);
  const prisonUntil = usePlayerStore((s) => s.prisonUntil);
  const globalSuspicionLevel = usePlayerStore((s) => s.globalSuspicionLevel);
  const inHospital = isInHospital(hospitalUntil);
  const inPrison = isInPrison(prisonUntil);

  const inventoryItems = useInventoryStore((s) => s.items);
  const { consumePotion, tolerance: potionTolerance } = usePotion();

  // Active quests
  const [activeQuests, setActiveQuests] = useState<
    { id: string; title: string; progress: number; goal: number; icon?: string }[]
  >([]);
  const [potionModalOpen, setPotionModalOpen] = useState(false);
  const [showAllActions, setShowAllActions] = useState(false);
  const [usingPotionId, setUsingPotionId] = useState<string | null>(null);

  const fallbackActiveQuests = [
    { id: "q1", title: "Demir Madeni", progress: 3, goal: 10, icon: "⛏️" },
    { id: "q2", title: "Karanlık Orman'ı Temizle", progress: 1, goal: 3, icon: "🏰" },
    { id: "q3", title: "5 İksir Kullan", progress: 2, goal: 5, icon: "🧪" },
  ];

  useEffect(() => {
    void (async () => {
      try {
        const res = await api.get<Array<{ id: string; title: string; progress: number; goal: number; icon?: string }>>(APIEndpoints.QUEST_LIST);
        if (res.success && Array.isArray(res.data) && res.data.length > 0) {
          setActiveQuests(res.data.slice(0, 3));
          return;
        }
      } catch {
      }

      setActiveQuests(fallbackActiveQuests);
    })();
  }, []);

  // Potion items from inventory
  const potionItems = useMemo(
    () => inventoryItems.filter((i) => i.item_type === "potion" && i.quantity > 0),
    [inventoryItems]
  );

  // Notifications — HomeScreen.gd notification feed
  const notifications = useMemo(() => {
    const notes: {
      id: string; icon: string; title: string; message: string;
      color: string; bg: string; path?: string; urgent?: boolean;
    }[] = [];

    if (inHospital) {
      notes.push({
        id: "hospital", icon: "🏥", title: "Hastanedesin",
        message: "Tedavi süresi devam ediyor — zindan ve PvP kısıtlandı",
        color: "text-red-400", bg: "bg-red-400/10", path: "/hospital", urgent: true,
      });
    }
    if (inPrison) {
      notes.push({
        id: "prison", icon: "👮", title: "Cezaevindesin",
        message: "Ceza süresi devam ediyor — tüm aktiviteler kısıtlandı",
        color: "text-orange-400", bg: "bg-orange-400/10", path: "/prison", urgent: true,
      });
    }
    if (energy < 20) {
      notes.push({
        id: "energy", icon: "⚡", title: "Enerji Kritik!",
        message: `${energy}/${maxEnergy} enerji — iksir kullanmayı düşün`,
        color: "text-yellow-400", bg: "bg-yellow-400/10", urgent: true,
      });
    }
    if (tolerance > 60) {
      notes.push({
        id: "tolerance", icon: "⚠️", title: "Yüksek Tolerans",
        message: `Bağımlılık riski: %${tolerance} — iksir etkisi azalıyor`,
        color: tolerance >= 80 ? "text-red-400" : "text-orange-400",
        bg: tolerance >= 80 ? "bg-red-400/10" : "bg-orange-400/10",
        urgent: tolerance >= 80,
      });
    }
    if (globalSuspicionLevel >= 60) {
      notes.push({
        id: "suspicion", icon: "🔍", title: "Yüksek Şüphe Seviyesi",
        message: `Global şüphe: ${globalSuspicionLevel}/100 — dikkatli ol`,
        color: "text-purple-400", bg: "bg-purple-400/10",
      });
    }
    return notes;
  }, [energy, maxEnergy, tolerance, hospitalUntil, prisonUntil, inHospital, inPrison, globalSuspicionLevel]);

  const suspicionInfo = getSuspicionInfo(globalSuspicionLevel);

  // Handle potion use
  const handleUsePotion = useCallback(async (item: InventoryItem) => {
    setUsingPotionId(item.item_id);
    try {
      const itemData = {
        item_id: item.item_id,
        energy_restore: item.energy_restore,
        tolerance_increase: item.tolerance_increase,
        overdose_risk: 0.05,
      } as unknown as ItemData;
      const result = await consumePotion(itemData);
      if (result.success) {
        setPotionModalOpen(false);
      }
    } finally {
      setUsingPotionId(null);
    }
  }, [consumePotion]);

  const displayName = player?.display_name || player?.username || "Oyuncu";
  const guildName = player?.guild_name;
  const xpPercent = nextLevelXp > 0 ? Math.min(100, (xp / nextLevelXp) * 100) : 0;

  return (
    <>
      {/* ── Potion Picker Modal ─────────────────────────────── */}
      <Modal
        isOpen={potionModalOpen}
        onClose={() => setPotionModalOpen(false)}
        title="🧪 İksir Kullan"
        size="md"
      >
        <div className="space-y-3">
          {potionItems.length === 0 ? (
            <div className="text-center py-6 space-y-2">
              <p className="text-3xl">🫙</p>
              <p className="text-sm text-[var(--text-muted)]">Envanterde iksir bulunmuyor.</p>
              <Link href="/shop" onClick={() => setPotionModalOpen(false)}>
                <Button variant="primary" size="sm">Mağazaya Git</Button>
              </Link>
            </div>
          ) : (
            <>
              <p className="text-xs text-[var(--text-muted)]">
                Tolerans: %{Math.round(potionTolerance)} • Mevcut enerji: {energy}/{maxEnergy}
              </p>
              {potionItems.map((item) => (
                <button
                  key={item.row_id}
                  onClick={() => handleUsePotion(item)}
                  disabled={usingPotionId !== null}
                  className="w-full flex items-center gap-3 p-3 rounded-xl bg-[var(--bg-elevated)] border border-[var(--border-default)] hover:border-[var(--accent)]/50 transition-colors text-left disabled:opacity-50"
                >
                  <ItemIcon icon={item.icon} itemType={item.item_type} itemId={item.row_id} className="text-2xl shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-[var(--text-primary)] truncate">{item.name}</p>
                    <div className="flex items-center gap-3 mt-0.5">
                      {item.energy_restore > 0 && (
                        <span className="text-[10px] text-yellow-400">+{item.energy_restore} enerji</span>
                      )}
                      {item.tolerance_increase > 0 && (
                        <span className="text-[10px] text-orange-400">+{item.tolerance_increase} tolerans</span>
                      )}
                    </div>
                  </div>
                  <div className="flex flex-col items-end shrink-0">
                    <span className="text-xs text-[var(--text-muted)]">×{item.quantity}</span>
                    {usingPotionId === item.item_id && (
                      <span className="text-[10px] text-[var(--accent)] animate-pulse">Kullanılıyor...</span>
                    )}
                  </div>
                </button>
              ))}
            </>
          )}
        </div>
      </Modal>

      {/* ── Main Page ─────────────────────────────────────────── */}
      <motion.div variants={stagger} initial="hidden" animate="show" className="p-4 space-y-4 pb-24">

        {/* ── Low Energy Warning Banner ──────────────────────── */}
        <AnimatePresence>
          {energy < 20 && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              className="overflow-hidden"
            >
              <div className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-yellow-500/10 border border-yellow-500/30">
                <span className="text-xl animate-pulse">⚡</span>
                <p className="text-xs text-yellow-400 flex-1">
                  <strong>Enerji kritik!</strong> {energy}/{maxEnergy} enerji kaldı.
                </p>
                <button
                  onClick={() => setPotionModalOpen(true)}
                  className="text-[10px] text-yellow-400 font-bold underline shrink-0"
                >
                  İksir Kullan
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ── Tolerance Warning Banner ───────────────────────── */}
        <AnimatePresence>
          {tolerance > 60 && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              className="overflow-hidden"
            >
              <div className={`flex items-center gap-2 px-4 py-2.5 rounded-xl border ${
                tolerance >= 80
                  ? "bg-red-500/10 border-red-500/30"
                  : "bg-orange-500/10 border-orange-500/30"
              }`}>
                <span className="text-xl">⚠️</span>
                <p className={`text-xs flex-1 ${tolerance >= 80 ? "text-red-400" : "text-orange-400"}`}>
                  <strong>Yüksek tolerans!</strong> %{tolerance} — iksir etkisi azalmakta.
                </p>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ── Notifications ─────────────────────────────────── */}
        {notifications.length > 0 && (
          <motion.div variants={fadeUp} className="space-y-2">
            {notifications.map((n) => (
              <button
                key={n.id}
                className={`w-full flex items-start gap-3 px-4 py-3 rounded-xl border text-left transition-colors ${n.bg} border-transparent hover:border-[var(--border-default)]`}
                onClick={() => n.path && router.push(n.path)}
              >
                <span className={`text-xl ${n.urgent ? "animate-pulse" : ""}`}>{n.icon}</span>
                <div className="flex-1 min-w-0">
                  <p className={`text-sm font-semibold ${n.color}`}>{n.title}</p>
                  <p className="text-[11px] text-[var(--text-muted)] mt-0.5 leading-snug">{n.message}</p>
                </div>
                {n.path && <span className="text-[var(--text-muted)] text-xs shrink-0">›</span>}
              </button>
            ))}
          </motion.div>
        )}

        {/* ── Player Info Card ──────────────────────────────── */}
        <motion.div variants={fadeUp}>
          <Card variant="elevated">
            <div className="p-4">
              {/* Name + guild + suspicion */}
              <div className="flex items-start justify-between mb-3">
                <div>
                  <h2 className="text-lg font-bold text-[var(--text-primary)]">{displayName}</h2>
                  <div className="flex items-center gap-2 mt-0.5">
                    <span className="text-xs text-[var(--text-muted)]">Seviye {level}</span>
                    {guildName && (
                      <>
                        <span className="text-[var(--text-muted)]">•</span>
                        <span className="text-xs text-[var(--accent)]">⚔️ {guildName}</span>
                      </>
                    )}
                  </div>
                </div>
                <div className="flex flex-col items-end gap-1">
                  <div className="text-right text-sm">
                    <p className="text-[var(--color-gold)] font-medium">🪙 {formatGold(gold)}</p>
                    <p className="text-[var(--color-gem)] text-xs">💎 {formatCompact(gems)}</p>
                  </div>
                  {/* Global suspicion indicator */}
                  <div className={`text-[9px] font-bold px-2 py-0.5 rounded-full ${suspicionInfo.bg} ${suspicionInfo.color}`}>
                    🔍 {suspicionInfo.label}
                  </div>
                </div>
              </div>

              {/* XP bar */}
              <div className="space-y-1">
                <div className="flex justify-between text-[10px] text-[var(--text-muted)]">
                  <span>XP</span>
                  <span>{formatCompact(xp)} / {formatCompact(nextLevelXp)}</span>
                </div>
                <ProgressBar value={xpPercent} max={100} color="accent" size="sm" />
              </div>
            </div>
          </Card>
        </motion.div>

        {/* ── Energy + Tolerance bars ───────────────────────── */}
        <motion.div variants={fadeUp} className="grid grid-cols-2 gap-3">
          <Card>
            <div className="p-3">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-xs font-medium text-[var(--text-primary)]">⚡ Enerji</span>
                <span className={`text-[10px] font-bold ${energy < 20 ? "text-red-400 animate-pulse" : "text-[var(--text-muted)]"}`}>
                  {energy}/{maxEnergy}
                </span>
              </div>
              <ProgressBar
                value={energy}
                max={maxEnergy}
                color={energy < 20 ? "health" : energy < 50 ? "warning" : "energy"}
                size="sm"
              />
              {energy < 20 && (
                <button
                  onClick={() => setPotionModalOpen(true)}
                  className="text-[9px] text-yellow-400 underline mt-1"
                >
                  İksir kullan →
                </button>
              )}
            </div>
          </Card>

          <Card>
            <div className="p-3">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-xs font-medium text-[var(--text-primary)]">🧪 Tolerans</span>
                <span className={`text-[10px] font-bold ${
                  tolerance >= 80 ? "text-red-400" : tolerance >= 60 ? "text-orange-400" : "text-[var(--text-muted)]"
                }`}>
                  %{tolerance}
                </span>
              </div>
              <ProgressBar
                value={tolerance}
                max={100}
                color={tolerance >= 80 ? "health" : tolerance >= 50 ? "warning" : "success"}
                size="sm"
              />
              {tolerance >= 80 && (
                <p className="text-[9px] text-red-400 mt-1">Doz aşımı riski yüksek!</p>
              )}
            </div>
          </Card>
        </motion.div>

        {/* ── Active Quests ─────────────────────────────────── */}
        {activeQuests.length > 0 && (
          <motion.div variants={fadeUp}>
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-sm font-semibold text-[var(--text-secondary)]">📜 Aktif Görevler</h3>
              <Link href="/quests" className="text-[10px] text-[var(--accent)] underline">Tümünü Gör</Link>
            </div>
            <div className="space-y-2">
              {activeQuests.map((q) => {
                const pct = q.goal > 0 ? (q.progress / q.goal) * 100 : 0;
                return (
                  <Card key={q.id}>
                    <div className="p-3">
                      <div className="flex items-center justify-between mb-1.5">
                        <div className="flex items-center gap-2">
                          {q.icon && <span className="text-base">{q.icon}</span>}
                          <p className="text-xs font-medium text-[var(--text-primary)] truncate">{q.title}</p>
                        </div>
                        <span className="text-[10px] text-[var(--text-muted)] shrink-0 ml-2">
                          {q.progress}/{q.goal}
                        </span>
                      </div>
                      <ProgressBar value={pct} max={100} color="accent" size="sm" />
                    </div>
                  </Card>
                );
              })}
            </div>
          </motion.div>
        )}

        {/* ── Use Potion quick action ───────────────────────── */}
        <motion.div variants={fadeUp}>
          <button
            className="w-full flex items-center gap-3 p-3 rounded-xl bg-[var(--bg-card)] border border-[var(--border-default)] hover:border-[var(--accent)]/50 transition-colors text-left"
            onClick={() => setPotionModalOpen(true)}
          >
            <span className="text-2xl">🧪</span>
            <div className="flex-1">
              <p className="text-sm font-semibold text-[var(--text-primary)]">İksir Kullan</p>
              <p className="text-[10px] text-[var(--text-muted)]">
                Enerji yenile • {potionItems.length} iksir mevcut
              </p>
            </div>
            <span className="text-[var(--text-muted)]">›</span>
          </button>
        </motion.div>

        {/* ── Primary Quick Actions Grid (8 items) ─────────── */}
        <motion.div variants={fadeUp}>
          <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">Hızlı İşlemler</h3>
          <div className="grid grid-cols-4 gap-2">
            {PRIMARY_ACTIONS.map((action) => (
              <motion.button
                key={action.path}
                whileTap={{ scale: 0.92 }}
                onClick={() => router.push(action.path)}
                className={`flex flex-col items-center gap-1.5 p-3 rounded-xl border transition-colors ${
                  inHospital && ["/dungeon", "/pvp"].includes(action.path)
                    ? "border-red-500/30 bg-red-500/5 opacity-50 cursor-not-allowed"
                    : "bg-[var(--card-bg)] border-[var(--border-default)] hover:border-[var(--accent)] hover:bg-[var(--accent)]/5"
                }`}
              >
                <span className="text-2xl">{action.icon}</span>
                <span className="text-[10px] font-medium text-[var(--text-secondary)] text-center leading-tight">
                  {action.label}
                </span>
              </motion.button>
            ))}
          </div>
        </motion.div>

        {/* ── Secondary Actions (expandable) ───────────────── */}
        <motion.div variants={fadeUp}>
          <AnimatePresence>
            {showAllActions && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: "auto" }}
                exit={{ opacity: 0, height: 0 }}
                className="overflow-hidden mb-2"
              >
                <div className="grid grid-cols-4 gap-2">
                  {SECONDARY_ACTIONS.map((action) => (
                    <motion.button
                      key={action.path}
                      whileTap={{ scale: 0.92 }}
                      onClick={() => router.push(action.path)}
                      className="flex flex-col items-center gap-1.5 p-3 rounded-xl border border-[var(--border-default)] bg-[var(--card-bg)] hover:border-[var(--accent)] hover:bg-[var(--accent)]/5 transition-colors"
                    >
                      <span className="text-2xl">{action.icon}</span>
                      <span className="text-[10px] font-medium text-[var(--text-secondary)] text-center leading-tight">
                        {action.label}
                      </span>
                    </motion.button>
                  ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>
          <button
            onClick={() => setShowAllActions((v) => !v)}
            className="w-full py-2 text-xs text-[var(--text-muted)] hover:text-[var(--text-secondary)] transition-colors text-center"
          >
            {showAllActions ? "▲ Daha az göster" : "▼ Tüm özellikler"}
          </button>
        </motion.div>

        {/* ── Recent Activity ───────────────────────────────── */}
        <motion.div variants={fadeUp}>
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)]">⏱️ Son Aktivite</h3>
          </div>
          <Card>
            <div className="divide-y divide-[var(--border-default)]">
              {MOCK_ACTIVITY.map((a) => (
                <div key={a.id} className="flex items-center gap-3 px-4 py-2.5">
                  <span className="text-lg shrink-0">{a.icon}</span>
                  <p className={`text-xs flex-1 ${a.color}`}>{a.text}</p>
                  <span className="text-[9px] text-[var(--text-muted)] shrink-0">{a.time}</span>
                </div>
              ))}
            </div>
          </Card>
        </motion.div>

        {/* ── System status ─────────────────────────────────── */}
        {(inHospital || inPrison) && (
          <motion.div variants={fadeUp} className="space-y-2">
            {inHospital && (
              <Card>
                <button
                  className="w-full flex items-center gap-3 p-3 text-left"
                  onClick={() => router.push("/hospital")}
                >
                  <span className="text-2xl">🏥</span>
                  <div className="flex-1">
                    <p className="text-sm font-bold text-red-400">Hastanede Tedavi Görüyorsun</p>
                    <p className="text-xs text-[var(--text-muted)]">
                      Hastane ekranına giderek durumunu kontrol et
                    </p>
                  </div>
                  <span className="text-[var(--text-muted)]">›</span>
                </button>
              </Card>
            )}
            {inPrison && (
              <Card>
                <button
                  className="w-full flex items-center gap-3 p-3 text-left"
                  onClick={() => router.push("/prison")}
                >
                  <span className="text-2xl">👮</span>
                  <div className="flex-1">
                    <p className="text-sm font-bold text-orange-400">Cezaevinde Tutuklusun</p>
                    <p className="text-xs text-[var(--text-muted)]">
                      Kefalet ödeyerek erken çıkabilirsin
                    </p>
                  </div>
                  <span className="text-[var(--text-muted)]">›</span>
                </button>
              </Card>
            )}
          </motion.div>
        )}
      </motion.div>
    </>
  );
}
