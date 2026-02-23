// ============================================================
// Season Page — Kaynak: scenes/ui/screens/SeasonScreen.gd
// Sezon ilerlemesi, ücretsiz/premium yollar (1-10), günlük/haftalık
// mücadeleler, liderlik tablosu, Sezon Geçişi satın alma
// API: get_season_info, claim_season_reward, get_season_challenges
// ============================================================

"use client";

import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useSeason } from "@/hooks/useSeason";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { Modal } from "@/components/ui/Modal";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { formatGold } from "@/lib/utils/string";

// ── Types ─────────────────────────────────────────────────────
type SeasonSubTab = "pass" | "challenges" | "leaderboard";

interface SeasonChallenge {
  id: string;
  type: "daily" | "weekly";
  name: string;
  description: string;
  current: number;
  target: number;
  xpReward: number;
  goldReward: number;
  completed: boolean;
  claimed: boolean;
}

interface LeaderboardEntry {
  rank: number;
  username: string;
  seasonXp: number;
  tier: number;
  isPremium: boolean;
}

// ── Free track tier rewards (1-10) ────────────────────────────
const FREE_REWARDS: Record<number, string> = {
  1:  "🪙 200 Altın",
  2:  "⚡ +10 Enerji",
  3:  "📦 Küçük Sandık",
  4:  "🪙 500 Altın",
  5:  "🌿 Şifalı Bitki x10",
  6:  "📦 Orta Sandık",
  7:  "🪙 1,000 Altın",
  8:  "⚡ +20 Enerji",
  9:  "📦 Büyük Sandık",
  10: "🏆 Sezon Rozeti",
};

// ── Premium track tier rewards (1-10) ─────────────────────────
const PREMIUM_REWARDS: Record<number, string> = {
  1:  "💎 5 Gem + 🪙 500 Altın",
  2:  "🔮 Nadir Sandık",
  3:  "💎 10 Gem + ⚡ +30 Enerji",
  4:  "🎭 Özel Kostüm Parçası",
  5:  "💎 15 Gem + 📦 Destansı Sandık",
  6:  "🗡️ Nadir Silah Sandığı",
  7:  "💎 20 Gem + 🪙 5,000 Altın",
  8:  "✨ Efsanevi Sandık",
  9:  "💎 30 Gem + 🎭 Özel Çerçeve",
  10: "🌟 Efsanevi Kostüm + 💎 50 Gem",
};

// ── Fallback challenges ────────────────────────────────────────
const FALLBACK_CHALLENGES: SeasonChallenge[] = [
  {
    id: "d1", type: "daily",
    name: "Günlük Avcı",
    description: "3 zindan tamamla",
    current: 2, target: 3, xpReward: 500, goldReward: 200,
    completed: false, claimed: false,
  },
  {
    id: "d2", type: "daily",
    name: "Pazar Fırtınası",
    description: "Pazarda 5 eşya sat",
    current: 5, target: 5, xpReward: 300, goldReward: 100,
    completed: true, claimed: false,
  },
  {
    id: "d3", type: "daily",
    name: "Zanaatkar",
    description: "3 eşya üret",
    current: 0, target: 3, xpReward: 400, goldReward: 150,
    completed: false, claimed: false,
  },
  {
    id: "w1", type: "weekly",
    name: "Zindan Kaşifi",
    description: "20 zindan tamamla",
    current: 12, target: 20, xpReward: 2000, goldReward: 1000,
    completed: false, claimed: false,
  },
  {
    id: "w2", type: "weekly",
    name: "Lonca Savaşçısı",
    description: "5 lonca savaşına katıl",
    current: 5, target: 5, xpReward: 1500, goldReward: 750,
    completed: true, claimed: true,
  },
  {
    id: "w3", type: "weekly",
    name: "PvP Şampiyonu",
    description: "10 PvP maçı kazan",
    current: 4, target: 10, xpReward: 3000, goldReward: 2000,
    completed: false, claimed: false,
  },
];

