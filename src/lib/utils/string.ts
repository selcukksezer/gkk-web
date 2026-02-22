// ============================================================
// String Utilities — Kaynak: core/utils/StringHelper.gd
// ============================================================

/**
 * Gold formatla: 1000 → "1.000", 1234567 → "1.234.567"
 */
export function formatGold(amount: number): string {
  return new Intl.NumberFormat("tr-TR").format(amount);
}

/**
 * Kısa sayı formatı: 1000 → "1K", 1500000 → "1.5M"
 */
export function formatCompact(amount: number): string {
  if (amount >= 1_000_000) {
    return `${(amount / 1_000_000).toFixed(1)}M`;
  }
  if (amount >= 1_000) {
    return `${(amount / 1_000).toFixed(1)}K`;
  }
  return amount.toString();
}

/**
 * Gem sembolü ile formatla
 */
export function formatGems(amount: number): string {
  return `💎 ${formatGold(amount)}`;
}

/**
 * Enerji sembolü ile formatla
 */
export function formatEnergy(current: number, max: number): string {
  return `⚡ ${current}/${max}`;
}

/**
 * Rarity → Türkçe isim
 */
export function rarityLabel(rarity: string): string {
  const labels: Record<string, string> = {
    common: "Sıradan",
    uncommon: "Yaygın Olmayan",
    rare: "Nadir",
    epic: "Destansı",
    legendary: "Efsanevi",
    mythic: "Mitik",
  };
  return labels[rarity] || rarity;
}

/**
 * Truncate: "çok uzun bir metin..." 
 */
export function truncate(str: string, maxLength: number): string {
  if (str.length <= maxLength) return str;
  return str.slice(0, maxLength - 3) + "...";
}

/**
 * Username doğrulama: 3-20 karakter, alfanumerik + _
 */
export function isValidUsername(name: string): boolean {
  return /^[a-zA-Z0-9_]{3,20}$/.test(name);
}

/**
 * Email doğrulama
 */
export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/**
 * Şifre gücü kontrolü (min 6 karakter)
 */
export function isValidPassword(password: string): boolean {
  return password.length >= 6;
}

/**
 * Capitalize first letter
 */
export function capitalize(str: string): string {
  if (!str) return "";
  return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * Snake case → display: "lumber_mill" → "Lumber Mill"
 */
export function snakeToDisplay(str: string): string {
  return str
    .split("_")
    .map((word) => capitalize(word))
    .join(" ");
}
