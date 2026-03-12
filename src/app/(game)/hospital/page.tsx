// ============================================================
// Hospital Page — Kaynak: scenes/ui/screens/HospitalScreen.gd (213 satır)
// Geri sayım (Xh Xm Xs), taburcu tarihi, sebep, elmas ile taburcu,
// yetersiz elmas → dükkana git, enerji gösterimi, başarı animasyonu
// ============================================================

"use client";

import { useMemo, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useCountdown } from "@/hooks/useCountdown";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { Modal } from "@/components/ui/Modal";
import { api } from "@/lib/api";
import { isInHospital } from "@/lib/utils/validation";

export default function HospitalPage() {
  const router = useRouter();
  const hospitalUntil = usePlayerStore((s) => s.hospitalUntil);
  const hospitalReason = usePlayerStore((s) => s.hospitalReason);
  const gems = usePlayerStore((s) => s.gems);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);
  const addToast = useUiStore((s) => s.addToast);

  const [confirmRelease, setConfirmRelease] = useState(false);
  const [insufficientGemsOpen, setInsufficientGemsOpen] = useState(false);
  const [isReleasing, setIsReleasing] = useState(false);
  const [released, setReleased] = useState(false);

  const inHospital = isInHospital(hospitalUntil);

  const { secondsLeft, isComplete } = useCountdown({
    targetDate: hospitalUntil,
    onComplete: () => {
      fetchProfile();
      addToast("Hastaneden taburcu oldun!", "success");
    },
  });

  // Godot format: Xh Xm Xs
  const formattedCountdown = useMemo(() => {
    if (secondsLeft <= 0) return "0h 0m 0s";
    const h = Math.floor(secondsLeft / 3600);
    const m = Math.floor((secondsLeft % 3600) / 60);
    const s = secondsLeft % 60;
    return `${h}h ${m}m ${s}s`;
  }, [secondsLeft]);

  // Gem cost formula matching PLAN_04: 3 Gem / Minute
  const gemCost = useMemo(() => {
    if (!inHospital || isComplete) return 0;
    const totalMinutes = Math.ceil(secondsLeft / 60);
    return totalMinutes * 3;
  }, [secondsLeft, inHospital, isComplete]);

  // Release time formatted as datetime
  const releaseTimeFormatted = useMemo(() => {
    if (!hospitalUntil) return "";
    const d = new Date(hospitalUntil);
    if (isNaN(d.getTime())) return "";
    const pad = (n: number) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
  }, [hospitalUntil]);

  // Initial duration estimate for progress bar
  const initialDuration = useMemo(() => {
    // Use secondsLeft as approximation — progress will be estimated
    return Math.max(secondsLeft, 3600); // min 1 hour for visual
  }, []);

  const handleGemRelease = useCallback(async () => {
    if (gems < gemCost) {
      setConfirmRelease(false);
      setInsufficientGemsOpen(true);
      return;
    }
    setIsReleasing(true);
    try {
      // New Supabase RPC: heal_with_gems calculates and deducts
      const result = await api.rpc("heal_with_gems", {});
      if (result.success) {
        setReleased(true);
        addToast("Başarılı! Hastaneden çıktınız!", "success");
        await fetchProfile();
        setConfirmRelease(false);
      } else {
        addToast(result.error || "Taburcu başarısız", "error");
      }
    } catch {
      addToast("Taburcu başarısız", "error");
    } finally {
      setIsReleasing(false);
    }
  }, [gems, gemCost, fetchProfile, addToast]);

  // Not in hospital — healthy state
  if (!inHospital || isComplete || released) {
    return (
      <div className="p-4 space-y-4 pb-24">
        <Card variant="elevated">
          <div className="p-6 text-center">
            <motion.span
              className="text-5xl block"
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ type: "spring", bounce: 0.5 }}
            >
              🏥
            </motion.span>
            <h2 className="text-lg font-bold text-[var(--text-primary)] mt-3">
              {released ? "Başarıyla Çıktınız!" : "Hastane"}
            </h2>
            <p className="text-sm text-[var(--color-success)] mt-2">
              {released
                ? "Elmas harcayarak hastaneden erken çıktınız."
                : "👍 Sağlıksınız — hastanede değilsiniz"}
            </p>
            <div className="flex gap-2 mt-4 justify-center">
              <Button variant="secondary" size="sm" onClick={() => router.push("/home")}>
                Ana Sayfaya Dön
              </Button>
            </div>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="p-4 space-y-4 pb-24">
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}>
        <Card variant="elevated">
          <div className="p-6 text-center">
            <span className="text-5xl">🏥</span>
            <h2 className="text-lg font-bold text-[var(--text-primary)] mt-3">Hastanede</h2>

            {/* Reason — Godot: "Neden: {reason}" */}
            <p className="text-xs text-[var(--color-warning)] mt-1">
              Neden: {hospitalReason || "Zindan başarısızlığı"}
            </p>

            {/* Release datetime — Godot: "Taburcu Tarihi: YYYY-MM-DD HH:MM:SS" */}
            {releaseTimeFormatted && (
              <p className="text-xs text-[var(--text-muted)] mt-1">
                Taburcu Tarihi: {releaseTimeFormatted}
              </p>
            )}

            {/* Countdown — Godot: "Kalan Süre: Xh Xm Xs" */}
            <div className="mt-4">
              <p className="text-3xl font-mono font-bold text-[var(--color-error)]">
                {formattedCountdown}
              </p>
              <p className="text-xs text-[var(--text-muted)] mt-1">Kalan Süre</p>
            </div>

            {/* Progress Bar */}
            <div className="mt-4">
              <ProgressBar
                value={initialDuration - secondsLeft}
                max={initialDuration}
                color="health"
                size="md"
              />
            </div>

            {/* Energy display — Godot: "Enerji: X/Y" */}
            <p className="text-xs text-[var(--text-secondary)] mt-3">
              ⚡ Enerji: {energy}/{maxEnergy}
            </p>

            {/* Gem cost label — Godot: "Elmas ile Çık: X💎" */}
            <p className="text-sm font-semibold text-[var(--color-gem)] mt-3">
              Elmas ile Çık: {gemCost}💎
            </p>

            {/* Release with Gems button */}
            <div className="mt-4">
              <Button
                variant="gold"
                fullWidth
                onClick={() => {
                  if (gems < gemCost) {
                    setInsufficientGemsOpen(true);
                  } else {
                    setConfirmRelease(true);
                  }
                }}
              >
                💎 {gemCost} Gem ile Taburcu Ol
              </Button>
              {gems < gemCost && (
                <p className="text-xs text-[var(--color-error)] mt-1">
                  {gemCost} gem gerekli (mevcut: {gems})
                </p>
              )}
            </div>
          </div>
        </Card>
      </motion.div>

      {/* Confirm Release Modal — Godot: "Emin misiniz?" dialog */}
      <Modal isOpen={confirmRelease} onClose={() => setConfirmRelease(false)} title="Emin misiniz?" size="sm">
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            Hastaneden çıkmak için <strong>{gemCost} elmas</strong> harcayacak. Devam etmek istiyor musunuz?
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setConfirmRelease(false)}>
              İptal
            </Button>
            <Button variant="gold" size="sm" fullWidth isLoading={isReleasing} onClick={handleGemRelease}>
              Evet, Çık
            </Button>
          </div>
        </div>
      </Modal>

      {/* Insufficient Gems Modal — Godot: "Yetersiz Elmas" → "Dükkana Git" */}
      <Modal isOpen={insufficientGemsOpen} onClose={() => setInsufficientGemsOpen(false)} title="Yetersiz Elmas" size="sm">
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            Hastaneden çıkmak için {gemCost} elmas gerekli. Şu anki: {gems}
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setInsufficientGemsOpen(false)}>
              Kapat
            </Button>
            <Button
              variant="gold"
              size="sm"
              fullWidth
              onClick={() => {
                setInsufficientGemsOpen(false);
                router.push("/shop");
              }}
            >
              Dükkana Git
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
