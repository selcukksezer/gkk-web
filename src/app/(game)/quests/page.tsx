// ============================================================
// Quests Page — Kaynak: scenes/ui/screens/QuestScreen.gd
// Filtreler: Tümü, Müsait, Aktif, Tamamlanan
// Görev detay modal, hedef listesi, ödül talebi, otomatik yenileme
// ============================================================

"use client";

import { useEffect, useState, useMemo, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { api } from "@/lib/api";
import { formatGold } from "@/lib/utils/string";
import type { QuestData, QuestStatus, QuestDifficulty } from "@/types/quest";

// ── Quest filter type (mirrors QuestScreen.gd QuestFilter enum) ──
type QuestFilter = "all" | "available" | "active" | "completed";

const FILTERS: { key: QuestFilter; label: string; emoji: string }[] = [
  { key: "all", label: "Tümü", emoji: "📋" },
  { key: "available", label: "Müsait", emoji: "🟢" },
  { key: "active", label: "Aktif", emoji: "⚡" },
  { key: "completed", label: "Tamamlanan", emoji: "✅" },
];

const difficultyConfig: Record<QuestDifficulty, { label: string; color: string; emoji: string; bg: string }> = {
  easy: { label: "Kolay", color: "var(--color-success)", emoji: "🟢", bg: "var(--color-success)" },
  medium: { label: "Orta", color: "var(--color-warning)", emoji: "🟡", bg: "var(--color-warning)" },
  hard: { label: "Zor", color: "var(--color-error)", emoji: "🔴", bg: "var(--color-error)" },
  elite: { label: "Elit", color: "var(--rarity-epic)", emoji: "🟣", bg: "var(--rarity-epic)" },
  dungeon: { label: "Zindan", color: "var(--rarity-legendary)", emoji: "💀", bg: "var(--rarity-legendary)" },
};

const statusConfig: Record<QuestStatus, { label: string; color: string; bg: string }> = {
  available: { label: "Müsait", color: "var(--color-success)", bg: "var(--color-success)20" },
  active: { label: "Aktif", color: "var(--color-warning)", bg: "var(--color-warning)20" },
  completed: { label: "Tamamlandı", color: "var(--accent-light)", bg: "var(--accent)20" },
  failed: { label: "Başarısız", color: "var(--color-error)", bg: "var(--color-error)20" },
};

// Mock objectives per quest (Godot: QuestObjective[])
interface QuestObjective {
  id: string;
  description: string;
  current: number;
  required: number;
  completed: boolean;
}

function buildObjectives(quest: QuestData): QuestObjective[] {
  if (quest.status === "available") {
    return [
      { id: "obj1", description: "Görevi kabul et", current: 0, required: 1, completed: false },
    ];
  }
  const base: QuestObjective[] = [
    {
      id: "obj1",
      description: "Ana hedefi tamamla",
      current: Math.min(quest.progress || 0, quest.progress_max || 1),
      required: quest.progress_max || 1,
      completed: (quest.progress || 0) >= (quest.progress_max || 1),
    },
  ];
  if (quest.status === "completed") {
    base[0].completed = true;
    base[0].current = base[0].required;
  }
  return base;
}

// Realistic fallback quest data (Godot: QuestManager.fallback_quests)
const FALLBACK_QUESTS: QuestData[] = [
  {
    id: "q1",
    quest_id: "q1",
    name: "Acemi Savaşçı",
    description: "Başlangıç Köyü'nün çevresinde dolaşan 5 canavar öldür ve köyü tehlikelerden kurtar.",
    difficulty: "easy",
    required_level: 1,
    energy_cost: 5,
    gold_reward: 200,
    xp_reward: 150,
    gem_reward: 0,
    item_rewards: ["iron_sword"],
    status: "available",
    progress: 0,
    progress_max: 5,
    target: 5,
    expires_at: null,
  },
  {
    id: "q2",
    quest_id: "q2",
    name: "Kayıp Tüccar",
    description: "Orman Bölgesi'nde kaybolan tüccarı bul ve güvenli şekilde kasabaya geri getir.",
    difficulty: "easy",
    required_level: 2,
    energy_cost: 8,
    gold_reward: 350,
    xp_reward: 200,
    gem_reward: 0,
    item_rewards: ["health_potion"],
    status: "active",
    progress: 1,
    progress_max: 3,
    target: 3,
    expires_at: null,
  },
  {
    id: "q3",
    quest_id: "q3",
    name: "Maden Keşfi",
    description: "Dağ Geçidi'ndeki eski madeninleri araştır ve 10 adet demir cevheri topla.",
    difficulty: "medium",
    required_level: 5,
    energy_cost: 15,
    gold_reward: 750,
    xp_reward: 400,
    gem_reward: 1,
    item_rewards: ["res_mining_common", "pickaxe"],
    status: "available",
    progress: 0,
    progress_max: 10,
    target: 10,
    expires_at: null,
  },
  {
    id: "q4",
    quest_id: "q4",
    name: "Korsanları Durdur",
    description: "Liman Kenti'ne saldıran korsan çetesinin lideri Demir Kanca'yı etkisiz hale getir.",
    difficulty: "hard",
    required_level: 10,
    energy_cost: 25,
    gold_reward: 2000,
    xp_reward: 800,
    gem_reward: 3,
    item_rewards: ["pirate_sword", "sea_chart"],
    status: "available",
    progress: 0,
    progress_max: 1,
    target: 1,
    expires_at: null,
  },
  {
    id: "q5",
    quest_id: "q5",
    name: "Ejderha'nın Laneti",
    description: "Ejderha Yurdu'nda uyanmak üzere olan kadim ejderhayı uyutmak için büyülü taşları topla.",
    difficulty: "elite",
    required_level: 20,
    energy_cost: 35,
    gold_reward: 5000,
    xp_reward: 1500,
    gem_reward: 10,
    item_rewards: ["dragon_scale", "magic_stone"],
    status: "active",
    progress: 2,
    progress_max: 5,
    target: 5,
    expires_at: null,
  },
  {
    id: "q6",
    quest_id: "q6",
    name: "Karanlık Tapınak",
    description: "Lanetli Topraklar'daki karanlık tapınakta gizlenen karabüyücüyü mağlup et.",
    difficulty: "dungeon",
    required_level: 15,
    energy_cost: 30,
    gold_reward: 3500,
    xp_reward: 1000,
    gem_reward: 5,
    item_rewards: ["dark_crystal", "cursed_tome"],
    status: "completed",
    progress: 1,
    progress_max: 1,
    target: 1,
    expires_at: null,
  },
  {
    id: "q7",
    quest_id: "q7",
    name: "Şifa Otu Toplama",
    description: "Şifacı için Orman Bölgesi'nden 15 adet nadir şifa otu topla.",
    difficulty: "easy",
    required_level: 1,
    energy_cost: 6,
    gold_reward: 180,
    xp_reward: 100,
    gem_reward: 0,
    item_rewards: ["herb_bundle"],
    status: "available",
    progress: 0,
    progress_max: 15,
    target: 15,
    expires_at: null,
  },
  {
    id: "q8",
    quest_id: "q8",
    name: "Dağ Geçidi Temizleme",
    description: "Ticaret yolunu bloke eden kaya devlerini temizle ve geçidi güvenli hale getir.",
    difficulty: "medium",
    required_level: 8,
    energy_cost: 20,
    gold_reward: 1200,
    xp_reward: 600,
    gem_reward: 2,
    item_rewards: ["stone_shield"],
    status: "completed",
    progress: 3,
    progress_max: 3,
    target: 3,
    expires_at: null,
  },
];

export default function QuestsPage() {
  const energy = usePlayerStore((s) => s.energy);
  const level = usePlayerStore((s) => s.level);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const addToast = useUiStore((s) => s.addToast);

  const [quests, setQuests] = useState<QuestData[]>(FALLBACK_QUESTS);
  const [isLoading, setIsLoading] = useState(false);
  const [activeFilter, setActiveFilter] = useState<QuestFilter>("all");
  const [selectedQuest, setSelectedQuest] = useState<QuestData | null>(null);
  const [detailOpen, setDetailOpen] = useState(false);
  const [isStarting, setIsStarting] = useState(false);
  const [isCompleting, setIsCompleting] = useState(false);
  const [isClaiming, setIsClaiming] = useState(false);

  const loadQuests = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.rpc<QuestData[]>("get_available_quests", { p_player_level: level });
      if (res.success && res.data && res.data.length > 0) {
        setQuests(res.data);
      }
      // else keep fallback data
    } catch {
      // keep fallback data
    } finally {
      setIsLoading(false);
    }
  }, [level]);

  useEffect(() => {
    loadQuests();
  }, [loadQuests]);

  // Auto-refresh when filter changes
  useEffect(() => {
    loadQuests();
  }, [activeFilter, loadQuests]);

  const filteredQuests = useMemo(() => {
    if (activeFilter === "all") return quests;
    return quests.filter((q) => q.status === activeFilter);
  }, [quests, activeFilter]);

  const activeCount = useMemo(() => quests.filter((q) => q.status === "active").length, [quests]);
  const completedCount = useMemo(() => quests.filter((q) => q.status === "completed").length, [quests]);
  const maxActiveQuests = 5; // Godot: quest_manager.max_active_quests

  const handleStartQuest = async (quest: QuestData) => {
    if (activeCount >= maxActiveQuests) {
      addToast(`Maksimum ${maxActiveQuests} aktif görev! Önce mevcut görevleri tamamla.`, "warning");
      return;
    }
    if (quest.required_level > level) {
      addToast(`Bu görev için seviye ${quest.required_level} gerekli!`, "warning");
      return;
    }
    if (quest.energy_cost > energy) {
      addToast("Yeterli enerji yok!", "warning");
      return;
    }
    setIsStarting(true);
    try {
      await api.rpc("start_quest", { p_quest_id: quest.quest_id });
      consumeEnergy(quest.energy_cost);
      addToast(`"${quest.name}" görevi başlatıldı!`, "success");
      setQuests((prev) =>
        prev.map((q) => (q.quest_id === quest.quest_id ? { ...q, status: "active" as QuestStatus } : q))
      );
    } catch {
      addToast("Görev başlatılamadı", "error");
    } finally {
      setIsStarting(false);
      setDetailOpen(false);
    }
  };

  const handleCompleteQuest = async (quest: QuestData) => {
    setIsCompleting(true);
    try {
      await api.rpc("complete_quest", { p_quest_id: quest.quest_id });
      addToast(`"${quest.name}" tamamlandı!`, "success");
      setQuests((prev) =>
        prev.map((q) => (q.quest_id === quest.quest_id ? { ...q, status: "completed" as QuestStatus } : q))
      );
    } catch {
      addToast("Görev tamamlanamadı", "error");
    } finally {
      setIsCompleting(false);
    }
  };

  const handleClaimReward = async (quest: QuestData) => {
    setIsClaiming(true);
    try {
      await api.rpc("claim_quest_reward", { p_quest_id: quest.quest_id });
      addToast(`Ödül alındı: 🪙${formatGold(quest.gold_reward)} + ✨${quest.xp_reward} XP`, "success");
      setQuests((prev) => prev.filter((q) => q.quest_id !== quest.quest_id));
      setDetailOpen(false);
      setSelectedQuest(null);
    } catch {
      addToast("Ödül alınamadı", "error");
    } finally {
      setIsClaiming(false);
    }
  };

  const emptyMessages: Record<QuestFilter, string> = {
    all: "Henüz görev yok. Yenile veya bir sonraki seviyeye geç.",
    available: "Seviyene uygun müsait görev bulunmuyor.",
    active: "Henüz aktif görevin yok. Bir görev başlat!",
    completed: "Henüz tamamladığın bir görev yok.",
  };

  return (
    <div className="p-4 space-y-4 pb-24">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-[var(--text-primary)]">📜 Görevler</h2>
        <div className="flex items-center gap-2">
          <span
            className={`text-xs font-medium px-2 py-0.5 rounded-full ${
              activeCount >= maxActiveQuests
                ? "bg-[var(--color-error)]/20 text-[var(--color-error)]"
                : "bg-[var(--bg-input)] text-[var(--text-secondary)]"
            }`}
          >
            Aktif Görevler: {activeCount}/{maxActiveQuests}
          </span>
        </div>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-2 text-center">
        <div className="bg-[var(--bg-card)] rounded-xl p-2">
          <p className="text-lg font-bold text-[var(--text-primary)]">{quests.length}</p>
          <p className="text-[10px] text-[var(--text-muted)]">Toplam</p>
        </div>
        <div className="bg-[var(--color-warning)]/10 rounded-xl p-2">
          <p className="text-lg font-bold text-[var(--color-warning)]">{activeCount}</p>
          <p className="text-[10px] text-[var(--text-muted)]">Aktif</p>
        </div>
        <div className="bg-[var(--color-success)]/10 rounded-xl p-2">
          <p className="text-lg font-bold text-[var(--color-success)]">{completedCount}</p>
          <p className="text-[10px] text-[var(--text-muted)]">Tamamlanan</p>
        </div>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-1 overflow-x-auto no-scrollbar">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            onClick={() => setActiveFilter(f.key)}
            className={`flex-shrink-0 px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              activeFilter === f.key
                ? "bg-[var(--accent)] text-white"
                : "bg-[var(--bg-card)] text-[var(--text-secondary)] border border-[var(--border-default)]"
            }`}
          >
            {f.emoji} {f.label}
            {f.key === "active" && activeCount > 0 && (
              <span className="ml-1 bg-white/20 text-white text-[9px] px-1 rounded-full">{activeCount}</span>
            )}
          </button>
        ))}
      </div>

      {/* Quest list */}
      {isLoading ? (
        <div className="text-center text-sm text-[var(--text-muted)] py-12">
          <div className="text-2xl mb-2">⏳</div>
          Görevler yükleniyor...
        </div>
      ) : filteredQuests.length === 0 ? (
        <div className="text-center text-sm text-[var(--text-muted)] py-12">
          <div className="text-3xl mb-2">📭</div>
          <p>{emptyMessages[activeFilter]}</p>
        </div>
      ) : (
        <motion.div className="space-y-3" layout>
          <AnimatePresence mode="popLayout">
            {filteredQuests.map((quest) => {
              const diff = difficultyConfig[quest.difficulty];
              const status = statusConfig[quest.status];
              const objectives = buildObjectives(quest);
              const progressPct =
                quest.progress_max > 0
                  ? Math.round((quest.progress / quest.progress_max) * 100)
                  : 0;
              const canStart =
                quest.status === "available" &&
                quest.required_level <= level &&
                quest.energy_cost <= energy &&
                activeCount < maxActiveQuests;

              return (
                <motion.div
                  key={quest.quest_id}
                  layout
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                >
                  <Card variant="elevated">
                    <div className="p-4">
                      {/* Quest header */}
                      <div className="flex items-start justify-between mb-2 gap-2">
                        <div className="flex-1 min-w-0">
                          <h4 className="text-sm font-bold text-[var(--text-primary)] truncate">
                            {quest.name}
                          </h4>
                          <p className="text-xs text-[var(--text-muted)] mt-0.5 line-clamp-2">
                            {quest.description}
                          </p>
                        </div>
                        <div className="flex flex-col items-end gap-1 flex-shrink-0">
                          <span
                            className="text-[10px] font-semibold px-1.5 py-0.5 rounded"
                            style={{
                              color: diff.color,
                              backgroundColor: `${diff.bg}20`,
                            }}
                          >
                            {diff.emoji} {diff.label}
                          </span>
                          <span
                            className="text-[10px] font-medium px-1.5 py-0.5 rounded"
                            style={{
                              color: status.color,
                              backgroundColor: status.bg,
                            }}
                          >
                            {status.label}
                          </span>
                        </div>
                      </div>

                      {/* Rewards row */}
                      <div className="flex items-center gap-3 text-xs mb-2">
                        <span className="text-[var(--color-gold)]">🪙 {formatGold(quest.gold_reward)}</span>
                        <span className="text-[var(--accent-light)]">✨ {quest.xp_reward} XP</span>
                        {quest.gem_reward > 0 && (
                          <span className="text-[var(--rarity-epic)]">💎 {quest.gem_reward}</span>
                        )}
                        <span className="text-[var(--color-warning)] ml-auto">⚡ {quest.energy_cost}</span>
                      </div>

                      {/* Objectives */}
                      <div className="space-y-1 mb-2">
                        {objectives.map((obj) => (
                          <div key={obj.id} className="flex items-center gap-2">
                            <span className="text-xs">{obj.completed ? "☑️" : "☐"}</span>
                            <span
                              className={`text-xs flex-1 ${
                                obj.completed
                                  ? "text-[var(--color-success)] line-through opacity-70"
                                  : "text-[var(--text-secondary)]"
                              }`}
                            >
                              {obj.description}
                            </span>
                            {obj.required > 1 && (
                              <span className="text-[10px] text-[var(--text-muted)]">
                                {obj.current}/{obj.required}
                              </span>
                            )}
                          </div>
                        ))}
                      </div>

                      {/* Progress bar for active quests */}
                      {quest.status === "active" && quest.progress_max > 0 && (
                        <div className="mb-3">
                          <ProgressBar
                            value={quest.progress}
                            max={quest.progress_max}
                            color="accent"
                            size="sm"
                            label={`İlerleme: ${quest.progress}/${quest.progress_max} (%${progressPct})`}
                          />
                        </div>
                      )}

                      {/* Level requirement warning */}
                      {quest.required_level > level && (
                        <p className="text-xs text-[var(--color-error)] mb-2">
                          ⚠️ Seviye {quest.required_level} gerekli (mevcut: {level})
                        </p>
                      )}

                      {/* Action buttons */}
                      <div className="flex gap-2 mt-2">
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={() => {
                            setSelectedQuest(quest);
                            setDetailOpen(true);
                          }}
                        >
                          Detay
                        </Button>

                        {quest.status === "available" && (
                          <Button
                            variant={canStart ? "primary" : "secondary"}
                            size="sm"
                            className="flex-1"
                            disabled={!canStart}
                            isLoading={isStarting}
                            onClick={() => handleStartQuest(quest)}
                          >
                            {activeCount >= maxActiveQuests
                              ? "Slot Dolu"
                              : quest.required_level > level
                              ? `Sev. ${quest.required_level} Gerekli`
                              : quest.energy_cost > energy
                              ? "Enerji Yok"
                              : "Görevi Başlat"}
                          </Button>
                        )}

                        {quest.status === "active" && quest.progress >= quest.progress_max && (
                          <Button
                            variant="primary"
                            size="sm"
                            className="flex-1"
                            isLoading={isCompleting}
                            onClick={() => handleCompleteQuest(quest)}
                          >
                            ✅ Tamamla
                          </Button>
                        )}

                        {quest.status === "completed" && (
                          <Button
                            variant="primary"
                            size="sm"
                            className="flex-1"
                            isLoading={isClaiming}
                            onClick={() => handleClaimReward(quest)}
                          >
                            🎁 Ödülü Al
                          </Button>
                        )}

                        {quest.status === "active" && quest.progress < quest.progress_max && (
                          <div className="flex-1 flex items-center justify-center">
                            <span className="text-xs text-[var(--color-warning)]">
                              ⏳ Devam ediyor...
                            </span>
                          </div>
                        )}
                      </div>
                    </div>
                  </Card>
                </motion.div>
              );
            })}
          </AnimatePresence>
        </motion.div>
      )}

      {/* Refresh button */}
      <div className="flex justify-center pt-2">
        <button
          onClick={loadQuests}
          disabled={isLoading}
          className="text-xs text-[var(--text-muted)] hover:text-[var(--text-secondary)] transition-colors flex items-center gap-1"
        >
          🔄 Yenile
        </button>
      </div>

      {/* Quest Detail Modal */}
      <Modal
        isOpen={detailOpen}
        onClose={() => { setDetailOpen(false); setSelectedQuest(null); }}
        title={selectedQuest?.name ?? "Görev Detayı"}
        size="sm"
      >
        {selectedQuest && (
          <div className="space-y-4">
            {/* Difficulty + status badges */}
            <div className="flex items-center gap-2">
              <span
                className="text-xs font-semibold px-2 py-0.5 rounded"
                style={{
                  color: difficultyConfig[selectedQuest.difficulty].color,
                  backgroundColor: `${difficultyConfig[selectedQuest.difficulty].bg}20`,
                }}
              >
                {difficultyConfig[selectedQuest.difficulty].emoji}{" "}
                {difficultyConfig[selectedQuest.difficulty].label}
              </span>
              <span
                className="text-xs font-medium px-2 py-0.5 rounded"
                style={{
                  color: statusConfig[selectedQuest.status].color,
                  backgroundColor: statusConfig[selectedQuest.status].bg,
                }}
              >
                {statusConfig[selectedQuest.status].label}
              </span>
            </div>

            {/* Full description */}
            <p className="text-sm text-[var(--text-secondary)] leading-relaxed">
              {selectedQuest.description}
            </p>

            {/* All objectives */}
            <div>
              <h4 className="text-xs font-semibold text-[var(--text-muted)] mb-2">📋 HEDEFLER</h4>
              <div className="space-y-1">
                {buildObjectives(selectedQuest).map((obj) => (
                  <div key={obj.id} className="flex items-center gap-2 text-sm">
                    <span>{obj.completed ? "☑️" : "☐"}</span>
                    <span
                      className={
                        obj.completed
                          ? "text-[var(--color-success)] line-through opacity-70"
                          : "text-[var(--text-primary)]"
                      }
                    >
                      {obj.description}
                    </span>
                    {obj.required > 1 && (
                      <span className="ml-auto text-xs text-[var(--text-muted)]">
                        {obj.current}/{obj.required}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>

            {/* All rewards */}
            <div>
              <h4 className="text-xs font-semibold text-[var(--text-muted)] mb-2">🎁 ÖDÜLLER</h4>
              <div className="bg-[var(--bg-input)] rounded-xl p-3 space-y-1">
                <div className="flex justify-between text-sm">
                  <span className="text-[var(--text-muted)]">Altın</span>
                  <span className="text-[var(--color-gold)] font-semibold">
                    🪙 {formatGold(selectedQuest.gold_reward)}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-[var(--text-muted)]">Deneyim</span>
                  <span className="text-[var(--accent-light)] font-semibold">
                    ✨ {selectedQuest.xp_reward} XP
                  </span>
                </div>
                {selectedQuest.gem_reward > 0 && (
                  <div className="flex justify-between text-sm">
                    <span className="text-[var(--text-muted)]">Gem</span>
                    <span className="text-[var(--rarity-epic)] font-semibold">
                      💎 {selectedQuest.gem_reward}
                    </span>
                  </div>
                )}
                {selectedQuest.item_rewards.length > 0 && (
                  <div className="flex justify-between text-sm">
                    <span className="text-[var(--text-muted)]">Eşyalar</span>
                    <span className="text-[var(--text-primary)] text-xs">
                      {selectedQuest.item_rewards.map((r) => r.replace(/_/g, " ")).join(", ")}
                    </span>
                  </div>
                )}
              </div>
            </div>

            {/* Requirements */}
            <div className="flex items-center gap-4 text-xs text-[var(--text-muted)]">
              <span>📊 Min Seviye: {selectedQuest.required_level}</span>
              <span>⚡ Enerji: {selectedQuest.energy_cost}</span>
            </div>

            {/* Actions */}
            <div className="flex gap-2">
              <Button
                variant="secondary"
                size="sm"
                fullWidth
                onClick={() => { setDetailOpen(false); setSelectedQuest(null); }}
              >
                Kapat
              </Button>

              {selectedQuest.status === "available" && (
                <Button
                  variant="primary"
                  size="sm"
                  fullWidth
                  isLoading={isStarting}
                  disabled={
                    selectedQuest.required_level > level ||
                    selectedQuest.energy_cost > energy ||
                    activeCount >= maxActiveQuests
                  }
                  onClick={() => handleStartQuest(selectedQuest)}
                >
                  Başlat
                </Button>
              )}

              {selectedQuest.status === "completed" && (
                <Button
                  variant="primary"
                  size="sm"
                  fullWidth
                  isLoading={isClaiming}
                  onClick={() => handleClaimReward(selectedQuest)}
                >
                  🎁 Ödülü Al
                </Button>
              )}
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
