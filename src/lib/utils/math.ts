// ============================================================
// Math Utilities — Kaynak: core/utils/MathHelper.gd
// ============================================================

/**
 * XP hesaplama formülü: base_xp * (level ^ 1.5)
 * Kaynak: StateStore.gd xp_for_next_level()
 */
export function xpForNextLevel(level: number): number {
  const baseXp = 100;
  return Math.floor(baseXp * Math.pow(level, 1.5));
}

/**
 * Toplam XP: Seviye 1'den current level'a kadar gereken toplam XP
 */
export function totalXpForLevel(level: number): number {
  let total = 0;
  for (let i = 1; i < level; i++) {
    total += xpForNextLevel(i);
  }
  return total;
}

/**
 * XP ilerleme yüzdesi
 */
export function xpProgress(currentXp: number, level: number): number {
  const needed = xpForNextLevel(level);
  if (needed <= 0) return 1;
  return Math.min(currentXp / needed, 1);
}

/**
 * Power skoru hesaplama
 * Kaynak: StateStore.gd _calculate_power()
 */
export function calculatePower(stats: {
  attack: number;
  defense: number;
  health: number;
  level: number;
}): number {
  return Math.floor(
    stats.attack * 1.5 +
    stats.defense * 1.2 +
    stats.health * 0.5 +
    stats.level * 10
  );
}

/**
 * Enhancement başarı oranı  
 * Kaynak: game_config.json enhancement.success_rates
 */
export function getEnhancementSuccessRate(level: number): number {
  const rates = [1.0, 1.0, 1.0, 1.0, 0.8, 0.8, 0.6, 0.6, 0.4, 0.2, 0.1];
  if (level < 0 || level >= rates.length) return 0;
  return rates[level];
}

/**
 * Enhancement yıkılma oranı
 * Kaynak: game_config.json enhancement.destruction_rates
 */
export function getEnhancementDestructionRate(level: number): number {
  const rates = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.1, 0.15];
  if (level < 0 || level >= rates.length) return 0;
  return rates[level];
}

/**
 * Stat bonusu: enhancement başına %10
 * Kaynak: game_config.json enhancement.stat_bonus_per_level
 */
export function getEnhancementStatBonus(baseValue: number, enhancementLevel: number): number {
  return Math.floor(baseValue * (1 + enhancementLevel * 0.1));
}

/**
 * PvP stolen gold hesaplama
 * Kaynak: game_config.json pvp.gold_steal_percentage = 5%
 */
export function calculateStolenGold(defenderGold: number): number {
  return Math.floor(defenderGold * 0.05);
}

/**
 * Tesis üretim oranı hesaplama
 * Kaynak: FacilityManager.gd _calculate_rate()
 */
export function calculateFacilityRate(baseRate: number, facilityLevel: number): number {
  return baseRate * facilityLevel;
}

/**
 * Upgrade maliyetini hesapla
 * Kaynak: FacilityManager.gd upgrade_cost hesaplama
 */
export function calculateUpgradeCost(
  baseUpgradeCost: number,
  upgradeMultiplier: number,
  currentLevel: number
): number {
  return Math.floor(baseUpgradeCost * Math.pow(upgradeMultiplier, currentLevel - 1));
}

/**
 * Clamp utility
 */
export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/**
 * Lerp utility
 */
export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * clamp(t, 0, 1);
}

/**
 * Rastgele sayı [min, max] aralığında
 */
export function randomRange(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * Yüzde formatla
 */
export function formatPercent(value: number, decimals = 0): string {
  return `${(value * 100).toFixed(decimals)}%`;
}
