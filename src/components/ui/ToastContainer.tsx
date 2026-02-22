// ============================================================
// Toast container — Global bildirim sistemi
// ============================================================

"use client";

import { useUIStore } from "@/stores/uiStore";
import { motion, AnimatePresence } from "framer-motion";
import { cn } from "@/lib/utils/cn";

const TOAST_STYLES: Record<string, string> = {
  success: "bg-green-600/90 border-green-500",
  error: "bg-red-600/90 border-red-500",
  warning: "bg-yellow-600/90 border-yellow-500",
  info: "bg-blue-600/90 border-blue-500",
};

const TOAST_ICONS: Record<string, string> = {
  success: "✅",
  error: "❌",
  warning: "⚠️",
  info: "ℹ️",
};

export function ToastContainer() {
  const toasts = useUIStore((s) => s.toasts);
  const removeToast = useUIStore((s) => s.removeToast);

  return (
    <div className="fixed top-16 right-4 z-[100] flex flex-col gap-2 pointer-events-none">
      <AnimatePresence>
        {toasts.map((toast) => (
          <motion.div
            key={toast.id}
            initial={{ opacity: 0, x: 100, scale: 0.9 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            exit={{ opacity: 0, x: 100, scale: 0.9 }}
            transition={{ type: "spring", duration: 0.4, bounce: 0.25 }}
            className={cn(
              "pointer-events-auto flex items-center gap-2 px-4 py-3 rounded-lg border backdrop-blur-sm text-white text-sm max-w-xs shadow-lg cursor-pointer",
              TOAST_STYLES[toast.type]
            )}
            onClick={() => removeToast(toast.id)}
          >
            <span>{TOAST_ICONS[toast.type]}</span>
            <span>{toast.message}</span>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
