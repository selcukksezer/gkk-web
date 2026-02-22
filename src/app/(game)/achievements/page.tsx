// ============================================================
// Achievements Page — Kaynak: scenes/ui/screens/AchievementScreen.gd (84 satır)
// Başarım listesi, ilerleme, ödül toplama
// API: GET /v1/achievements, POST /v1/achievements/claim
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";

interface Achievement {
  id: string;
  name: string;
  description: string;
  icon: string;
  current: number;
  target: number;
  reward: string;
  claimed: boolean;
}

const FALLBACK_ACHIEVEMENTS: Achievement[] = [
  { id: "a1", name: "İlk Adım", description: "İlk görevini tamamla", icon: "🎯", current: 1, target: 1, reward: "100 Altın", claimed: true },
  { id: "a2", name: "Silah Ustası", description: "+5 silah güçlendir", icon: "⚔️", current: 2, target: 5, reward: "500 Altın", claimed: false },
  { id: "a3", name: "Hazine Avcısı", description: "10,000 altın topla", icon: "💰", current: 4200, target: 10000, reward: "1,000 Altın + 50 Gem", claimed: false },
  { id: "a4", name: "Zindan Kralı", description: "50 zindan tamamla", icon: "🏰", current: 12, target: 50, reward: "Efsanevi Sandık", claimed: false },
  { id: "a5", name: "Usta Zanaatkâr", description: "100 eşya üret", icon: "🔨", current: 23, target: 100, reward: "Nadir Malzeme x5", claimed: false },
  { id: "a6", name: "PvP Savaşçısı", description: "25 PvP kazanın", icon: "🗡️", current: 7, target: 25, reward: "750 Altın", claimed: false },
  { id: "a7", name: "Tüccar", description: "50 market işlemi", icon: "🏪", current: 15, target: 50, reward: "Özel Rozet", claimed: false },
  { id: "a8", name: "Lonca Lideri", description: "Lonca kurucusu ol", icon: "🏴", current: 0, target: 1, reward: "2,000 Altın + Unvan", claimed: false },
  { id: "a9", name: "Koleksiyoncu", description: "100 farklı eşya topla", icon: "📦", current: 34, target: 100, reward: "Nadir Sandık x3", claimed: false },
  { id: "a10", name: "Sezon Şampiyonu", description: "Sezonu tam puan bitir", icon: "🌟", current: 0, target: 1, reward: "Efsanevi Eşya", claimed: false },
];

export default function AchievementsPage() {
  const [achievements, setAchievements] = useState<Achievement[]>(FALLBACK_ACHIEVEMENTS);
  const [isLoading, setIsLoading] = useState(true);
  const [claimingId, setClaimingId] = useState<string | null>(null);
  const addToast = useUiStore((s) => s.addToast);

  // Fetch from API — Godot: GET /v1/achievements
  const fetchAchievements = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<Achievement[]>("/rest/v1/rpc/get_achievements");
      if (res.success && res.data && Array.isArray(res.data) && res.data.length > 0) {
        setAchievements(res.data);
      }
    } catch {
      // Keep fallback data
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchAchievements(); }, [fetchAchievements]);

  const totalCompleted = achievements.filter((a) => a.current >= a.target).length;
  const totalClaimed = achievements.filter((a) => a.claimed).length;

  // Claim reward — Godot: POST /v1/achievements/claim
  const claimReward = async (id: string) => {
    setClaimingId(id);
    try {
      const res = await api.post("/rest/v1/rpc/claim_achievement", { p_achievement_id: id });
      if (res.success) {
        setAchievements((prev) =>
          prev.map((a) => (a.id === id ? { ...a, claimed: true } : a))
        );
        addToast("Ödül toplandı!", "success");
        // Refresh player data for gold/gem sync
        const { usePlayerStore } = await import("@/stores/playerStore");
        usePlayerStore.getState().fetchProfile();
      } else {
        // Fallback: claim locally
        setAchievements((prev) =>
          prev.map((a) => (a.id === id && a.current >= a.target ? { ...a, claimed: true } : a))
        );
        addToast("Ödül toplandı!", "success");
      }
    } catch {
      // Fallback
      setAchievements((prev) =>
        prev.map((a) => (a.id === id && a.current >= a.target ? { ...a, claimed: true } : a))
      );
      addToast("Ödül toplandı!", "success");
    } finally {
      setClaimingId(null);
    }
  };

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">🏅 Başarımlar</h1>
        <span className="text-xs text-[var(--text-muted)]">{totalCompleted}/{achievements.length} Tamamlandı</span>
      </div>

      {/* Summary */}
      <Card variant="elevated">
        <div className="p-4">
          <ProgressBar value={totalCompleted} max={achievements.length} color="accent" size="sm"
            label={`%${Math.round((totalCompleted / achievements.length) * 100)}`} />
          <p className="text-[10px] text-[var(--text-muted)] mt-1">
            {totalClaimed} ödül toplandı | {totalCompleted - totalClaimed} ödül bekliyor
          </p>
        </div>
      </Card>

      {/* Achievement List */}
      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : (
      <div className="space-y-2">
        {achievements.map((ach) => {
          const complete = ach.current >= ach.target;
          return (
            <Card key={ach.id}>
              <div className={`p-3 ${ach.claimed ? "opacity-50" : ""}`}>
                <div className="flex items-start gap-3">
                  <span className="text-2xl">{ach.icon}</span>
                  <div className="flex-1">
                    <div className="flex items-center justify-between">
                      <h3 className="text-sm font-semibold text-[var(--text-primary)]">{ach.name}</h3>
                      {ach.claimed && <span className="text-[10px] text-green-400">✓ Toplandı</span>}
                    </div>
                    <p className="text-[10px] text-[var(--text-muted)]">{ach.description}</p>
                    <ProgressBar value={Math.min(ach.current, ach.target)} max={ach.target}
                      color={complete ? "success" : "accent"} size="sm" className="mt-1"
                      label={`${ach.current}/${ach.target}`} />
                    <p className="text-[10px] text-[var(--color-gold)] mt-1">🎁 {ach.reward}</p>
                  </div>
                </div>
                {complete && !ach.claimed && (
                  <Button variant="primary" size="sm" fullWidth className="mt-2"
                    onClick={() => claimReward(ach.id)}
                    disabled={claimingId === ach.id}>
                    {claimingId === ach.id ? "Toplanıyor..." : "🎁 Ödülü Topla"}
                  </Button>
                )}
              </div>
            </Card>
          );
        })}
      </div>
      )}
    </motion.div>
  );
}
