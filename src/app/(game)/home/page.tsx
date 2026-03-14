// ============================================================
// Home Page — Mobil Oyun Dashboard (Login Sonrası)
// Modern tasarım: Character hero, stats, quick actions, quests
// Technologies: Framer Motion, Tailwind CSS, glassmorphism
// ============================================================

"use client";

import { useMemo, useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence, type Variants } from "framer-motion";
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
import { calculateEquipmentStats, calculateCharacterPowerBreakdown } from "@/lib/utils/calculateEquipmentStats";
import { getReputationTier } from "@/lib/utils/reputation";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import Link from "next/link";
import type { InventoryItem } from "@/types/inventory";
import type { ItemData } from "@/types/item";
import { Zap, Crown, TrendingUp, Sword } from "lucide-react";

// ============================================================
// Animation Variants
// ============================================================

const containerVariants: Variants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: {
      staggerChildren: 0.08,
      delayChildren: 0.2,
    },
  },
};

const itemVariants: Variants = {
  hidden: { opacity: 0, y: 20 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: "easeOut" },
  },
};

const floatingVariants: Variants = {
  animate: {
    y: [0, -8, 0],
    transition: {
      duration: 4,
      repeat: Infinity,
      ease: "easeInOut",
    },
  },
};

const pulseVariants: Variants = {
  animate: {
    scale: [1, 1.05, 1],
    opacity: [0.7, 1, 0.7],
    transition: {
      duration: 3,
      repeat: Infinity,
      ease: "easeInOut",
    },
  },
};

// ============================================================
// Quick Actions Configuration
// ============================================================

const PRIMARY_ACTIONS = [
  { path: "/dungeon", label: "Koparma", icon: "⚔️", color: "from-red-600 to-red-700" },
  { path: "/quest", label: "Görevler", icon: "📜", color: "from-blue-600 to-blue-700" },
  { path: "/market", label: "Market", icon: "💰", color: "from-purple-600 to-purple-700" },
  { path: "/enhancement", label: "Geliştirme", icon: "🔥", color: "from-orange-600 to-orange-700" },
];

const SECONDARY_ACTIONS = [
  { path: "/crafting", label: "Zanaat", icon: "🔨", color: "from-amber-600 to-amber-700" },
  { path: "/equipment", label: "Teçhizat", icon: "🛡️", color: "from-slate-600 to-slate-700" },
  { path: "/shop", label: "Mağaza", icon: "🛒", color: "from-cyan-600 to-cyan-700" },
  { path: "/bank", label: "Banka", icon: "🏦", color: "from-gray-600 to-gray-700" },
  { path: "/leaderboard", label: "Sıralama", icon: "🏆", color: "from-yellow-600 to-yellow-700" },
  { path: "/pvp", label: "PvP", icon: "🥊", color: "from-pink-600 to-pink-700" },
  { path: "/facilities", label: "Tesis", icon: "🏭", color: "from-green-600 to-green-700" },
  { path: "/season", label: "Sezon", icon: "✨", color: "from-indigo-600 to-indigo-700" },
];

// ============================================================
// Styles & Utilities
// ============================================================

function getSuspicionInfo(level: number): { label: string; color: string; bg: string } {
  if (level >= 80) return { label: "Kritik", color: "text-red-400", bg: "bg-red-400/10" };
  if (level >= 60) return { label: "Yüksek", color: "text-orange-400", bg: "bg-orange-400/10" };
  if (level >= 40) return { label: "Orta", color: "text-yellow-400", bg: "bg-yellow-400/10" };
  if (level >= 20) return { label: "Düşük", color: "text-green-400", bg: "bg-green-400/10" };
  return { label: "Temiz", color: "text-blue-400", bg: "bg-blue-400/10" };
}

// ============================================================
// Main Component
// ============================================================

