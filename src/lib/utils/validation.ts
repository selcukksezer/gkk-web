// ============================================================
// Validation Utilities — Kaynak: core/utils/ValidationHelper.gd
// ============================================================

import { parseDate } from "@/lib/utils/datetime";

/**
 * Envanter kapasitesi kontrolü
 */
export function canAddToInventory(currentCount: number, maxSlots = 20): boolean {
  return currentCount < maxSlots;
}

/**
 * Enerji yeterliliği kontrolü
 */
export function hasEnoughEnergy(currentEnergy: number, cost: number): boolean {
  return currentEnergy >= cost;
}

/**
 * Gold yeterliliği kontrolü
 */
export function hasEnoughGold(currentGold: number, cost: number): boolean {
  return currentGold >= cost;
}

/**
 * Gem yeterliliği kontrolü
 */
export function hasEnoughGems(currentGems: number, cost: number): boolean {
  return currentGems >= cost;
}

/**
 * Level gereksinimi kontrolü
 */
export function meetsLevelRequirement(playerLevel: number, requiredLevel: number): boolean {
  return playerLevel >= requiredLevel;
}

/**
 * Hastanede mi? (hospital_until kontrolü)
 */
export function isInHospital(hospitalUntil: string | null): boolean {
  if (!hospitalUntil) return false;
  const d = parseDate(hospitalUntil);
  if (!d) return false;
  return d > new Date();
}

/**
 * Hapishanede mi? (prison_until kontrolü)
 */
export function isInPrison(prisonUntil: string | null): boolean {
  if (!prisonUntil) return false;
  const d = parseDate(prisonUntil);
  if (!d) return false;
  return d > new Date();
}

/**
 * Oyuncu engelli mi? (hospital veya prison)
 */
export function isPlayerRestricted(hospitalUntil: string | null, prisonUntil: string | null): boolean {
  return isInHospital(hospitalUntil) || isInPrison(prisonUntil);
}

/**
 * PvP saldırı yapılabilir mi?
 */
export function canAttackPvP(
  currentEnergy: number,
  isInHosp: boolean,
  isInPris: boolean,
  dailyAttacks: number,
  maxAttacks = 50
): boolean {
  if (isInHosp || isInPris) return false;
  if (dailyAttacks >= maxAttacks) return false;
  return currentEnergy >= 15; // PvP energy cost
}

/**
 * Market sipariş yapılabilir mi?
 */
export function canCreateOrder(
  currentOrders: number,
  maxOrders = 50,
  playerGold: number,
  orderCost: number
): boolean {
  return currentOrders < maxOrders && playerGold >= orderCost;
}

/**
 * Enhancement yapılabilir mi?
 */
export function canEnhanceItem(
  currentEnhancement: number,
  maxEnhancement: number,
  playerGold: number,
  scrollCost: number
): boolean {
  return currentEnhancement < maxEnhancement && playerGold >= scrollCost;
}