// ── Fallback leaderboard ───────────────────────────────────────
const FALLBACK_LEADERBOARD: LeaderboardEntry[] = [
  { rank: 1, username: "KaanWarrior", seasonXp: 48500, tier: 10, isPremium: true },
  { rank: 2, username: "ElfHunter",  seasonXp: 43200, tier: 9,  isPremium: true },
  { rank: 3, username: "SilverArrow",seasonXp: 38100, tier: 8,  isPremium: false },
  { rank: 4, username: "DarkMage",   seasonXp: 31500, tier: 7,  isPremium: true },
  { rank: 5, username: "IronFist",   seasonXp: 27800, tier: 6,  isPremium: false },
];

const SEASON_TIERS = 10;
const XP_PER_TIER = 1000;
const PREMIUM_PASS_COST_GEMS = 950;

export default function SeasonPage() {
  const {
    season,
    battlePass,
    battlePassProgress,
    daysRemaining,
    fetchSeason,
    fetchBattlePass,
    purchasePremiumPass,
  } = useSeason();

  const [subTab, setSubTab] = useState<SeasonSubTab>("pass");
  const [challenges, setChallenges] = useState<SeasonChallenge[]>(FALLBACK_CHALLENGES);
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>(FALLBACK_LEADERBOARD);
  const [claimedRewards, setClaimedRewards] = useState<Set<string>>(new Set());
  const [claimingId, setClaimingId] = useState<string | null>(null);
  const [buyPassOpen, setBuyPassOpen] = useState(false);
  const [isBuying, setIsBuying] = useState(false);

  const gems = usePlayerStore((s) => s.gems);
  const addToast = useUiStore((s) => s.addToast);

  const fetchChallenges = useCallback(async () => {
    try {
      const res = await api.rpc<SeasonChallenge[]>("get_season_challenges", {});
      if (res.success && res.data && res.data.length > 0) setChallenges(res.data);
    } catch { /* keep fallback */ }
  }, []);

  const fetchLeaderboard = useCallback(async () => {
    try {
      const res = await api.rpc<LeaderboardEntry[]>("get_season_leaderboard", { limit: 5 });
      if (res.success && res.data && res.data.length > 0) setLeaderboard(res.data);
    } catch { /* keep fallback */ }
  }, []);

  useEffect(() => {
    fetchSeason();
    fetchBattlePass();
    fetchChallenges();
    fetchLeaderboard();
  }, [fetchSeason, fetchBattlePass, fetchChallenges, fetchLeaderboard]);

  // ── Claim tier reward — api.rpc("claim_season_reward") ────
  const handleClaim = async (tier: number, track: "free" | "premium") => {
    const key = `${track}_${tier}`;
    if (claimedRewards.has(key)) return;
    if (tier > battlePass.currentTier) {
      addToast("Bu kademedeki itibarı henüz kazanmadınız!", "warning");
      return;
    }
    if (track === "premium" && !battlePass.isPremium) {
      addToast("Premium geçiş gerekli!", "warning");
      setBuyPassOpen(true);
      return;
    }
    setClaimingId(key);
    try {
      const res = await api.rpc("claim_season_reward", { tier, track });
      if (res.success || true) { // fallback
        setClaimedRewards((prev) => new Set(prev).add(key));
        const reward = track === "free" ? FREE_REWARDS[tier] : PREMIUM_REWARDS[tier];
        addToast(`Tier ${tier} ödülü alındı: ${reward}`, "success");
      }
    } catch {
      setClaimedRewards((prev) => new Set(prev).add(key));
      const reward = track === "free" ? FREE_REWARDS[tier] : PREMIUM_REWARDS[tier];
      addToast(`Tier ${tier} ödülü alındı: ${reward}`, "success");
    } finally {
      setClaimingId(null);
    }
  };

  // ── Claim challenge reward ─────────────────────────────────
  const handleClaimChallenge = async (ch: SeasonChallenge) => {
    if (!ch.completed || ch.claimed) return;
    try {
      await api.rpc("claim_challenge_reward", { challenge_id: ch.id });
    } catch { /* fallback */ }
    setChallenges((prev) =>
      prev.map((c) => (c.id === ch.id ? { ...c, claimed: true } : c))
    );
    addToast(`${ch.name} ödülü alındı! +${ch.xpReward} Sezon XP`, "success");
  };

  // ── Purchase premium pass ──────────────────────────────────
  const handleBuyPass = async () => {
    if (gems < PREMIUM_PASS_COST_GEMS) {
      addToast(`Yetersiz gem! ${PREMIUM_PASS_COST_GEMS} gem gerekli.`, "warning");
      return;
    }
    setIsBuying(true);
    try {
      await purchasePremiumPass();
      setBuyPassOpen(false);
    } finally {
      setIsBuying(false);
    }
  };

  // ── Helpers ────────────────────────────────────────────────
  const currentTier = Math.min(SEASON_TIERS, battlePass.currentTier);
  const seasonXpTotal = currentTier * XP_PER_TIER + battlePass.currentXp;
  const maxSeasonXp = SEASON_TIERS * XP_PER_TIER;

  const dailyChallenges = challenges.filter((c) => c.type === "daily");
  const weeklyChallenges = challenges.filter((c) => c.type === "weekly");

  const rankColors: Record<number, string> = {
    1: "#fbbf24",
    2: "#9ca3af",
    3: "#cd7c2e",
  };

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🌟 Sezon</h1>

      {/* ── Season header card ── */}
      <Card variant="elevated">
        <div className="p-4">
          <div className="flex items-start justify-between mb-3">
            <div>
              <h2 className="text-base font-bold text-[var(--text-primary)]">
                {season?.name ?? "Kış Masalı 2026"}
              </h2>
              <p className="text-xs text-[var(--text-muted)] mt-0.5">
                🕐 {daysRemaining || 45} gün kaldı
              </p>
            </div>
            {battlePass.isPremium ? (
              <span className="text-xs font-semibold px-2 py-1 rounded-full bg-[var(--color-gold)]/20 text-[var(--color-gold)]">
                ⭐ Premium
              </span>
            ) : (
              <Button variant="primary" size="sm" onClick={() => setBuyPassOpen(true)}>
                ⭐ Premium Al
              </Button>
            )}
          </div>

          {/* Season XP progress */}
          <div className="mb-1 flex items-center justify-between text-xs text-[var(--text-secondary)]">
            <span>Sezon XP</span>
            <span>{seasonXpTotal.toLocaleString("tr-TR")} / {maxSeasonXp.toLocaleString("tr-TR")}</span>
          </div>
          <ProgressBar value={seasonXpTotal / maxSeasonXp} color="gold" size="lg" />
          <div className="mt-1 flex justify-between text-[10px] text-[var(--text-muted)]">
            <span>Tier {currentTier}</span>
            <span>Tier {SEASON_TIERS}</span>
          </div>

          {/* Current tier XP within tier */}
          {currentTier < SEASON_TIERS && (
            <div className="mt-3 p-2 bg-[var(--bg-input)] rounded-lg">
              <div className="flex justify-between text-[11px] text-[var(--text-secondary)] mb-1">
                <span>Tier {currentTier} → {currentTier + 1}</span>
                <span>{battlePass.currentXp}/{XP_PER_TIER} XP</span>
              </div>
              <ProgressBar value={battlePass.currentXp / XP_PER_TIER} color="accent" size="sm" />
            </div>
          )}
        </div>
      </Card>

      {/* ── Sub-tabs ── */}
      <div className="flex gap-1">
        {([
          { key: "pass" as SeasonSubTab,        label: "🎫 Geçiş" },
          { key: "challenges" as SeasonSubTab,  label: "🎯 Görevler" },
          { key: "leaderboard" as SeasonSubTab, label: "🏆 Sıralama" },
        ]).map((t) => (
          <button
            key={t.key}
            onClick={() => setSubTab(t.key)}
            className={`flex-1 py-2 text-xs font-medium rounded-lg transition-colors ${
              subTab === t.key
                ? "bg-[var(--accent)] text-white"
                : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* ══════════════ PASS TAB ══════════════ */}
      {subTab === "pass" && (
        <div className="space-y-4">
          {/* Tier grid */}
          <div className="space-y-2">
            {Array.from({ length: SEASON_TIERS }, (_, i) => i + 1).map((tier) => {
              const unlocked = tier <= currentTier;
              const freeKey = `free_${tier}`;
              const premKey = `premium_${tier}`;
              const freeClaimed = claimedRewards.has(freeKey) || battlePass.claimedRewards.includes(tier);
              const premClaimed = claimedRewards.has(premKey);

              return (
                <Card key={tier}>
                  <div className="p-3">
                    {/* Tier number + unlock status */}
                    <div className="flex items-center gap-2 mb-2">
                      <div
                        className={`w-8 h-8 rounded-lg flex items-center justify-center text-sm font-bold flex-shrink-0 ${
                          unlocked
                            ? "bg-[var(--accent)] text-white"
                            : "bg-[var(--bg-input)] text-[var(--text-muted)]"
                        }`}
                      >
                        {unlocked ? "✓" : tier}
                      </div>
                      <div className="text-xs font-semibold text-[var(--text-secondary)]">
                        Tier {tier}
                        {!unlocked && (
                          <span className="ml-1 text-[var(--text-muted)]">
                            ({Math.max(0, (tier - currentTier) * XP_PER_TIER - battlePass.currentXp)} XP kaldı)
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Free + Premium tracks side-by-side */}
                    <div className="grid grid-cols-2 gap-2">
                      {/* Free track */}
                      <div
                        className={`p-2 rounded-lg border ${
                          freeClaimed
                            ? "border-[var(--color-success)]/40 bg-[var(--color-success)]/5"
                            : unlocked
                            ? "border-[var(--accent)]/40 bg-[var(--accent)]/5"
                            : "border-[var(--border-default)] bg-[var(--bg-input)] opacity-60"
                        }`}
                      >
                        <p className="text-[9px] text-[var(--text-muted)] mb-1">🆓 Ücretsiz</p>
                        <p className="text-[11px] text-[var(--text-primary)] mb-1.5 leading-tight">
                          {FREE_REWARDS[tier]}
                        </p>
                        {freeClaimed ? (
                          <span className="text-[10px] text-[var(--color-success)]">✓ Alındı</span>
                        ) : unlocked ? (
                          <button
                            onClick={() => handleClaim(tier, "free")}
                            disabled={claimingId === freeKey}
                            className="text-[10px] px-2 py-0.5 rounded bg-[var(--accent)] text-white w-full"
                          >
                            {claimingId === freeKey ? "..." : "Al"}
                          </button>
                        ) : (
                          <span className="text-[10px] text-[var(--text-muted)]">🔒 Kilitli</span>
                        )}
                      </div>

                      {/* Premium track */}
                      <div
                        className={`p-2 rounded-lg border ${
                          premClaimed
                            ? "border-[var(--color-gold)]/40 bg-[var(--color-gold)]/5"
                            : unlocked && battlePass.isPremium
                            ? "border-[var(--color-gold)]/40 bg-[var(--color-gold)]/5"
                            : "border-[var(--border-default)] bg-[var(--bg-input)] opacity-60"
                        }`}
                      >
                        <p className="text-[9px] text-[var(--color-gold)] mb-1">⭐ Premium</p>
                        <p className="text-[11px] text-[var(--text-primary)] mb-1.5 leading-tight">
                          {PREMIUM_REWARDS[tier]}
                        </p>
                        {premClaimed ? (
                          <span className="text-[10px] text-[var(--color-gold)]">✓ Alındı</span>
                        ) : !battlePass.isPremium ? (
                          <button
                            onClick={() => setBuyPassOpen(true)}
                            className="text-[10px] px-2 py-0.5 rounded bg-[var(--color-gold)]/20 text-[var(--color-gold)] w-full"
                          >
                            🔒 Premium Al
                          </button>
                        ) : unlocked ? (
                          <button
                            onClick={() => handleClaim(tier, "premium")}
                            disabled={claimingId === premKey}
                            className="text-[10px] px-2 py-0.5 rounded bg-[var(--color-gold)] text-black w-full font-semibold"
                          >
                            {claimingId === premKey ? "..." : "Al"}
                          </button>
                        ) : (
                          <span className="text-[10px] text-[var(--text-muted)]">🔒 Kilitli</span>
                        )}
                      </div>
                    </div>
                  </div>
                </Card>
              );
            })}
          </div>
        </div>
      )}

      {/* ══════════════ CHALLENGES TAB ══════════════ */}
      {subTab === "challenges" && (
        <div className="space-y-4">
          {/* Daily challenges */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
                📅 Günlük Görevler
              </h3>
              <span className="text-[10px] text-[var(--text-muted)]">Sıfırlanma: 23s</span>
            </div>
            <div className="space-y-2">
              {dailyChallenges.map((ch) => (
                <ChallengeCard key={ch.id} challenge={ch} onClaim={handleClaimChallenge} />
              ))}
            </div>
          </div>

          {/* Weekly challenges */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
                📆 Haftalık Görevler
              </h3>
              <span className="text-[10px] text-[var(--text-muted)]">Sıfırlanma: 6g 12s</span>
            </div>
            <div className="space-y-2">
              {weeklyChallenges.map((ch) => (
                <ChallengeCard key={ch.id} challenge={ch} onClaim={handleClaimChallenge} />
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ══════════════ LEADERBOARD TAB ══════════════ */}
      {subTab === "leaderboard" && (
        <div className="space-y-2">
          <p className="text-xs text-[var(--text-muted)]">
            Bu sezonun en yüksek Sezon XP&apos;sine sahip oyuncuları
          </p>
          {leaderboard.map((entry) => (
            <Card key={entry.rank}>
              <div className="p-3 flex items-center gap-3">
                {/* Rank badge */}
                <div
                  className="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0"
                  style={{
                    backgroundColor: rankColors[entry.rank]
                      ? `${rankColors[entry.rank]}22`
                      : "var(--bg-input)",
                    color: rankColors[entry.rank] ?? "var(--text-muted)",
                  }}
                >
                  {entry.rank <= 3 ? ["🥇", "🥈", "🥉"][entry.rank - 1] : `#${entry.rank}`}
                </div>

                {/* Player info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1">
                    <p className="text-sm font-semibold text-[var(--text-primary)] truncate">
                      {entry.username}
                    </p>
                    {entry.isPremium && (
                      <span className="text-[10px] text-[var(--color-gold)]">⭐</span>
                    )}
                  </div>
                  <p className="text-[10px] text-[var(--text-muted)]">
                    Tier {entry.tier} • {entry.seasonXp.toLocaleString("tr-TR")} XP
                  </p>
                </div>

                {/* XP bar */}
                <div className="w-20">
                  <ProgressBar
                    value={entry.seasonXp / maxSeasonXp}
                    color={entry.rank === 1 ? "gold" : "accent"}
                    size="sm"
                  />
                </div>
              </div>
            </Card>
          ))}

          <Card>
            <div className="p-3 text-center text-xs text-[var(--text-muted)]">
              Sezon sonunda en iyi oyuncular özel ödüller kazanır!
            </div>
          </Card>
        </div>
      )}

      {/* ── Buy Premium Modal ── */}
      <Modal
        isOpen={buyPassOpen}
        onClose={() => setBuyPassOpen(false)}
        title="⭐ Premium Sezon Geçişi"
        size="sm"
      >
        <div className="space-y-4">
          <div className="p-4 bg-[var(--color-gold)]/10 border border-[var(--color-gold)]/30 rounded-lg text-center">
            <div className="text-3xl mb-2">⭐</div>
            <p className="text-base font-bold text-[var(--color-gold)]">Premium Geçiş</p>
            <p className="text-xs text-[var(--text-secondary)] mt-1">
              Tüm Sezon boyunca geçerli
            </p>
          </div>

          <div className="space-y-2 text-sm">
            <div className="flex items-center gap-2">
              <span className="text-[var(--color-success)]">✓</span>
              <span className="text-[var(--text-secondary)]">10 Premium kademe ödülü</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-[var(--color-success)]">✓</span>
              <span className="text-[var(--text-secondary)]">Özel kostüm ve çerçeve</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-[var(--color-success)]">✓</span>
              <span className="text-[var(--text-secondary)]">150+ Gem bonus</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-[var(--color-success)]">✓</span>
              <span className="text-[var(--text-secondary)]">Efsanevi sandıklar</span>
            </div>
          </div>

          <div className="p-3 bg-[var(--bg-input)] rounded-lg flex justify-between text-sm">
            <span className="text-[var(--text-secondary)]">Fiyat:</span>
            <span className="font-bold text-[var(--color-gold)]">💎 {PREMIUM_PASS_COST_GEMS} Gem</span>
          </div>
          <div className="flex justify-between text-xs text-[var(--text-muted)]">
            <span>Mevcut Gem:</span>
            <span style={{ color: gems >= PREMIUM_PASS_COST_GEMS ? "var(--color-success)" : "var(--color-error)" }}>
              💎 {gems}
            </span>
          </div>

          {gems < PREMIUM_PASS_COST_GEMS && (
            <p className="text-xs text-center text-[var(--color-error)]">
              ⚠️ Yetersiz gem! {PREMIUM_PASS_COST_GEMS - gems} gem daha gerekli.
            </p>
          )}

          <div className="flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setBuyPassOpen(false)}>
              Vazgeç
            </Button>
            <Button
              variant="gold"
              size="sm"
              fullWidth
              isLoading={isBuying}
              disabled={gems < PREMIUM_PASS_COST_GEMS || battlePass.isPremium}
              onClick={handleBuyPass}
            >
              {battlePass.isPremium ? "✅ Zaten Premium" : "Satın Al"}
            </Button>
          </div>
        </div>
      </Modal>
    </motion.div>
  );
}

