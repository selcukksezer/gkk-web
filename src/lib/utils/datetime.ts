// ============================================================
// DateTime Utilities — Kaynak: core/utils/DateTimeHelper.gd
// ============================================================

import { formatDistanceToNow, differenceInSeconds, differenceInMinutes, format, parseISO } from "date-fns";
import { tr } from "date-fns/locale";

/**
 * ISO string → Date parse (null-safe)
 */
export function parseDate(dateStr: string | null | undefined): Date | null {
  if (!dateStr) return null;
  try {
    return parseISO(dateStr);
  } catch {
    return null;
  }
}

/**
 * Geçen süre: "2 saat önce", "3 dakika önce" vb.
 */
export function timeAgo(dateStr: string | null): string {
  const d = parseDate(dateStr);
  if (!d) return "";
  return formatDistanceToNow(d, { addSuffix: true, locale: tr });
}

/**
 * Kalan süre hesaplama (saniye)
 */
export function secondsUntil(targetDateStr: string | null): number {
  const d = parseDate(targetDateStr);
  if (!d) return 0;
  return Math.max(0, differenceInSeconds(d, new Date()));
}

/**
 * Kalan süre hesaplama (dakika)
 */
export function minutesUntil(targetDateStr: string | null): number {
  const d = parseDate(targetDateStr);
  if (!d) return 0;
  return Math.max(0, differenceInMinutes(d, new Date()));
}

/**
 * Süre aktif mi? (hospital_until, prison_until)
 */
export function isActive(untilDateStr: string | null): boolean {
  return secondsUntil(untilDateStr) > 0;
}

/**
 * Geri sayım formatı: "02:15:30" veya "15dk 30s"
 */
export function formatCountdown(totalSeconds: number): string {
  if (totalSeconds <= 0) return "00:00";

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = Math.floor(totalSeconds % 60);

  if (hours > 0) {
    return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
  }
  return `${pad(minutes)}:${pad(seconds)}`;
}

/**
 * Kısa geri sayım: "2s 15dk" formatında
 */
export function formatCountdownShort(totalSeconds: number): string {
  if (totalSeconds <= 0) return "0s";

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const secs = Math.floor(totalSeconds % 60);

  const parts: string[] = [];
  if (hours > 0) parts.push(`${hours}s`);
  if (minutes > 0) parts.push(`${minutes}dk`);
  if (secs > 0 && hours === 0) parts.push(`${secs}sn`);

  return parts.join(" ");
}

/**
 * Tarih formatla (Türkçe)
 */
export function formatDate(dateStr: string | null, pattern = "dd MMM yyyy HH:mm"): string {
  const d = parseDate(dateStr);
  if (!d) return "";
  return format(d, pattern, { locale: tr });
}

/**
 * Hospital süresi metin: "2 saat 30 dakika"
 */
export function formatDuration(totalMinutes: number): string {
  const hours = Math.floor(totalMinutes / 60);
  const mins = totalMinutes % 60;

  if (hours > 0 && mins > 0) return `${hours} saat ${mins} dakika`;
  if (hours > 0) return `${hours} saat`;
  return `${mins} dakika`;
}

/**
 * Enerji yenilenme zamanı hesapla
 * Kaynak: game_config.json energy.regen_interval = 180s
 */
export function nextEnergyRegenTime(lastRegenAt: string | null): number {
  const d = parseDate(lastRegenAt);
  if (!d) return 0;
  const nextRegen = new Date(d.getTime() + 180 * 1000);
  return Math.max(0, differenceInSeconds(nextRegen, new Date()));
}

function pad(n: number): string {
  return n.toString().padStart(2, "0");
}
