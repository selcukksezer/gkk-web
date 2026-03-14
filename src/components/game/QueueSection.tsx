// ============================================================
// QueueSection Component — Üretim Kuyruğu Görünümü
// Kuyruktaki öğeler, talep edilme, progres göstergesi
// ============================================================

"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ItemIcon } from "@/components/game/ItemIcon";
import type { CraftQueueItem } from "@/types/crafting";

interface QueueSectionProps {
  queue: CraftQueueItem[];
  onClaim: (queueItemId: string) => void;
  onAcknowledge?: (queueItemId: string) => void;
  onFinalize?: (queueItemId: string) => void;
  onCancel: (queueItemId: string) => void;
  isClaiming?: boolean;
  isCancelling?: boolean;
}

function getRemainingTime(completesAt: string): { time: string; isComplete: boolean } {
  const now = new Date().getTime();
  const complete = new Date(completesAt).getTime();
  const diff = complete - now;

  if (diff <= 0) return { time: "Hazır!", isComplete: true };

  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  const seconds = Math.floor((diff % (1000 * 60)) / 1000);

  if (hours > 0) return { time: `${hours}sa ${minutes}dk`, isComplete: false };
  if (minutes > 0) return { time: `${minutes}dk ${seconds}sn`, isComplete: false };
  return { time: `${seconds}sn`, isComplete: false };
}