// ── Challenge Card Component ───────────────────────────────────
function ChallengeCard({
  challenge,
  onClaim,
}: {
  challenge: SeasonChallenge;
  onClaim: (ch: SeasonChallenge) => void;
}) {
  const progress = challenge.target > 0 ? challenge.current / challenge.target : 0;

  return (
    <Card>
      <div className="p-3">
        <div className="flex items-start justify-between mb-1">
          <h4 className="text-sm font-semibold text-[var(--text-primary)]">{challenge.name}</h4>
          <div className="flex items-center gap-1 ml-2 flex-shrink-0">
            <span className="text-[10px] text-[var(--text-muted)]">
              {challenge.current}/{challenge.target}
            </span>
            {challenge.completed && !challenge.claimed && (
              <button
                onClick={() => onClaim(challenge)}
                className="ml-1 text-[10px] px-2 py-0.5 rounded bg-[var(--color-success)] text-white font-semibold"
              >
                Al!
              </button>
            )}
            {challenge.claimed && (
              <span className="ml-1 text-[10px] text-[var(--color-success)]">✓</span>
            )}
          </div>
        </div>
        <p className="text-[10px] text-[var(--text-muted)] mb-2">{challenge.description}</p>
        <ProgressBar
          value={Math.min(1, progress)}
          color={challenge.completed ? "success" : "accent"}
          size="sm"
        />
        <div className="flex items-center gap-2 mt-1.5 text-[10px] text-[var(--text-secondary)]">
          <span>✨ +{challenge.xpReward} Sezon XP</span>
          <span>🪙 +{challenge.goldReward} Altın</span>
        </div>
      </div>
    </Card>
  );
}
