// ============================================================
// QueueSection Component — Üretim Kuyruğu Görünümü
// Kuyruktaki öğeler, talep edilme, progres göstergesi
// ============================================================

"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import type { CraftQueueItem } from "@/types/crafting";

interface QueueSectionProps {
  queue: CraftQueueItem[];
  onClaim: (queueItemId: string) => void;
  isClaiming?: boolean;
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

export function QueueSection({ queue, onClaim, isClaiming = false }: QueueSectionProps) {
  const [timeUpdates, setTimeUpdates] = useState<Record<string, { time: string; isComplete: boolean }>>({});

  // Update remaining times every second
  useEffect(() => {
    const interval = setInterval(() => {
      const updates: Record<string, { time: string; isComplete: boolean }> = {};
      queue.forEach((item) => {
        updates[item.id] = getRemainingTime(item.completes_at);
      });
      setTimeUpdates(updates);
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
    <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/8 to-white/[0.02] backdrop-blur-2xl p-4 space-y-2">
      <h3 className="font-bold text-white mb-3">📦 Üretim Kuyruğu ({queue.length})</h3>

      <AnimatePresence mode="popLayout">
        {queue.map((item) => {
          const timeInfo = timeUpdates[item.id] || getRemainingTime(item.completes_at);

          return (
            <motion.div
              key={item.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              className={`rounded-lg p-3 border ${
                item.is_completed ? "border-green-500/50 bg-green-500/10" : "border-white/20 bg-white/5"
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <div>
                  <p className="font-bold text-sm text-white">{item.recipe_name}</p>
                  <p className="text-xs text-white/60">x{item.batch_count} adet</p>
                </div>
                <div className="text-right">
                  <p className={`text-xs font-bold ${timeInfo.isComplete ? "text-green-300" : "text-yellow-300"}`}>
                    {timeInfo.time}
                  </p>
                </div>
              </div>

              {/* Progress Bar */}
              <div className="w-full h-1.5 rounded-full bg-white/10 overflow-hidden mb-2">
                <motion.div
                  initial={{ width: "0%" }}
                  animate={{ width: item.is_completed ? "100%" : "50%" }}
                  className="h-full bg-gradient-to-r from-blue-600 to-purple-600"
                />
              </div>

              {/* Action Button */}
              {item.is_completed && !item.claimed ? (
                <button
                  onClick={() => onClaim(item.id)}
                  disabled={isClaiming}
                  className="w-full py-2 rounded-lg bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 text-white text-xs font-bold transition-all disabled:opacity-50"
                >
                  {isClaiming ? "Talep Ediliyor..." : "✓ Talep Et"}
                </button>
              ) : (
                <div className="w-full py-2 rounded-lg bg-white/10 text-white text-xs font-bold text-center">
                  {item.claimed ? "✓ Talep Edildi" : "Üretiliyor..."}
                </div>
              )}
            </motion.div>
          );
        })}
      </AnimatePresence>
    </div>
  );
}
