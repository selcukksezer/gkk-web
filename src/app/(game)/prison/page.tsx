// ============================================================
// Prison Page — Kaynak: scenes/ui/screens/PrisonScreen.gd (148 satır)
// Cezaevi durumu, geri sayım (MM:SS), kefalet, progress bar,
// gems gösterimi, açıklama metni, icon değişimi, başarı animasyonu
// ============================================================

"use client";

import { useMemo, useState, useRef, useCallback } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useCountdown } from "@/hooks/useCountdown";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { Modal } from "@/components/ui/Modal";
import { api } from "@/lib/api";
import { isInPrison } from "@/lib/utils/validation";

export default function PrisonPage() {
  const router = useRouter();
  const prisonUntil = usePlayerStore((s) => s.prisonUntil);
  const prisonReason = usePlayerStore((s) => s.prisonReason);
  const gems = usePlayerStore((s) => s.gems);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);
  const addToast = useUiStore((s) => s.addToast);

  const [confirmBail, setConfirmBail] = useState(false);
  const [isBailing, setIsBailing] = useState(false);
  const [released, setReleased] = useState(false);

  const inPrison = isInPrison(prisonUntil);

  // Track initial prison time for accurate progress bar (Godot: initial_prison_time)
  const initialPrisonTimeRef = useRef<number>(0);

  const { secondsLeft, isComplete } = useCountdown({
    targetDate: prisonUntil,
    onComplete: () => {
      fetchProfile();
      addToast("Cezaevinden çıktın!", "success");
    },
  });

  // Set initial prison time on first render
  if (initialPrisonTimeRef.current === 0 && secondsLeft > 0) {
    initialPrisonTimeRef.current = secondsLeft;
  }

  // Godot format: MM:SS  (Godot uses "%02d:%02d" % [mins, secs])
  const formattedCountdown = useMemo(() => {
    if (secondsLeft <= 0) return "00:00";
    const mins = Math.floor(secondsLeft / 60);
    const secs = secondsLeft % 60;
    return `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  }, [secondsLeft]);

  // Bail cost: max(1, ceil(remaining_seconds / 60))  — matches Godot exactly
  const bailCost = useMemo(() => {
    if (!inPrison || isComplete) return 0;
    return Math.max(1, Math.ceil(secondsLeft / 60));
  }, [secondsLeft, inPrison, isComplete]);

  // Progress: Godot uses 1 - (remaining / initial)
  const progress = useMemo(() => {
    if (initialPrisonTimeRef.current <= 0) return 0;
    return Math.max(0, Math.min(100, (1 - secondsLeft / initialPrisonTimeRef.current) * 100));
  }, [secondsLeft]);

  const handleBail = useCallback(async () => {
    if (gems < bailCost) {
      addToast("Yeterli elmas yok!", "warning");
      return;
    }
    setIsBailing(true);
    try {
      // Actual Supabase RPC: release_from_prison(p_use_bail)
      const result = await api.rpc("release_from_prison", { p_use_bail: true });
      if (result.success) {
        setReleased(true);
        addToast("Kefalet ödendi, serbest kaldın!", "success");
        await fetchProfile();
        setConfirmBail(false);
      } else {
        addToast(result.error || "Kefalet başarısız", "error");
      }
    } catch {
      addToast("Kefalet başarısız", "error");
    } finally {
      setIsBailing(false);
    }
  }, [gems, bailCost, fetchProfile, addToast]);

  // Not in prison — free state (Godot: "✅ Şu anda özgürsünüz!")
  if (!inPrison || isComplete || released) {
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
              👍
            </motion.span>
            <h2 className="text-lg font-bold text-[var(--text-primary)] mt-3">
              Cezaevi
            </h2>
            <p className="text-sm text-[var(--color-success)] mt-2">
              {released
                ? "Kefalet ödediniz. Artık özgürsünüz!"
                : "✅ Şu anda özgürsünüz!"}
            </p>
            <p className="text-xs text-[var(--text-muted)] mt-1">
              {released
                ? ""
                : "Gölge Ekonomi'de hukuk ve düzen sağlanıyor. Yasalara uyduğunuz sürece özgürsünüz!"}
            </p>
            <Button variant="secondary" size="sm" className="mt-4" onClick={() => router.push("/home")}>
              Ana Sayfaya Dön
            </Button>
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
            {/* Icon — Godot: "👮" when in prison */}
            <span className="text-5xl">👮</span>

            {/* Status — Godot: "⛓️ HAPİSHANESİNİZ!" */}
            <h2 className="text-lg font-bold text-[var(--color-error)] mt-3">
              ⛓️ HAPİSHANEDESİNİZ!
            </h2>

            {/* Reason — Godot: "📄 Gerekçe: {reason}" */}
            <p className="text-xs text-[var(--color-warning)] mt-1">
              📄 Gerekçe: {prisonReason || "Bilinmiyor"}
            </p>

            {/* Description — Godot description_label text */}
            <p className="text-xs text-[var(--text-muted)] mt-2 px-4">
              Yasalara aykırı davranışlar nedeniyle hapishanedesiniz. Kefalet ödeyerek erken çıkabilir veya sürenizi tamamlayabilirsiniz.
            </p>

            {/* Countdown — Godot: "⏱️ Kalan Süre: MM:SS" */}
            <div className="mt-4">
              <p className="text-3xl font-mono font-bold text-[var(--color-warning)]">
                ⏱️ {formattedCountdown}
              </p>
              <p className="text-xs text-[var(--text-muted)] mt-1">Kalan Süre</p>
            </div>

            {/* Progress Bar — Godot: progress = 1-(remaining/initial) */}
            <div className="mt-4">
              <ProgressBar value={progress} max={100} color="warning" size="md" />
            </div>

            {/* Gems display — Godot: "💎 Mevcut: X Elmas" */}
            <p className="text-xs text-[var(--color-gem)] mt-3">
              💎 Mevcut: {gems} Elmas
            </p>

            {/* Bail button — Godot: "💰 Kefalet Öde (X Elmas)" */}
            <div className="mt-4">
              <Button
                variant="gold"
                fullWidth
                disabled={gems < bailCost}
                onClick={() => setConfirmBail(true)}
              >
                💰 Kefalet Öde ({bailCost} Elmas)
              </Button>
              {gems < bailCost && (
                <p className="text-xs text-[var(--color-error)] mt-1">
                  Yeterli elmasınız yok! ({gems} / {bailCost})
                </p>
              )}
            </div>
          </div>
        </Card>
      </motion.div>

      {/* Confirm Bail Modal */}
      <Modal isOpen={confirmBail} onClose={() => setConfirmBail(false)} title="Kefalet Onayı" size="sm">
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            Cezaevinden çıkmak için <strong>{bailCost} elmas</strong> harcanacak.
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setConfirmBail(false)}>
              Vazgeç
            </Button>
            <Button variant="gold" size="sm" fullWidth isLoading={isBailing} onClick={handleBail}>
              💰 Kefalet Öde
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