export default function HomePage() {
  const router = useRouter();
  const player = usePlayerStore((s) => s.player);
  const inventoryItems = useInventoryStore((s) => s.items);
  const equippedMap = useInventoryStore((s) => s.equippedItems);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);
  const { consumePotion, tolerance: potionTolerance } = usePotion();

  const [showPotionModal, setShowPotionModal] = useState(false);
  const [showAllActions, setShowAllActions] = useState(false);
  const [usingPotionId, setUsingPotionId] = useState<string | null>(null);
  const [activeQuests, setActiveQuests] = useState<
    { id: string; title: string; progress: number; goal: number; icon?: string }[]
  >([]);

  // Extract player stats
  const displayName = player?.display_name || player?.username || "Oyuncu";
  const guildName = player?.guild_name;
  const gold = player?.gold || 0;
  const gems = player?.gems || 0;
  const level = player?.level || 1;
  const xp = player?.xp || 0;
  const nextLevelXp = 1000; // Placeholder — backend'den gelecek
  const energy = player?.energy || 0;
  const maxEnergy = player?.max_energy || 100;
  const tolerance = player?.addiction_level || 0;
  const hospitalUntil = player?.hospital_until;
  const prisonUntil = player?.prison_until;
  const globalSuspicionLevel = player?.global_suspicion_level || 0;
  const reputation = Math.max(0, player?.reputation || 0);
  const reputationTier = useMemo(() => getReputationTier(reputation), [reputation]);

  const inHospital = hospitalUntil ? isInHospital(hospitalUntil) : false;
  const inPrison = prisonUntil ? isInPrison(prisonUntil) : false;
  const xpPercent = nextLevelXp > 0 ? Math.min(100, (xp / nextLevelXp) * 100) : 0;
  const energyPercent = maxEnergy > 0 ? (energy / maxEnergy) * 100 : 0;
  const tolerancePercent = Math.min(100, tolerance);
  const equipmentStats = useMemo(() => calculateEquipmentStats(equippedMap || {}), [equippedMap]);
  const powerBreakdown = useMemo(
    () => calculateCharacterPowerBreakdown(equipmentStats, level, reputation),
    [equipmentStats, level, reputation]
  );

  // Potion items
  const potionItems = useMemo(
    () => inventoryItems.filter((i) => i.item_type === "potion" && i.quantity > 0),
    [inventoryItems]
  );

  // Fetch active quests
  const fallbackActiveQuests = [
    { id: "q1", title: "Demir Madeni", progress: 3, goal: 10, icon: "⛏️" },
    { id: "q2", title: "Karanlık Orman'ı Temizle", progress: 1, goal: 3, icon: "🏰" },
    { id: "q3", title: "5 İksir Kullan", progress: 2, goal: 5, icon: "🧪" },
  ];

  useEffect(() => {
    fetchInventory(true).catch(() => {});
  }, [fetchInventory]);

  useEffect(() => {
    void (async () => {
      try {
        const res = await api.get<
          Array<{ id: string; title: string; progress: number; goal: number; icon?: string }>
        >(APIEndpoints.QUEST_LIST);
        if (res.success && Array.isArray(res.data) && res.data.length > 0) {
          setActiveQuests(res.data.slice(0, 3));
          return;
        }
      } catch {
        // Fallback
      }
      setActiveQuests(fallbackActiveQuests);
    })();
  }, []);

  // Handle potion use
  const handleUsePotion = useCallback(
    async (item: InventoryItem) => {
      setUsingPotionId(item.item_id);
      try {
        const itemData = {
          item_id: item.item_id,
          energy_restore: item.energy_restore || 0,
          tolerance_increase: item.tolerance_increase || 0,
          overdose_risk: 0.05,
        } as unknown as ItemData;
        const result = await consumePotion(itemData);
        if (result.success) {
          setShowPotionModal(false);
        }
      } finally {
        setUsingPotionId(null);
      }
    },
    [consumePotion]
  );

  const suspicionInfo = getSuspicionInfo(globalSuspicionLevel);

  if (!player) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <motion.div className="text-center space-y-4" animate={{ opacity: 1 }} initial={{ opacity: 0 }}>
          <motion.div
            className="h-8 w-8 border-4 border-gold border-t-transparent rounded-full mx-auto"
            animate={{ rotate: 360 }}
            transition={{ duration: 1, repeat: Infinity }}
          />
          <p className="text-sm text-gray-400">Yükleniyor...</p>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black pb-24 overflow-x-hidden">
      {/* ========== Premium Dark Background with Grid ========== */}
      <div className="fixed inset-0 -z-20">
        <div className="absolute inset-0 bg-gradient-to-b from-slate-900/50 via-black to-black" />
        <div
          className="absolute inset-0 opacity-[0.02]"
          style={{
            backgroundImage: "radial-gradient(circle at 20% 50%, white 1px, transparent 1px)",
            backgroundSize: "50px 50px",
          }}
        />
      </div>

      {/* ========== Animated Background Orbs ========== */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none -z-10">
        <motion.div
          variants={floatingVariants}
          animate="animate"
          className="absolute top-0 -left-1/4 w-[600px] h-[600px] bg-gradient-to-br from-purple-600/20 to-blue-600/10 rounded-full blur-3xl"
        />
        <motion.div
          variants={floatingVariants}
          animate="animate"
          transition={{ delay: 1 }}
          className="absolute -bottom-32 -right-1/4 w-[600px] h-[600px] bg-gradient-to-tl from-cyan-600/15 to-emerald-600/8 rounded-full blur-3xl"
        />
        <motion.div
          variants={pulseVariants}
          animate="animate"
          className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-gradient-to-r from-pink-600/10 to-red-600/5 rounded-full blur-3xl"
        />
      </div>

      {/* ========== Content ========== */}
      <motion.div
        className="relative px-4 pt-4 space-y-4"
        variants={containerVariants}
        initial="hidden"
        animate="show"
      >
        {/* ===== System Warnings ===== */}
        <AnimatePresence>
          {(inHospital || inPrison) && (
            <motion.div
              variants={itemVariants}
              initial="hidden"
              animate="show"
              exit="hidden"
              className={`p-4 rounded-xl border backdrop-blur-lg flex items-start gap-3 ${
                inHospital
                  ? "bg-red-500/10 border-red-500/30"
                  : "bg-orange-500/10 border-orange-500/30"
              }`}
            >
              <span className="text-2xl animate-pulse">
                {inHospital ? "🏥" : "👮"}
              </span>
              <div className="flex-1">
                <p className={`font-bold text-sm ${inHospital ? "text-red-400" : "text-orange-400"}`}>
                  {inHospital ? "Hastanede Tedavi" : "Cezaevinde"}
                </p>
                <p className="text-xs text-gray-400 mt-1">
                  {inHospital
                    ? "Tedavi süresi devam ediyor — Zindan ve PvP kısıtlandı"
                    : "Ceza süresi devam ediyor — Tüm aktiviteler kısıtlandı"}
                </p>
              </div>
            </motion.div>
          )}

          {energy < 20 && (
            <motion.div
              variants={itemVariants}
              initial="hidden"
              animate="show"
              exit="hidden"
              className="p-4 rounded-xl border bg-yellow-500/10 border-yellow-500/30 backdrop-blur-lg flex items-start gap-3"
            >
              <span className="text-2xl animate-pulse">⚡</span>
              <div className="flex-1">
                <p className="font-bold text-sm text-yellow-400">Enerji Kritik</p>
                <p className="text-xs text-gray-400 mt-1">
                  {energy}/{maxEnergy} enerji kaldı — İksir kullanmayı düşün
                </p>
              </div>
            </motion.div>
          )}

          {tolerance > 60 && (
            <motion.div
              variants={itemVariants}
              initial="hidden"
              animate="show"
              exit="hidden"
              className={`p-4 rounded-xl border backdrop-blur-lg flex items-start gap-3 ${
                tolerance >= 80
                  ? "bg-red-500/10 border-red-500/30"
                  : "bg-orange-500/10 border-orange-500/30"
              }`}
            >
              <span className="text-2xl">⚠️</span>
              <div className="flex-1">
                <p className={`font-bold text-sm ${tolerance >= 80 ? "text-red-400" : "text-orange-400"}`}>
                  Yüksek Tolerans
                </p>
                <p className="text-xs text-gray-400 mt-1">
                  %{tolerance} — İksir etkisi azalmakta
                </p>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ===== Character Hero Section (Premium) ===== */}
        <motion.div
          variants={itemVariants}
          className="relative rounded-3xl border border-white/10 bg-gradient-to-br from-white/8 to-white/[0.02] backdrop-blur-2xl p-8 overflow-hidden"
        >
          {/* Background Glow */}
          <div className="absolute inset-0 bg-gradient-to-r from-blue-600/0 via-purple-600/5 to-blue-600/0 pointer-events-none" />

          <div className="relative z-10 flex items-end gap-6">
            {/* Character Avatar Placeholder */}
            <motion.div
              whileHover={{ scale: 1.05 }}
              className="relative shrink-0"
            >
              {/* Glowing Circle */}
              <div className="absolute -inset-4 bg-gradient-to-r from-purple-600/50 to-blue-600/50 rounded-full blur-xl" />
              
              {/* Avatar Container */}
              <div className="relative w-24 h-24 rounded-full border-2 border-white/30 bg-gradient-to-br from-purple-500/30 to-blue-500/20 backdrop-blur-lg flex items-center justify-center overflow-hidden">
                <span className="text-5xl">🧙</span>
                {/* Inner Ring */}
                <div className="absolute inset-0 rounded-full border border-white/10" />
              </div>

              {/* Level Badge */}
              <motion.div
                className="absolute -bottom-2 -right-2 w-12 h-12 rounded-full bg-gradient-to-br from-amber-400 to-orange-600 border-2 border-black/50 flex items-center justify-center font-black text-sm text-white shadow-lg"
                whileHover={{ scale: 1.15 }}
              >
                {level}
              </motion.div>
            </motion.div>

            {/* Character Info */}
            <div className="flex-1">
              <motion.h1
                className="text-4xl font-black bg-gradient-to-r from-white via-blue-200 to-purple-200 bg-clip-text text-transparent mb-2 tracking-tight"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 }}
              >
                {displayName}
              </motion.h1>

              <div className="flex flex-wrap items-center gap-2 mb-3">
                {guildName && (
                  <motion.span
                    whileHover={{ scale: 1.05 }}
                    className="px-4 py-1.5 rounded-full bg-gradient-to-r from-purple-600/40 to-pink-600/40 border border-purple-500/50 text-purple-200 text-sm font-bold backdrop-blur-lg"
                  >
                    ⚔️ {guildName}
                  </motion.span>
                )}
                <motion.span
                  className="px-4 py-1.5 rounded-full border text-sm font-bold backdrop-blur-lg"
                  style={{
                    borderColor: reputationTier.color,
                    color: reputationTier.color,
                    background: "rgba(255,255,255,0.04)",
                  }}
                >
                  👑 {reputationTier.title} • {formatCompact(reputation)} Rep
                </motion.span>
                <motion.span
                  className="px-4 py-1.5 rounded-full bg-gradient-to-r from-blue-600/40 to-cyan-600/40 border border-blue-500/50 text-blue-200 text-sm font-bold backdrop-blur-lg"
                >
                  🌟 {globalSuspicionLevel > 60 ? `Şüphe: ${globalSuspicionLevel}%` : "Güvenli"}
                </motion.span>
              </div>

              {/* XP Progress */}
              <div className="space-y-1.5">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-bold text-gray-300 uppercase tracking-wider">Experience</span>
                  <span className="text-xs font-bold bg-gradient-to-r from-blue-400 to-cyan-300 bg-clip-text text-transparent">
                    {formatCompact(xp)} / {formatCompact(nextLevelXp)}
                  </span>
                </div>
                <div className="relative h-3 rounded-full bg-white/5 border border-white/10 overflow-hidden group">
                  <motion.div
                    className="absolute inset-y-0 left-0 bg-gradient-to-r from-blue-500 via-purple-500 to-cyan-400"
                    initial={{ width: 0 }}
                    animate={{ width: `${xpPercent}%` }}
                    transition={{ duration: 1, ease: "easeOut" }}
                  />
                  <div className="absolute inset-0 bg-gradient-to-r from-white/0 to-white/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                </div>
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== Premium Stats Grid (2x2 with shine effects) ===== */}
        <motion.div variants={itemVariants} className="grid grid-cols-2 gap-4">
          {[
            {
              label: "Gold",
              icon: "💰",
              value: formatGold(gold),
              gradient: "from-yellow-600 to-orange-600",
              border: "border-yellow-500/30",
              glow: "from-yellow-600/50 to-orange-600/50",
            },
            {
              label: "Gems",
              icon: "💎",
              value: formatCompact(gems),
              gradient: "from-purple-600 to-pink-600",
              border: "border-purple-500/30",
              glow: "from-purple-600/50 to-pink-600/50",
            },
            {
              label: "Energy",
              icon: "⚡",
              value: `${energy}/${maxEnergy}`,
              percent: energyPercent,
              gradient: "from-cyan-600 to-blue-600",
              border: "border-cyan-500/30",
              glow: "from-cyan-600/50 to-blue-600/50",
            },
            {
              label: "Tolerance",
              icon: "🧪",
              value: `${tolerance}%`,
              percent: tolerancePercent,
              gradient: "from-red-600 to-orange-600",
              border: "border-red-500/30",
              glow: "from-red-600/50 to-orange-600/50",
            },
            {
              label: "Reputation",
              icon: "⭐",
              value: `${formatCompact(reputation)} (${reputationTier.title})`,
              gradient: "from-emerald-600 to-teal-600",
              border: "border-emerald-500/30",
              glow: "from-emerald-600/50 to-teal-600/50",
            },
            {
              label: "Power",
              icon: "🔥",
              value: formatCompact(powerBreakdown.totalPower),
              gradient: "from-indigo-600 to-violet-600",
              border: "border-indigo-500/30",
              glow: "from-indigo-600/50 to-violet-600/50",
            },
          ].map((stat, idx) => (
            <motion.div key={stat.label} whileHover={{ scale: 1.05 }} className="relative group">
              {/* Glow Background */}
              <div
                className={`absolute -inset-1 bg-gradient-to-br ${stat.glow} rounded-2xl blur-lg opacity-0 group-hover:opacity-100 transition-opacity`}
              />

              <div
                className={`relative rounded-2xl border ${stat.border} bg-gradient-to-br ${stat.gradient}/10 backdrop-blur-xl p-5 overflow-hidden`}
              >
                {/* Shine Effect */}
                <div className="absolute inset-0 opacity-0 group-hover:opacity-20 transition-opacity">
                  <div className="absolute inset-0 bg-gradient-to-r from-white/0 via-white/50 to-white/0 -translate-x-full group-hover:translate-x-full transition-transform duration-500" />
                </div>

                <div className="relative z-10 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-3xl">{stat.icon}</span>
                    <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">
                      {stat.label}
                    </span>
                  </div>

                  <p className="text-2xl font-black bg-gradient-to-r from-white to-gray-300 bg-clip-text text-transparent">
                    {stat.value}
                  </p>

                  {stat.percent !== undefined && (
                    <div className="relative h-2 rounded-full bg-white/5 border border-white/10 overflow-hidden">
                      <motion.div
                        className={`absolute inset-y-0 left-0 bg-gradient-to-r ${stat.gradient}`}
                        initial={{ width: 0 }}
                        animate={{ width: `${stat.percent}%` }}
                        transition={{ duration: 0.8 }}
                      />
                    </div>
                  )}
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>

        {/* ===== Premium Quick Actions (4 Primary) ===== */}
        <motion.div variants={itemVariants} className="grid grid-cols-4 gap-3">
          {PRIMARY_ACTIONS.map((action, idx) => (
            <motion.button
              key={action.path}
              whileHover={{ scale: 1.12, y: -4 }}
              whileTap={{ scale: 0.88 }}
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 + idx * 0.08 }}
              onClick={() => router.push(action.path)}
              disabled={inHospital && ["/dungeon", "/pvp"].includes(action.path)}
              className="relative group disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {/* Glow Background */}
              <div className="absolute -inset-1 bg-gradient-to-r from-blue-600/20 to-purple-600/20 rounded-2xl blur-lg opacity-0 group-hover:opacity-100 transition-all duration-300" />

              {/* Button */}
              <div className="relative rounded-2xl border border-white/20 bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl p-4 flex flex-col items-center gap-2.5 transition-all">
                {/* Gradient Overlay */}
                <div className="absolute inset-0 bg-gradient-to-b from-white/10 to-transparent opacity-0 group-hover:opacity-100 rounded-2xl transition-opacity" />

                {/* Icon */}
                <motion.span className="text-4xl relative z-10 group-hover:scale-125 transition-transform duration-300">
                  {action.icon}
                </motion.span>

                {/* Label */}
                <span className="text-xs font-bold text-gray-100 text-center leading-tight relative z-10 uppercase tracking-wider">
                  {action.label}
                </span>
              </div>
            </motion.button>
          ))}
        </motion.div>

        {/* ===== Active Quests (Premium) ===== */}
        {activeQuests.length > 0 && (
          <motion.div variants={itemVariants} className="space-y-4">
            <div className="flex items-center justify-between px-2">
              <h2 className="text-lg font-black bg-gradient-to-r from-white to-blue-200 bg-clip-text text-transparent flex items-center gap-2">
                🎯 Aktif Görevler
              </h2>
              <Link href="/quest" className="text-xs text-blue-400 hover:text-blue-300 transition-colors font-bold uppercase tracking-wider">
                Tümünü Gör →
              </Link>
            </div>

            <div className="space-y-3">
              {activeQuests.map((quest, idx) => {
                const pct = quest.goal > 0 ? (quest.progress / quest.goal) * 100 : 0;
                return (
                  <motion.div
                    key={quest.id}
                    initial={{ opacity: 0, x: -30 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.5 + idx * 0.08 }}
                    whileHover={{ x: 4 }}
                    className="relative group"
                  >
                    {/* Glow on Hover */}
                    <div className="absolute -inset-2 bg-gradient-to-r from-blue-600/20 to-cyan-600/20 rounded-2xl blur-lg opacity-0 group-hover:opacity-100 transition-opacity" />

                    <div className="relative rounded-2xl border border-blue-500/40 bg-gradient-to-r from-blue-600/15 to-cyan-600/10 backdrop-blur-lg p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          {quest.icon && <span className="text-2xl">{quest.icon}</span>}
                          <span className="font-bold text-white">{quest.title}</span>
                        </div>
                        <motion.span
                          className="text-xs font-black bg-gradient-to-r from-blue-400 to-cyan-300 bg-clip-text text-transparent"
                          key={pct}
                        >
                          {Math.round(pct)}%
                        </motion.span>
                      </div>

                      <div className="space-y-1.5">
                        <div className="relative h-3 rounded-full bg-white/5 border border-white/10 overflow-hidden">
                          <motion.div
                            className="absolute inset-y-0 left-0 bg-gradient-to-r from-blue-500 via-purple-500 to-cyan-400"
                            initial={{ width: 0 }}
                            animate={{ width: `${pct}%` }}
                            transition={{ duration: 0.8 }}
                          />
                        </div>
                        <div className="flex justify-between text-xs text-gray-400">
                          <span>{quest.progress}/{quest.goal} completed</span>
                        </div>
                      </div>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          </motion.div>
        )}

        {/* ===== Premium Potion Quick Action ===== */}
        <motion.button
          variants={itemVariants}
          whileHover={{ scale: 1.02, y: -2 }}
          whileTap={{ scale: 0.98 }}
          onClick={() => setShowPotionModal(true)}
          className="relative w-full group overflow-hidden"
        >
          {/* Glow */}
          <div className="absolute -inset-1 bg-gradient-to-r from-emerald-600/40 via-green-600/30 to-emerald-600/40 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-all duration-300" />

          <div className="relative rounded-2xl border border-emerald-500/40 bg-gradient-to-r from-emerald-600/20 to-green-600/10 backdrop-blur-xl px-6 py-4 flex items-center gap-4">
            <span className="text-3xl">🧪</span>
            <div className="flex-1 text-left">
              <p className="text-sm font-bold text-white">İksir Kullan</p>
              <p className="text-xs text-gray-300">
                {potionItems.length} mevcut • Enerji yenile
              </p>
            </div>
            <span className="text-white/60 group-hover:text-white transition-colors">›</span>
          </div>
        </motion.button>

        {/* ===== Secondary Quick Actions (expandable) ===== */}
        <motion.div variants={itemVariants} className="space-y-2">
          <AnimatePresence>
            {showAllActions && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: "auto" }}
                exit={{ opacity: 0, height: 0 }}
                className="overflow-hidden"
              >
                <div className="grid grid-cols-4 gap-2 pb-3">
                  {SECONDARY_ACTIONS.map((action, idx) => (
                    <motion.button
                      key={action.path}
                      whileHover={{ scale: 1.08 }}
                      whileTap={{ scale: 0.92 }}
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ delay: idx * 0.03 }}
                      onClick={() => router.push(action.path)}
                      className="flex flex-col items-center gap-2 px-2 py-3 rounded-xl border border-white/10 hover:border-white/20 bg-gradient-to-br from-white/5 to-white/[0.02] backdrop-blur-lg text-white transition-all group overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-br from-white/0 to-white/5 opacity-0 group-hover:opacity-100 transition-opacity" />
                      <span className="text-2xl relative z-10">{action.icon}</span>
                      <span className="text-[10px] font-bold text-center leading-tight relative z-10 text-gray-200">
                        {action.label}
                      </span>
                    </motion.button>
                  ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <button
            onClick={() => setShowAllActions(!showAllActions)}
            className="w-full py-2 text-xs font-semibold text-gray-400 hover:text-gray-300 transition-colors"
          >
            {showAllActions ? "▲ Daha Az Göster" : "▼ Tüm Özellikler"}
          </button>
        </motion.div>

        {/* ===== Recent Activity (Premium) ===== */}
        <motion.div variants={itemVariants} className="space-y-4">
          <h2 className="text-lg font-black bg-gradient-to-r from-white to-orange-200 bg-clip-text text-transparent px-2">
            ⏱️ Son Aktivite
          </h2>
          <div className="space-y-2">
            {[
              { icon: "⚔️", text: "Karanlık Orman Zindanı tamamlandı", time: "5 dk", color: "from-green-600 to-emerald-600" },
              { icon: "🛒", text: "Demir Kılıç satın alındı — 2.500 🪙", time: "18 dk", color: "from-blue-600 to-cyan-600" },
              { icon: "🔥", text: "Levha +7 Başarılı Geliştirme", time: "1 s", color: "from-red-600 to-orange-600" },
            ].map((activity, idx) => (
              <motion.div
                key={idx}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.65 + idx * 0.05 }}
                whileHover={{ x: 4 }}
                className="flex items-center gap-3 px-4 py-3 rounded-xl border border-white/10 bg-gradient-to-r from-white/5 to-white/[0.02] backdrop-blur-lg hover:border-white/20 transition-all group"
              >
                <span className="text-lg">{activity.icon}</span>
                <span className="flex-1 text-sm text-gray-200 group-hover:text-white transition-colors">
                  {activity.text}
                </span>
                <span className="text-xs text-gray-500">{activity.time}</span>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </motion.div>

      {/* ========== Potion Modal ========== */}
      <Modal isOpen={showPotionModal} onClose={() => setShowPotionModal(false)} title="🧪 İksir Kullan">
        <div className="space-y-3">
          <div className="text-xs text-gray-400 bg-slate-800/50 px-3 py-2 rounded-lg">
            <p>
              <strong>Tolerans:</strong> %{Math.round(potionTolerance)} • <strong>Enerji:</strong> {energy}/{maxEnergy}
            </p>
          </div>

          {potionItems.length === 0 ? (
            <div className="text-center py-6 space-y-3">
              <p className="text-4xl">🫙</p>
              <p className="text-sm text-gray-400">Envanterde iksir bulunamadı</p>
              <Link href="/shop" onClick={() => setShowPotionModal(false)}>
                <Button className="w-full text-sm">Mağazaya Git</Button>
              </Link>
            </div>
          ) : (
            <div className="space-y-2 max-h-64 overflow-y-auto">
              {potionItems.map((item) => (
                <motion.button
                  key={item.row_id}
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => handleUsePotion(item)}
                  disabled={usingPotionId !== null}
                  className="w-full flex items-center gap-3 p-3 rounded-xl border border-emerald-500/30 bg-gradient-to-r from-emerald-600/10 to-green-600/5 backdrop-blur-lg text-white hover:border-emerald-500/50 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <ItemIcon
                    itemId={item.item_id}
                    className="text-2xl shrink-0"
                  />
                  <div className="flex-1 text-left min-w-0">
                    <p className="font-semibold text-sm text-white truncate">{item.name}</p>
                    <div className="flex gap-2 mt-0.5">
                      {item.energy_restore && item.energy_restore > 0 && (
                        <span className="text-xs text-cyan-300">+{item.energy_restore} ⚡</span>
                      )}
                      {item.tolerance_increase && item.tolerance_increase > 0 && (
                        <span className="text-xs text-orange-300">+{item.tolerance_increase} 🧪</span>
                      )}
                    </div>
                  </div>
                  <div className="text-right shrink-0">
                    <p className="text-xs text-gray-400">×{item.quantity}</p>
                    {usingPotionId === item.item_id && (
                      <p className="text-xs text-blue-400 animate-pulse mt-0.5">Kullanılıyor...</p>
                    )}
                  </div>
                </motion.button>
              ))}
            </div>
          )}
        </div>
      </Modal>
    </div>
  );
}
