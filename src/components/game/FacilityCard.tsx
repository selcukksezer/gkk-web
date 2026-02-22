// ============================================================
// FacilityCard — Tesis kartı (liste görünümü)
// ============================================================

"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import type { FacilityType } from "@/types/facility";
import { FACILITIES_CONFIG } from "@/data/FacilityConfig";

interface FacilityCardProps {
  type: FacilityType;
  level: number;
  isUnlocked: boolean;
  isProducing: boolean;
  suspicion: number;
}

export function FacilityCard({ type, level, isUnlocked, isProducing, suspicion }: FacilityCardProps) {
  const config = FACILITIES_CONFIG[type];
  if (!config) return null;

  return (
    <Link href={`/facilities/${type}`}>
      <motion.div
        whileTap={{ scale: 0.98 }}
        className={`bg-[var(--card-bg)] border rounded-xl p-4 ${
          isUnlocked ? "border-[var(--border)]" : "border-dashed border-[var(--border)] opacity-60"
        }`}
      >
        <div className="flex items-center gap-3">
          <span className="text-2xl">{config.icon}</span>
          <div className="flex-1">
            <h3 className="font-medium">{config.name}</h3>
            <p className="text-xs text-[var(--text-secondary)]">
              {isUnlocked ? `Seviye ${level}` : "Kilitli"}
            </p>
          </div>
          {isProducing && (
            <span className="text-xs bg-green-600/20 text-green-400 px-2 py-0.5 rounded-full">
              Üretim
            </span>
          )}
        </div>
        {isUnlocked && suspicion > 0 && (
          <div className="mt-2">
            <SuspicionBar value={suspicion} />
          </div>
        )}
      </motion.div>
    </Link>
  );
}

// Inline SuspicionBar for card display
function SuspicionBar({ value }: { value: number }) {
  const color =
    value < 30 ? "#22c55e" : value < 60 ? "#eab308" : value < 80 ? "#f97316" : "#ef4444";
  return (
    <div className="w-full h-1.5 bg-[var(--surface)] rounded-full overflow-hidden">
      <div
        className="h-full rounded-full transition-all duration-300"
        style={{ width: `${Math.min(value, 100)}%`, backgroundColor: color }}
      />
    </div>
  );
}
