// ============================================================
// Dungeon Battle Page — Kaynak: DungeonBattleScreen.gd
// Savaş animasyonu, countdown, başarı/başarısızlık, ödüller,
// hastane durumu, loot gösterimi, ödül toplama RPC
// ============================================================

"use client";

import { useEffect, useState, useCallback, Suspense } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { formatGold } from "@/lib/utils/string";

// ── Constants ───────────────────────────────────────────────

const SECONDS_PER_HOUR = 3600;
const BATTLE_COUNTDOWN_SECONDS = 3;

// ── Types ───────────────────────────────────────────────────

type BattlePhase =
  | "idle"       // Başlamadı
  | "fighting"   // Savaş sürüyor (spinner)
  | "success"    // Başarılı
  | "failure"    // Başarısız
  | "claiming";  // Ödüller alınıyor

interface BattleRewards {
  gold: number;
  xp: number;
  items: string[];
}

interface BattleResult {
  success: boolean;
  rewards?: BattleRewards;
  hospitalDuration?: number; // saniye
  hospitalized: boolean;
}

// ── Loot item display helper ─────────────────────────────────

function formatItemName(raw: string): string {
  return raw
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

// ── Animated battle spinner ─────────────────────────────────

function BattleSpinner({ dungeon_name }: { dungeon_name: string }) {
  return (
    <div className="flex flex-col items-center gap-6 py-10">
      <motion.div
        animate={{ rotate: 360 }}
        transition={{ duration: 1.2, repeat: Infinity, ease: "linear" }}
        className="text-6xl select-none"
        style={{ display: "inline-block" }}
      >
        ⚔️
      </motion.div>
      <div className="text-center space-y-2">
        <p className="text-lg font-bold text-[var(--text-primary)]">
          {dungeon_name}
        </p>
        <p className="text-sm text-[var(--text-secondary)]">
          Savaş devam ediyor…
        </p>
        <div className="flex gap-1 justify-center mt-2">
          {[0, 1, 2].map((i) => (
            <motion.div
              key={i}
              className="w-2 h-2 rounded-full bg-[var(--accent)]"
              animate={{ opacity: [0.3, 1, 0.3] }}
              transition={{ duration: 1, repeat: Infinity, delay: i * 0.33 }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

// ── Countdown display ───────────────────────────────────────

function CountdownBar({ seconds, total }: { seconds: number; total: number }) {
  const pct = ((total - seconds) / total) * 100;
  return (
    <div className="w-full">
      <div className="flex justify-between text-xs text-[var(--text-muted)] mb-1">
        <span>Süre</span>
        <span>{seconds}s</span>
      </div>
      <div className="h-2 bg-[var(--bg-elevated)] rounded-full overflow-hidden">
        <motion.div
          className="h-full bg-[var(--accent)] rounded-full"
          animate={{ width: `${pct}%` }}
          transition={{ ease: "linear" }}
        />
      </div>
    </div>
  );
}

// ── Result panel ─────────────────────────────────────────────

function ResultPanel({
  result,
  dungeonName,
  onClaim,
  onBack,
  isClaiming,
}: {
  result: BattleResult;
  dungeonName: string;
  onClaim: () => void;
  onBack: () => void;
  isClaiming: boolean;
}) {
  return (
    <AnimatePresence>
      <motion.div
        key="result"
        initial={{ opacity: 0, scale: 0.85 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.85 }}
        transition={{ type: "spring", stiffness: 280, damping: 22 }}
        className="space-y-4"
      >
        {/* Outcome header */}
        <Card variant="elevated">
          <div className="p-4 text-center space-y-3">
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ type: "spring", delay: 0.1, stiffness: 260, damping: 18 }}
              className="text-6xl"
            >
              {result.success ? "🏆" : "💀"}
            </motion.div>
            <h2
              className="text-2xl font-bold"
              style={{
                color: result.success
                  ? "var(--color-success)"
                  : "var(--color-error)",
              }}
            >
              {result.success ? "ZAFER!" : "YENILDIN!"}
            </h2>
            <p className="text-sm text-[var(--text-secondary)]">{dungeonName}</p>
          </div>
        </Card>

        {/* Rewards (success) */}
        {result.success && result.rewards && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.25 }}
          >
            <Card>
              <div className="p-4 space-y-3">
                <h3 className="text-sm font-bold text-[var(--text-primary)]">
                  🎁 Ödüller
                </h3>
                <div className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-[var(--text-secondary)]">💰 Altın</span>
                    <span className="text-[var(--color-gold)] font-semibold">
                      {formatGold(result.rewards.gold)}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-[var(--text-secondary)]">✨ Deneyim</span>
                    <span className="text-[var(--color-success)] font-semibold">
                      +{result.rewards.xp} XP
                    </span>
                  </div>
                  {result.rewards.items.length > 0 && (
                    <div className="pt-2 border-t border-[var(--border-default)]">
                      <p className="text-xs text-[var(--text-secondary)] mb-1">
                        🎒 Eşyalar
                      </p>
                      <div className="flex flex-wrap gap-1">
                        {result.rewards.items.map((item, i) => (
                          <span
                            key={i}
                            className="text-xs px-2 py-0.5 rounded-md bg-[var(--bg-elevated)] text-[var(--text-primary)]"
                          >
                            {formatItemName(item)}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </Card>
          </motion.div>
        )}

        {/* Hospital info (failure) */}
        {!result.success && result.hospitalized && result.hospitalDuration && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.25 }}
          >
            <Card variant="bordered">
              <div className="p-4 text-center space-y-2">
                <p className="text-3xl">🏥</p>
                <p className="text-sm font-semibold text-[var(--color-error)]">
                  Hastaneye Kaldırıldın!
                </p>
                <p className="text-xs text-[var(--text-muted)]">
                  {Math.round(result.hospitalDuration / 3600)} saat hastanede kalacaksın.
                </p>
              </div>
            </Card>
          </motion.div>
        )}

        {/* Failure — no hospital */}
        {!result.success && !result.hospitalized && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.25 }}
          >
            <Card variant="bordered">
              <div className="p-4 text-center">
                <p className="text-sm text-[var(--text-secondary)]">
                  Bu sefer şanssızdın. Tekrar dene!
                </p>
              </div>
            </Card>
          </motion.div>
        )}

        {/* Action buttons */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.45 }}
          className="flex flex-col gap-2"
        >
          {result.success && (
            <Button
              variant="gold"
              size="lg"
              fullWidth
              isLoading={isClaiming}
              onClick={onClaim}
            >
              🪙 Ödülleri Al
            </Button>
          )}
          <Button variant="secondary" size="md" fullWidth onClick={onBack}>
            ← Zindanlara Dön
          </Button>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}

// ── Core battle logic component (uses useSearchParams) ───────

function DungeonBattleContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const addToast = useUiStore((s) => s.addToast);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addXp = usePlayerStore((s) => s.addXp);
  const updatePlayerData = usePlayerStore((s) => s.updatePlayerData);

  // Parse URL params — mirrors DungeonBattleScreen.gd setup_dungeon()
  const dungeonId = searchParams.get("dungeon_id") ?? "";
  const dungeonName = searchParams.get("dungeon_name") ?? "Zindan";
  const successRate = parseFloat(searchParams.get("success_rate") ?? "0.5");
  const energyCost = parseInt(searchParams.get("energy_cost") ?? "10", 10);
  const minGold = parseInt(searchParams.get("min_gold") ?? "100", 10);
  const maxGold = parseInt(searchParams.get("max_gold") ?? "500", 10);
  const xpReward = parseInt(searchParams.get("xp_reward") ?? "100", 10);

  const [phase, setPhase] = useState<BattlePhase>("idle");
  const [countdown, setCountdown] = useState(BATTLE_COUNTDOWN_SECONDS);
  const [result, setResult] = useState<BattleResult | null>(null);
  const [isClaiming, setIsClaiming] = useState(false);

  // Start battle automatically on mount — Godot: _ready() → _start_battle()
  // addToast and router are stable references; dungeonId is the real trigger
  useEffect(() => {
    if (!dungeonId) {
      addToast("Geçersiz zindan parametreleri", "error");
      router.replace("/dungeon");
      return;
    }
    setPhase("fighting");
  }, [dungeonId, addToast, router]);

  // Battle resolution — mirrors DungeonBattleScreen.gd _resolve_battle()
  const resolveBattle = useCallback(async () => {
    // Local success roll (matches Godot: successRoll < successRate → success)
    const successRoll = Math.random();
    const localSuccess = successRoll < successRate;

    // Calculate rewards locally for immediate display
    const goldEarned = Math.floor(minGold + Math.random() * (maxGold - minGold));

    // 25% hospitalization chance on failure — Godot: if not success and rand() < 0.25
    const hospitalized = !localSuccess && Math.random() < 0.25;
    const hospitalHours = hospitalized
      ? 2 + Math.floor(Math.random() * 5) // 2-6 hours — Godot: rand_range(2, 6)
      : 0;
    const hospitalSeconds = hospitalHours * SECONDS_PER_HOUR;

    // Consume energy locally
    consumeEnergy(energyCost);

    try {
      // Call backend RPC — server is authoritative
      const res = await api.rpc<{
        success: boolean;
        gold_earned?: number;
        xp_earned?: number;
        items?: string[];
        hospital_duration?: number;
        hospitalized?: boolean;
        hospital_until?: string;
      }>("enter_dungeon", { p_dungeon_id: dungeonId });

      if (res.success && res.data) {
        const d = res.data;
        const finalSuccess = d.success;
        const finalHospitalized = !finalSuccess && (d.hospitalized ?? false);
        const finalHospitalDuration = d.hospital_duration ?? (finalHospitalized ? hospitalSeconds : 0);

        const battleResult: BattleResult = {
          success: finalSuccess,
          hospitalized: finalHospitalized,
          hospitalDuration: finalHospitalDuration,
          rewards: finalSuccess
            ? {
                gold: d.gold_earned ?? goldEarned,
                xp: d.xp_earned ?? xpReward,
                items: d.items ?? [],
              }
            : undefined,
        };

        // Update hospital status in store if applicable
        if (finalHospitalized && d.hospital_until) {
          updatePlayerData({
            hospital_until: d.hospital_until,
            inHospital: true,
            hospitalUntil: d.hospital_until,
          });
        }

        setResult(battleResult);
        setPhase(finalSuccess ? "success" : "failure");
        return;
      }
    } catch {
      // API failed — fall back to local result
    }

    // Fallback to local roll result
    const hospitalUntilDate = hospitalized
      ? new Date(Date.now() + hospitalSeconds * 1000).toISOString()
      : null;

    if (hospitalized && hospitalUntilDate) {
      updatePlayerData({
        hospital_until: hospitalUntilDate,
        inHospital: true,
        hospitalUntil: hospitalUntilDate,
      });
    }

    const battleResult: BattleResult = {
      success: localSuccess,
      hospitalized,
      hospitalDuration: hospitalSeconds,
      rewards: localSuccess
        ? { gold: goldEarned, xp: xpReward, items: [] }
        : undefined,
    };

    setResult(battleResult);
    setPhase(localSuccess ? "success" : "failure");
  }, [
    dungeonId,
    successRate,
    minGold,
    maxGold,
    xpReward,
    energyCost,
    consumeEnergy,
    updatePlayerData,
  ]);

  // Countdown timer while fighting
  useEffect(() => {
    if (phase !== "fighting") return;

    const interval = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          clearInterval(interval);
          resolveBattle();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [phase, resolveBattle]);

  // Claim rewards — Godot: _on_claim_rewards → api.rpc("collect_dungeon_rewards")
  const handleClaim = useCallback(async () => {
    if (!result?.success || !result.rewards) return;
    
    // CAPACITY CHECK: if rewards have items, ensure inventory space
    if (result.rewards.items && result.rewards.items.length > 0) {
      const invStore = useInventoryStore.getState();
      const capacityCheck = invStore.canAddItem("placeholder", result.rewards.items.length);
      if (!capacityCheck.canAdd) {
        addToast(capacityCheck.reason || "Envanter dolu! Ödüller alınamıyor.", "error");
        return;
      }
    }
    
    setIsClaiming(true);
    setPhase("claiming");

    try {
      // Try to collect from server
      await api.rpc("collect_dungeon_rewards", { p_dungeon_id: dungeonId });
    } catch {
      // Server-side already applied; update local state anyway
    }

    // Update local gold and XP optimistically
    updateGold(result.rewards.gold, true);
    addXp(result.rewards.xp);

    addToast(
      `🏆 ${dungeonName} tamamlandı! +${formatGold(result.rewards.gold)} 🪙 +${result.rewards.xp} XP`,
      "success"
    );

    router.replace("/dungeon");
  }, [result, dungeonId, dungeonName, updateGold, addXp, addToast, router]);

  // Handle back navigation
  const handleBack = useCallback(() => {
    if (!result?.success && result?.hospitalized) {
      addToast("🏥 Hastaneye kaldırıldın!", "error");
    }
    router.replace("/dungeon");
  }, [result, addToast, router]);

  // ── Render ─────────────────────────────────────────────────

  return (
    <div className="min-h-screen bg-[var(--bg-primary)] flex flex-col">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-[var(--bg-primary)] border-b border-[var(--border-default)] px-4 py-3 flex items-center gap-3">
        <button
          onClick={handleBack}
          className="text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition-colors"
          disabled={phase === "fighting"}
        >
          ←
        </button>
        <h1 className="text-base font-bold text-[var(--text-primary)] flex-1 truncate">
          🏰 {dungeonName}
        </h1>
        {phase === "fighting" && (
          <span className="text-xs text-[var(--text-muted)] tabular-nums">
            {countdown}s
          </span>
        )}
      </div>

      {/* Content */}
      <div className="flex-1 p-4 max-w-md mx-auto w-full">
        <AnimatePresence mode="wait">
          {/* Fighting phase */}
          {phase === "fighting" && (
            <motion.div
              key="fighting"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="space-y-6"
            >
              {/* Dungeon info strip */}
              <Card>
                <div className="p-3 flex justify-between text-xs text-[var(--text-secondary)]">
                  <span>⚡ {energyCost} Enerji</span>
                  <span>🎯 %{Math.round(successRate * 100)} Başarı</span>
                  <span className="text-[var(--color-gold)]">
                    💰 {formatGold(minGold)}-{formatGold(maxGold)}
                  </span>
                </div>
              </Card>

              <BattleSpinner dungeon_name={dungeonName} />

              <CountdownBar seconds={countdown} total={3} />

              {/* Battle flavour text */}
              <motion.div
                key={countdown}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                className="text-center text-xs text-[var(--text-muted)]"
              >
                {countdown === 3 && "🗡️ Zindana giriyorsun…"}
                {countdown === 2 && "⚔️ Düşmanlarla savaşıyorsun…"}
                {countdown === 1 && "🔥 Son hamle!"}
                {countdown === 0 && "✨ Sonuç belirleniyor…"}
              </motion.div>
            </motion.div>
          )}

          {/* Idle (before start) */}
          {phase === "idle" && (
            <motion.div
              key="idle"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex items-center justify-center py-20"
            >
              <p className="text-[var(--text-muted)] text-sm">Hazırlanıyor…</p>
            </motion.div>
          )}

          {/* Result phases */}
          {(phase === "success" || phase === "failure" || phase === "claiming") &&
            result && (
              <motion.div
                key="result"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
              >
                <ResultPanel
                  result={result}
                  dungeonName={dungeonName}
                  onClaim={handleClaim}
                  onBack={handleBack}
                  isClaiming={isClaiming}
                />
              </motion.div>
            )}
        </AnimatePresence>
      </div>

      {/* Bottom stats bar — visible during battle */}
      {phase === "fighting" && (
        <div className="border-t border-[var(--border-default)] px-4 py-3">
          <div className="max-w-md mx-auto grid grid-cols-3 gap-2 text-center text-xs text-[var(--text-muted)]">
            <div>
              <p className="font-semibold text-[var(--text-primary)]">
                ✨ {xpReward}
              </p>
              <p>XP Ödülü</p>
            </div>
            <div>
              <p className="font-semibold text-[var(--color-gold)]">
                {formatGold(minGold)}-{formatGold(maxGold)}
              </p>
              <p>Altın</p>
            </div>
            <div>
              <p
                className="font-semibold"
                style={{
                  color:
                    successRate >= 0.7
                      ? "var(--color-success)"
                      : successRate >= 0.4
                      ? "var(--color-warning)"
                      : "var(--color-error)",
                }}
              >
                %{Math.round(successRate * 100)}
              </p>
              <p>Başarı</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Suspense wrapper (required for useSearchParams) ──────────

export default function DungeonBattlePage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center">
          <div className="text-center space-y-4">
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 1.2, repeat: Infinity, ease: "linear" }}
              className="text-5xl"
              style={{ display: "inline-block" }}
            >
              ⚔️
            </motion.div>
            <p className="text-[var(--text-muted)] text-sm">Yükleniyor…</p>
          </div>
        </div>
      }
    >
      <DungeonBattleContent />
    </Suspense>
  );
}
