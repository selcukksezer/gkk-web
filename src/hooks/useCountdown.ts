// ============================================================
// useCountdown — Geri sayım hook'u
// Hospital, Prison, Crafting, Facility timer'ları için
// ============================================================

"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { secondsUntil, formatCountdown } from "@/lib/utils/datetime";

interface UseCountdownOptions {
  targetDate: string | null | undefined;
  onComplete?: () => void;
  interval?: number; // ms, default 1000
}

interface UseCountdownReturn {
  secondsLeft: number;
  formatted: string;
  isActive: boolean;
  isComplete: boolean;
}

export function useCountdown({
  targetDate,
  onComplete,
  interval = 1000,
}: UseCountdownOptions): UseCountdownReturn {
  const [secondsLeft, setSecondsLeft] = useState(() =>
    secondsUntil(targetDate ?? null)
  );
  const onCompleteRef = useRef(onComplete);
  onCompleteRef.current = onComplete;
  const completedRef = useRef(false);

  useEffect(() => {
    completedRef.current = false;
    setSecondsLeft(secondsUntil(targetDate ?? null));
  }, [targetDate]);

  useEffect(() => {
    if (!targetDate || secondsLeft <= 0) return;

    const timer = setInterval(() => {
      const remaining = secondsUntil(targetDate);
      setSecondsLeft(remaining);

      if (remaining <= 0 && !completedRef.current) {
        completedRef.current = true;
        clearInterval(timer);
        onCompleteRef.current?.();
      }
    }, interval);

    return () => clearInterval(timer);
  }, [targetDate, interval, secondsLeft]);

  return {
    secondsLeft,
    formatted: formatCountdown(secondsLeft),
    isActive: secondsLeft > 0,
    isComplete: secondsLeft <= 0 && !!targetDate,
  };
}
