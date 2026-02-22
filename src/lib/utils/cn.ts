// ============================================================
// CSS / Style Utilities — clsx + tailwind-merge
// ============================================================

import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

/**
 * Tailwind class merging utility
 * Kullanım: cn("bg-red-500", isActive && "bg-green-500")
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
