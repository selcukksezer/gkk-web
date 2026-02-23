// ============================================================
// Home Page — Kaynak: scenes/ui/screens/HomeScreen.gd
// Dashboard: Player info, energy, tolerance, quick actions, notifications
// ============================================================

"use client";

import { useMemo, useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { Card } from "@/components/ui/Card";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { formatGold, formatCompact } from "@/lib/utils/string";
import { isInHospital, isInPrison } from "@/lib/utils/validation";
import { api } from "@/lib/api";
import Link from "next/link";

const stagger = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.06 } },
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

// All game features accessible from home — Godot HomeScreen quick actions
const QUICK_ACTIONS = [
  { path: "/quests", label: "Görevler", icon: "📜" },
  { path: "/dungeon", label: "Zindan", icon: "🏰" },
  { path: "/pvp", label: "PvP Arena", icon: "⚔️" },
  { path: "/facilities", label: "Tesisler", icon: "🏭" },
  { path: "/crafting", label: "Zanaat", icon: "🔨" },
  { path: "/enhancement", label: "Güçlendirme", icon: "🔥" },
  { path: "/production", label: "Üretim", icon: "⚙️" },
  { path: "/shop", label: "Mağaza", icon: "🛒" },
  { path: "/equipment", label: "Teçhizat", icon: "🛡️" },
  { path: "/inventory", label: "Envanter", icon: "🎒" },
  { path: "/character", label: "Karakter", icon: "🧙" },
  { path: "/bank", label: "Banka", icon: "🏦" },
  { path: "/warehouse", label: "Depo", icon: "📦" },
  { path: "/leaderboard", label: "Sıralama", icon: "🏆" },
  { path: "/season", label: "Sezon", icon: "🌟" },
  { path: "/achievements", label: "Başarımlar", icon: "🏅" },
  { path: "/events", label: "Etkinlikler", icon: "🎉" },
  { path: "/guild", label: "Lonca", icon: "🏰" },
  { path: "/trade", label: "Ticaret", icon: "💱" },
  { path: "/building", label: "Binalar", icon: "🏗️" },
];