export function QueueSection({ queue, onClaim, onAcknowledge, onFinalize, onCancel, isClaiming = false, isCancelling = false }: QueueSectionProps) {
  const [timeUpdates, setTimeUpdates] = useState<Record<string, { time: string; isComplete: boolean }>>({});
  const [isExpanded, setIsExpanded] = useState(false);
  const [showCancelConfirm, setShowCancelConfirm] = useState<string | null>(null);
  const [pendingAcks, setPendingAcks] = useState<Record<string, boolean>>({});
  const [pendingClaims, setPendingClaims] = useState<Record<string, boolean>>({});
  const [pendingFinalizes, setPendingFinalizes] = useState<Record<string, boolean>>({});
  const onFinalizeRef = useRef<typeof onFinalize | undefined>(onFinalize);
  // keep the ref up-to-date without adding it to the effect deps
  onFinalizeRef.current = onFinalize;

  // Update remaining times every second
  useEffect(() => {
    const interval = setInterval(() => {
      const updates: Record<string, { time: string; isComplete: boolean }> = {};
      queue.forEach((item) => {
        updates[item.id] = getRemainingTime(item.completes_at);
      });
      setTimeUpdates(updates);
      // Auto-finalize items that just completed (server will decide success/fail)
      queue.forEach((item) => {
        const t = updates[item.id];
        if (!t) return;
        const becameComplete = t.isComplete && !item.is_completed && !item.failed && !item.claimed;
        const fn = onFinalizeRef.current;
        if (becameComplete && fn) {
          setPendingFinalizes((prev) => {
            if (prev[item.id]) return prev;
            const next = { ...prev, [item.id]: true };
            // async finalize and clear flag when done
            (async () => {
              try {
                await fn(item.id);
              } catch (e) {
                // ignore
              } finally {
                setPendingFinalizes((p) => ({ ...p, [item.id]: false }));
              }
            })();
            return next;
          });
        }
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [queue]);

  if (queue.length === 0) {
    return (
      <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/8 to-white/[0.02] backdrop-blur-2xl p-8 text-center">
        <p className="text-white/50">Kuyruğunuzda hiç üretim yok</p>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/8 to-white/[0.02] backdrop-blur-2xl overflow-hidden">
      {/* Collapsible Header */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full px-4 py-3 flex items-center justify-between hover:bg-white/5 transition-colors"
      >
        <h3 className="font-bold text-white">📦 Üretim Kuyruğu ({queue.length})</h3>
        <motion.div
          animate={{ rotate: isExpanded ? 180 : 0 }}
          transition={{ duration: 0.2 }}
          className="text-white/60"
        >
          ▼
        </motion.div>
      </button>

      {/* Content - Collapsible */}
      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="border-t border-white/10 px-4 py-3 space-y-2 max-h-96 overflow-y-auto"
          >
            <AnimatePresence mode="popLayout">
              {queue.map((item) => {
                const timeInfo = timeUpdates[item.id] || getRemainingTime(item.completes_at);
                const isTimeComplete = timeInfo.isComplete;
                const serverCompleted = !!item.is_completed;
                const showClaimButton = serverCompleted && !item.claimed && !item.failed;
                const awaitingFinalize = isTimeComplete && !serverCompleted && !item.failed && !item.claimed;
                // progress percent based on started_at -> completes_at
                const started = new Date(item.started_at).getTime();
                const completes = new Date(item.completes_at).getTime();
                const now = Date.now();
                let progressPercent = 0;
                if (completes <= started) progressPercent = 100;
                else progressPercent = Math.min(100, Math.max(0, Math.round(((now - started) / (completes - started)) * 100)));

                return (
                  <motion.div
                    key={item.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: 20 }}
                    className={`rounded-lg p-3 border ${
                      serverCompleted && item.failed
                        ? "border-red-500/50 bg-red-500/10"
                        : serverCompleted && !item.failed
                        ? "border-green-500/50 bg-green-500/10"
                        : "border-white/20 bg-white/5"
                    }`}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-3">
                        <ItemIcon icon={item.recipe_icon} itemId={item.recipe_id} className="w-10 h-10" />
                        <div>
                          <p className="font-bold text-sm text-white">{item.output_name || item.recipe_name}</p>
                          <div className="flex items-center gap-2">
                            <p className="text-xs text-white/60">x{item.batch_count} adet</p>
                            {serverCompleted && !item.failed && item.xp_reward ? (
                              <span className="text-xs bg-yellow-600/20 text-yellow-300 px-2 py-0.5 rounded">
                                +{item.xp_reward * item.batch_count} XP
                              </span>
                            ) : null}
                          </div>
                        </div>
                      </div>
                      <div className="text-right">
                            <p className={`text-xs font-bold ${serverCompleted && item.failed ? "text-red-300" : serverCompleted ? "text-green-300" : "text-yellow-300"}`}>
                              {serverCompleted && item.failed ? "" : timeInfo.time}
                            </p>
                      </div>
                    </div>

                    {/* Progress Bar */}
                    {!serverCompleted && (
                      <div className="w-full h-1.5 rounded-full bg-white/10 overflow-hidden mb-2">
                        <motion.div
                          initial={{ width: "0%" }}
                          animate={{ width: `${progressPercent}%` }}
                          transition={{ ease: "linear", duration: 0.5 }}
                          className="h-full bg-gradient-to-r from-blue-600 to-purple-600"
                        />
                      </div>
                    )}

                    {/* Action Buttons */}
                    {serverCompleted && item.failed ? (
                      <div className="flex gap-2">
                        <div className="flex-1 py-2 rounded-lg bg-red-600/20 text-red-200 text-xs font-bold text-center border border-red-500/50">
                          ❌ Üretim Başarısız
                        </div>
                        <button
                          onClick={async () => {
                            if (!onAcknowledge) return;
                            if (pendingAcks[item.id]) return;
                            setPendingAcks((s) => ({ ...s, [item.id]: true }));
                            try {
                              await onAcknowledge(item.id);
                            } finally {
                              setPendingAcks((s) => ({ ...s, [item.id]: false }));
                            }
                          }}
                          disabled={pendingAcks[item.id]}
                          className="px-3 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold transition-all disabled:opacity-50"
                        >
                          {pendingAcks[item.id] ? "İşleniyor..." : "Tamam"}
                        </button>
                      </div>
                    ) : showClaimButton ? (
                      <button
                        onClick={async () => {
                          // prevent double clicks per item
                          if (pendingClaims[item.id]) return;
                          setPendingClaims((s) => ({ ...s, [item.id]: true }));
                          try {
                            await onClaim(item.id as string);
                          } finally {
                            setPendingClaims((s) => ({ ...s, [item.id]: false }));
                          }
                        }}
                        disabled={isClaiming || !!pendingClaims[item.id]}
                        className="w-full py-2 rounded-lg bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 text-white text-xs font-bold transition-all disabled:opacity-50"
                      >
                        {isClaiming || pendingClaims[item.id] ? "Talep Ediliyor..." : "✓ Talep Et"}
                      </button>
                    ) : item.claimed ? (
                      <div className="w-full py-2 rounded-lg bg-white/10 text-white text-xs font-bold text-center">
                        ✓ Talep Edildi
                      </div>
                    ) : awaitingFinalize ? (
                      <div className="w-full py-2 rounded-lg bg-white/10 text-white text-xs font-bold text-center">
                        Tamamlanıyor...
                      </div>
                    ) : (
                      <div className="flex gap-2">
                        <div className="flex-1 py-2 rounded-lg bg-white/10 text-white text-xs font-bold text-center">
                          Üretiliyor...
                        </div>
                        <button
                          onClick={() => setShowCancelConfirm(item.id)}
                          disabled={isCancelling}
                          className="px-3 py-2 rounded-lg bg-red-600/20 hover:bg-red-600/40 border border-red-500/50 text-red-300 text-xs font-bold transition-all disabled:opacity-50"
                          title="İptal Et (Ödül Geri Verilmez)"
                        >
                          ✕
                        </button>
                      </div>
                    )}

                    {/* Cancel Confirmation Dialog */}
                    {showCancelConfirm === item.id && (
                      <motion.div
                        initial={{ opacity: 0, scale: 0.9 }}
                        animate={{ opacity: 1, scale: 1 }}
                        exit={{ opacity: 0, scale: 0.9 }}
                        className="absolute inset-0 flex items-center justify-center bg-black/60 backdrop-blur-sm rounded-lg p-4 z-50"
                      >
                        <div className="bg-slate-900 border border-red-500/50 rounded-lg p-4 max-w-sm">
                          <h4 className="font-bold text-red-300 mb-2">⚠️ Üretim İptal Et?</h4>
                          <p className="text-white/70 text-xs mb-4">
                            Bu işlem geri alınamaz. <strong>Ödül geri verilmeyecektir!</strong>
                          </p>
                          <div className="flex gap-2">
                            <button
                              onClick={() => setShowCancelConfirm(null)}
                              className="flex-1 py-2 rounded-lg bg-white/10 hover:bg-white/20 text-white text-xs font-bold transition-all"
                            >
                              Vazgeç
                            </button>
                            <button
                              onClick={() => {
                                onCancel(item.id);
                                setShowCancelConfirm(null);
                              }}
                              disabled={isCancelling}
                              className="flex-1 py-2 rounded-lg bg-red-600 hover:bg-red-700 text-white text-xs font-bold transition-all disabled:opacity-50"
                            >
                              {isCancelling ? "İptal Ediliyor..." : "Evet, İptal Et"}
                            </button>
                          </div>
                        </div>
                      </motion.div>
                    )}
                  </motion.div>
                );
              })}
            </AnimatePresence>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
