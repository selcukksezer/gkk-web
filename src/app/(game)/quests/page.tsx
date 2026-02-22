// ============================================================
// Quests Page — Kaynak: scenes/ui/screens/QuestScreen.gd
// Quest list with filters: Tümü, Müsait, Aktif, Tamamlanan
// ============================================================

"use client";

import { useEffect, useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { api } from "@/lib/api";
import { formatGold } from "@/lib/utils/string";
import type { QuestData, QuestStatus, QuestDifficulty } from "@/types/quest";

type QuestFilter = "all" | "available" | "active" | "completed";

const FILTERS: { key: QuestFilter; label: string }[] = [
  { key: "all", label: "Tümü" },
  { key: "available", label: "Müsait" },
  { key: "active", label: "Aktif" },
  { key: "completed", label: "Tamamlanan" },
];

const difficultyConfig: Record<QuestDifficulty, { label: string; color: string; emoji: string }> = {
  easy: { label: "Kolay", color: "var(--color-success)", emoji: "🟢" },
  medium: { label: "Orta", color: "var(--color-warning)", emoji: "🟡" },
  hard: { label: "Zor", color: "var(--color-error)", emoji: "🔴" },
  elite: { label: "Elit", color: "var(--rarity-epic)", emoji: "🟣" },
  dungeon: { label: "Zindan", color: "var(--rarity-legendary)", emoji: "💀" },
};

export default function QuestsPage() {
  const energy = usePlayerStore((s) => s.energy);
  const level = usePlayerStore((s) => s.level);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const addToast = useUiStore((s) => s.addToast);

  const [quests, setQuests] = useState<QuestData[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeFilter, setActiveFilter] = useState<QuestFilter>("all");
  const [selectedQuest, setSelectedQuest] = useState<QuestData | null>(null);
  const [isStarting, setIsStarting] = useState(false);

  useEffect(() => {
    loadQuests();
  }, []);

  const loadQuests = async () => {
    setIsLoading(true);
    try {
      const res = await api.rpc<QuestData[]>("get_available_quests", { p_player_level: level });
      setQuests(res.data || []);
    } catch {
      addToast("Görevler yüklenemedi", "error");
    } finally {
      setIsLoading(false);
    }
  };

  const filteredQuests = useMemo(() => {
    if (activeFilter === "all") return quests;
    return quests.filter((q) => q.status === activeFilter);
  }, [quests, activeFilter]);

  const handleStartQuest = async (quest: QuestData) => {
    if (quest.energy_cost > energy) {
      addToast("Yeterli enerji yok", "warning");
      return;
    }
    setIsStarting(true);
    try {
      await api.rpc("start_quest", { p_quest_id: quest.quest_id });
      consumeEnergy(quest.energy_cost);
      addToast(`${quest.name} başlatıldı!`, "success");
      await loadQuests();
    } catch {
      addToast("Görev başlatılamadı", "error");
    } finally {
      setIsStarting(false);
    }
  };

  const activeCount = useMemo(() => quests.filter((q) => q.status === "active").length, [quests]);
  const maxActiveQuests = 5; // Godot: quest_manager.max_active_quests

  return (
    <div className="p-4 space-y-4 pb-24">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-[var(--text-primary)]">📜 Görevler</h2>
        {/* Godot: "Aktif Görevler: X/Y" label */}
        <span className={`text-xs font-medium ${activeCount >= maxActiveQuests ? "text-[var(--color-error)]" : "text-[var(--text-secondary)]"}`}>
          Aktif: {activeCount}/{maxActiveQuests}
        </span>
      </div>

      {/* Filters */}
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
            {f.label}
          </button>
        ))}
      </div>

      {/* Quest List */}
      {isLoading ? (
        <div className="text-center text-sm text-[var(--text-muted)] py-8">
          Yükleniyor...
        </div>
      ) : filteredQuests.length === 0 ? (
        <div className="text-center text-sm text-[var(--text-muted)] py-8">
          Görev bulunamadı
        </div>
      ) : (
        <motion.div className="space-y-2" layout>
          <AnimatePresence mode="popLayout">
            {filteredQuests.map((quest) => (
              <motion.div
                key={quest.quest_id}
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
              >
                <Card
                  onClick={() =>
                    setSelectedQuest(
                      selectedQuest?.quest_id === quest.quest_id ? null : quest
                    )
                  }
                >
                  <div className="p-3">
                    <div className="flex items-center justify-between mb-1">
                      <h4 className="text-sm font-semibold text-[var(--text-primary)]">
                        {quest.name}
                      </h4>
                      <span className="text-xs" style={{ color: difficultyConfig[quest.difficulty]?.color }}>
                        {difficultyConfig[quest.difficulty]?.emoji}{" "}
                        {difficultyConfig[quest.difficulty]?.label}
                      </span>
                    </div>

                    <p className="text-xs text-[var(--text-muted)] mb-2 line-clamp-2">
                      {quest.description}
                    </p>

                    <div className="flex items-center justify-between text-xs text-[var(--text-secondary)]">
                      <span>⚡ {quest.energy_cost} enerji</span>
                      <span>🪙 {formatGold(quest.gold_reward)} altın</span>
                      <span>✨ {quest.xp_reward} XP</span>
                    </div>

                    {/* Expanded detail */}
                    <AnimatePresence>
                      {selectedQuest?.quest_id === quest.quest_id && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: "auto", opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          className="overflow-hidden"
                        >
                          <div className="mt-3 pt-3 border-t border-[var(--border-subtle)]">
                            {quest.required_level > level && (
                              <p className="text-xs text-[var(--color-error)] mb-2">
                                ⚠️ Seviye {quest.required_level} gerekli
                              </p>
                            )}
                            {quest.status === "available" && (
                              <Button
                                variant="primary"
                                size="sm"
                                fullWidth
                                isLoading={isStarting}
                                disabled={quest.energy_cost > energy || quest.required_level > level}
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleStartQuest(quest);
                                }}
                              >
                                Görevi Başlat
                              </Button>
                            )}
                            {quest.status === "active" && (
                              <ProgressBar
                                value={quest.progress || 0}
                                max={quest.progress_max || 1}
                                color="accent"
                                size="sm"
                                label={`İlerleme: ${quest.progress || 0}/${quest.progress_max || 1}`}
                              />
                            )}
                            {quest.status === "completed" && (
                              <p className="text-xs text-[var(--color-success)] text-center">
                                ✅ Tamamlandı
                              </p>
                            )}
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </div>
                </Card>
              </motion.div>
            ))}
          </AnimatePresence>
        </motion.div>
      )}
    </div>
  );
}