export default function HomePage() {
  const router = useRouter();
  const player = usePlayerStore((s) => s.player);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const level = usePlayerStore((s) => s.level);
  const xp = usePlayerStore((s) => s.xp);
  const tolerance = usePlayerStore((s) => s.tolerance);
  const hospitalUntil = usePlayerStore((s) => s.hospitalUntil);
  const prisonUntil = usePlayerStore((s) => s.prisonUntil);

  // Active quests — Godot HomeScreen._load_active_quests
  const [activeQuests, setActiveQuests] = useState<{ id: string; title: string; progress: number; goal: number }[]>([]);
  useEffect(() => {
    api.rpc<{ id: string; title: string; progress: number; goal: number }[]>("get_active_quests", {})
      .then((res) => { if (res.success && res.data) setActiveQuests((res.data as []).slice(0, 3)); })
      .catch(() => {});
  }, []);

  const notifications = useMemo(() => {
    const notes: { icon: string; title: string; message: string; color: string; path?: string }[] = [];

    if (isInHospital(hospitalUntil)) {
      notes.push({
        icon: "🏥", title: "Hastanedesin",
        message: "Tedavi süresi devam ediyor",
        color: "var(--color-error)", path: "/hospital",
      });
    }
    if (isInPrison(prisonUntil)) {
      notes.push({
        icon: "👮", title: "Cezaevindesin",
        message: "Ceza süresi devam ediyor",
        color: "var(--color-warning)", path: "/prison",
      });
    }
    if (energy < maxEnergy * 0.2) {
      notes.push({
        icon: "⚡", title: "Enerji Düşük",
        message: `${energy}/${maxEnergy} enerji kaldı`,
        color: "var(--color-warning)",
      });
    }
    if (tolerance >= 60) {
      notes.push({
        icon: "⚠️", title: "Yüksek Tolerans",
        message: `Bağımlılık riski: %${tolerance}`,
        color: tolerance >= 80 ? "var(--color-error)" : "var(--color-warning)",
      });
    }
    return notes;
  }, [energy, maxEnergy, tolerance, hospitalUntil, prisonUntil]);

  const xpForNext = Math.floor(1000 * Math.pow(level, 1.5));

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="p-4 space-y-4 pb-24">
      {/* Player Info */}
      <motion.div variants={fadeUp}>
        <Card variant="elevated">
          <div className="p-4">
            <div className="flex items-center justify-between mb-3">
              <div>
                <h2 className="text-lg font-bold text-[var(--text-primary)]">
                  {player?.display_name || player?.username || "Oyuncu"}
                </h2>
                <p className="text-xs text-[var(--text-muted)]">Seviye {level}</p>
              </div>
              <div className="text-right text-sm">
                <p className="text-[var(--color-gold)]">🪙 {formatGold(gold)}</p>
                <p className="text-[var(--color-gem)]">💎 {formatCompact(gems)}</p>
              </div>
            </div>
            <ProgressBar value={xp} max={xpForNext} color="accent" size="sm"
              label={`XP: ${formatCompact(xp)} / ${formatCompact(xpForNext)}`} />
          </div>
        </Card>
      </motion.div>

      {/* Energy + Tolerance */}
      <motion.div variants={fadeUp} className="grid grid-cols-2 gap-3">
        <Card>
          <div className="p-3">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-xs font-medium text-[var(--text-primary)]">⚡ Enerji</span>
              <span className="text-[10px] text-[var(--text-muted)]">{energy}/{maxEnergy}</span>
            </div>
            <ProgressBar value={energy} max={maxEnergy} color="energy" size="sm" />
          </div>
        </Card>
        <Card>
          <div className="p-3">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-xs font-medium text-[var(--text-primary)]">🧪 Tolerans</span>
              <span className="text-[10px] text-[var(--text-muted)]">{tolerance}/100</span>
            </div>
            <ProgressBar value={tolerance} max={100}
              color={tolerance >= 80 ? "health" : tolerance >= 50 ? "warning" : "success"} size="sm" />
          </div>
        </Card>
      </motion.div>

      {/* Notifications */}
      {notifications.length > 0 && (
        <motion.div variants={fadeUp} className="space-y-2">
          {notifications.map((n, i) => (
            <Card key={i}>
              <button className="w-full p-3 flex items-start gap-3 text-left"
                onClick={() => n.path && router.push(n.path)}>
                <span className="text-xl">{n.icon}</span>
                <div>
                  <p className="text-sm font-semibold" style={{ color: n.color }}>{n.title}</p>
                  <p className="text-xs text-[var(--text-muted)]">{n.message}</p>
                </div>
              </button>
            </Card>
          ))}
        </motion.div>
      )}

      {/* Active Quests — Godot: HomeScreen.active_quests_container */}
      {activeQuests.length > 0 && (
        <motion.div variants={fadeUp}>
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)]">📜 Aktif Görevler</h3>
            <Link href="/quests" className="text-[10px] text-[var(--accent)] underline">Tümünü Gör</Link>
          </div>
          <div className="space-y-2">
            {activeQuests.map((q) => (
              <Card key={q.id}>
                <div className="p-2">
                  <div className="flex items-center justify-between mb-1">
                    <p className="text-xs font-medium text-[var(--text-primary)] truncate">{q.title}</p>
                    <span className="text-[10px] text-[var(--text-muted)] shrink-0 ml-2">{q.progress}/{q.goal}</span>
                  </div>
                  <ProgressBar value={q.progress} max={q.goal} color="accent" size="sm" />
                </div>
              </Card>
            ))}
          </div>
        </motion.div>
      )}

      {/* İksir Kullan — Godot: use_potion_button */}
      <motion.div variants={fadeUp}>
        <Card>
          <button className="w-full p-3 flex items-center gap-3"
            onClick={() => router.push("/inventory?tab=potions")}>
            <span className="text-2xl">🧪</span>
            <div className="text-left">
              <p className="text-sm font-semibold text-[var(--text-primary)]">İksir Kullan</p>
              <p className="text-xs text-[var(--text-muted)]">Enerji veya can yenilemek için iksir kullan</p>
            </div>
          </button>
        </Card>
      </motion.div>

      {/* Quick Actions Grid */}
      <motion.div variants={fadeUp}>
        <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">Hızlı İşlemler</h3>
        <div className="grid grid-cols-4 gap-2">
          {QUICK_ACTIONS.map((action) => (
            <motion.button
              key={action.path}
              whileTap={{ scale: 0.95 }}
              onClick={() => router.push(action.path)}
              className="flex flex-col items-center gap-1 p-3 rounded-xl bg-[var(--card-bg)] border border-[var(--border-default)] hover:border-[var(--accent)] transition-colors"
            >
              <span className="text-2xl">{action.icon}</span>
              <span className="text-[10px] font-medium text-[var(--text-secondary)] text-center leading-tight">
                {action.label}
              </span>
            </motion.button>
          ))}
        </div>
      </motion.div>
    </motion.div>
  );
}
