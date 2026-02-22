// ============================================================
// UpgradeResultEffect — Geliştirme sonucu animasyonu
// ============================================================

"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useEffect, useState } from "react";

interface UpgradeResultEffectProps {
  show: boolean;
  success: boolean;
  onDone?: () => void;
}

export function UpgradeResultEffect({ show, success, onDone }: UpgradeResultEffectProps) {
  const [visible, setVisible] = useState(show);

  useEffect(() => {
    if (show) {
      setVisible(true);
      const t = setTimeout(() => {
        setVisible(false);
        onDone?.();
      }, 2000);
      return () => clearTimeout(t);
    }
  }, [show, onDone]);

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[100] flex items-center justify-center pointer-events-none"
        >
          <motion.div
            initial={{ scale: 0.3, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 1.5, opacity: 0 }}
            transition={{ type: "spring", stiffness: 300, damping: 20 }}
            className="flex flex-col items-center gap-2"
          >
            <span className="text-7xl">{success ? "✨" : "💥"}</span>
            <span
              className="text-2xl font-black"
              style={{ color: success ? "#22c55e" : "#ef4444" }}
            >
              {success ? "BAŞARILI!" : "BAŞARISIZ!"}
            </span>
          </motion.div>

          {/* Particle ring */}
          {success && (
            <>
              {Array.from({ length: 8 }).map((_, i) => {
                const angle = (i / 8) * Math.PI * 2;
                return (
                  <motion.span
                    key={i}
                    initial={{ x: 0, y: 0, opacity: 1, scale: 1 }}
                    animate={{
                      x: Math.cos(angle) * 120,
                      y: Math.sin(angle) * 120,
                      opacity: 0,
                      scale: 0.3,
                    }}
                    transition={{ duration: 1, ease: "easeOut" }}
                    className="absolute text-xl"
                  >
                    ⭐
                  </motion.span>
                );
              })}
            </>
          )}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
