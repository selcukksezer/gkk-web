// ============================================================
// Season Page — Kaynak: scenes/ui/screens/SeasonScreen.gd
// Sezon ilerlemesi, mücadeleler, ödüller, battle pass
// ============================================================

"use client";

import { useEffect, useState, useCallback } from "react";
import { motion } from "framer-motion";
import { useSeason } from "@/hooks/useSeason";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";

interface SeasonChallenge {
  id: string;
  name: string;
  description: string;
  current: number;
  target: number;
  reward: string;
}

const FALLBACK_CHALLENGES: SeasonChallenge[] = [
  { id: "c1", name: "Zindan Avcısı", description: "10 zindan tamamla", current: 0, target: 10, reward: "500 Altın + 10 Gem" },
  { id: "c2", name: "Pazar Ustası", description: "20 eşya sat", current: 0, target: 20, reward: "1,000 Altın" },
  { id: "c3", name: "Lonca Savaşçısı", description: "5 lonca savaşına katıl", current: 0, target: 5, reward: "Nadir Sandık" },
  { id: "c4", name: "Zanaatkâr", description: "15 eşya üret", current: 0, target: 15, reward: "750 Altın + Scroll" },
  { id: "c5", name: "PvP Şampiyonu", description: "Sıralamada Top 100'e gir", current: 0, target: 1, reward: "Efsanevi Sandık" },
];

export default function SeasonPage() {
  const { season, battlePass, battlePassProgress, daysRemaining, fetchSeason, fetchBattlePass, claimReward, purchasePremiumPass } = useSeason();
  const [challenges, setChallenges] = useState<SeasonChallenge[]>(FALLBACK_CHALLENGES);

  const fetchChallenges = useCallback(async () => {
    const res = await api.rpc<SeasonChallenge[]>("get_season_challenges", {});
    if (res.success && res.data && res.data.length > 0) {
      setChallenges(res.data);
    }
  }, []);

  useEffect(() => {
    fetchSeason();
    fetchBattlePass();
    fetchChallenges();
  }, [fetchSeason, fetchBattlePass, fetchChallenges]);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🌟 Sezon</h1>

      {/* Season Info */}
      <Card variant="elevated">
        <div className="p-4">
          <h2 className="font-bold text-[var(--text-primary)]">{season?.name ?? "Winter Wonderland 2026"}</h2>
          <div className="flex items-center justify-between mt-2 text-xs text-[var(--text-secondary)]">
            <span>Kalan: {daysRemaining || 45} gün</span>
            <span>Genel İlerleme</span>
          </div>
          <ProgressBar value={battlePassProgress} max={100} color="accent" size="sm" className="mt-2"
            label={`%${Math.round(battlePassProgress)}`} />
        </div>
      </Card>

      {/* Battle Pass */}
      <Card>
        <div className="p-4">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)]">🎫 Battle Pass</h3>
            <span className={`text-xs font-medium ${battlePass.isPremium ? "text-[var(--gold)]" : "text-[var(--text-muted)]"}`}>
              {battlePass.isPremium ? "⭐ Premium" : "Ücretsiz"}
            </span>
          </div>
          <div className="flex items-center justify-between text-xs text-[var(--text-muted)] mb-2">
            <span>Tier {battlePass.currentTier}/{battlePass.maxTiers}</span>
            <span>{battlePass.currentXp}/{battlePass.xpPerTier} XP</span>
          </div>
          <ProgressBar value={battlePass.currentXp} max={battlePass.xpPerTier} color="accent" size="sm" />

          {/* Tier rewards preview */}
          <div className="flex gap-1 mt-3 overflow-x-auto pb-1">
            {Array.from({ length: Math.min(10, battlePass.maxTiers) }).map((_, i) => {
              const tier = i + 1;
              const claimed = battlePass.claimedRewards.includes(tier);
              const available = tier <= battlePass.currentTier && !claimed;
              return (
                <button key={tier} onClick={() => available && claimReward(tier)}
                  className={`flex-shrink-0 w-10 h-10 rounded-lg border text-xs font-bold flex items-center justify-center transition-colors ${
                    claimed ? "bg-green-500/20 border-green-500 text-green-400" :
                    available ? "bg-[var(--accent)]/20 border-[var(--accent)] text-[var(--accent)] animate-pulse" :
                    "bg-[var(--bg-input)] border-[var(--border-default)] text-[var(--text-muted)]"
                  }`}>
                  {claimed ? "✓" : tier}
                </button>
              );
            })}
          </div>

          {!battlePass.isPremium && (
            <Button variant="primary" size="sm" fullWidth className="mt-3" onClick={() => purchasePremiumPass()}>
              ⭐ Premium Battle Pass Satın Al
            </Button>
          )}
        </div>
      </Card>

      {/* Challenges */}
      <div>
        <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">🎯 Mücadeleler</h3>
        <div className="space-y-2">
          {challenges.map((ch) => (
            <Card key={ch.id}>
              <div className="p-3">
                <div className="flex items-center justify-between mb-1">
                  <h4 className="text-sm font-medium text-[var(--text-primary)]">{ch.name}</h4>
                  <span className="text-[10px] text-[var(--text-muted)]">{ch.current}/{ch.target}</span>
                </div>
                <p className="text-[10px] text-[var(--text-muted)] mb-2">{ch.description}</p>
                <ProgressBar value={ch.current} max={ch.target} color={ch.current >= ch.target ? "success" : "accent"} size="sm" />
                <p className="text-[10px] text-[var(--color-gold)] mt-1">🎁 {ch.reward}</p>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </motion.div>
  );
}
