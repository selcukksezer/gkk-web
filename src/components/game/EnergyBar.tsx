// ============================================================
// EnergyBar — Enerji çubuğu + yenilenme zamanlayıcısı
// ============================================================

"use client";

import { usePlayerStore } from "@/stores";
import { useEnergyRegen } from "@/hooks";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { GAME_CONFIG } from "@/data/GameConstants";
import { useState, useEffect } from "react";

interface EnergyBarProps {
  compact?: boolean;
}

export function EnergyBar({ compact }: EnergyBarProps) {
  const player = usePlayerStore((s) => s.player);
  const energy = player?.energy ?? 0;
  const maxEnergy = player?.max_energy ?? 100;

  // Start regen timer
  useEnergyRegen();

  // Simple countdown for next regen tick
  const regenInterval = GAME_CONFIG.energy.regenInterval ?? 180;
  const [timeLeft, setTimeLeft] = useState(energy < maxEnergy ? regenInterval : 0);

  useEffect(() => {
    if (energy >= maxEnergy) { setTimeLeft(0); return; }
    setTimeLeft(regenInterval);
    const t = setInterval(() => {
      setTimeLeft((prev) => {
        if (prev <= 1) return regenInterval;
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(t);
  }, [energy, maxEnergy, regenInterval]);

  const pct = Math.min((energy / maxEnergy) * 100, 100);

  if (compact) {
    return (
      <div className="flex items-center gap-1.5">
        <span className="text-xs">⚡</span>
        <span className="text-xs font-medium">
          {energy}/{maxEnergy}
        </span>
      </div>
    );
  }

  return (
    <div className="w-full">
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs font-medium">⚡ Enerji</span>
        <span className="text-xs text-[var(--text-secondary)]">
          {energy}/{maxEnergy}
        </span>
      </div>
      <ProgressBar value={pct} max={100} />
      {energy < maxEnergy && timeLeft > 0 && (
        <p className="text-[10px] text-[var(--text-secondary)] mt-0.5 text-right">
          Sonraki: {Math.floor(timeLeft / 60)}:{String(timeLeft % 60).padStart(2, "0")}
        </p>
      )}
    </div>
  );
}
