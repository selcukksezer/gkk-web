// ============================================================
// Calculate Equipment Stats — Kuşanılmış ekipmanlardan istatistik hesaplama
// Kaynak: PLAN_01_ITEMS_EQUIPMENT.md → 2.5 Toplam Güç Hesaplaması
// ============================================================

import type { InventoryItem } from "@/types/inventory";

export interface EquipmentStats {
  totalAttack: number;
  totalDefense: number;
  totalHP: number;
  totalLuck: number;
  powerFromEquipment: number; // attack + defense + hp/10 + luck×2
}

export interface CharacterPowerBreakdown {
  equipmentPower: number;
  levelPower: number;
  reputationPower: number;
  totalPower: number;
}

/**
 * Calculate total stats from all equipped items
 * Formula (from PLAN 01):
 *   - Each item contributes: attack + defense + max(hp/10, 0) + luck×2
 */
export function calculateEquipmentStats(
  equippedItems: Record<string, InventoryItem | null>
): EquipmentStats {
  let totalAttack = 0;
  let totalDefense = 0;
  let totalHP = 0;
  let totalLuck = 0;

  Object.values(equippedItems).forEach((item) => {
    if (item) {
      totalAttack += item.attack || 0;
      totalDefense += item.defense || 0;
      totalHP += item.health || 0;
      totalLuck += item.luck || 0;
    }
  });

  // Power formula from PLAN 01: attack + defense + hp/10 + luck×2
  const powerFromEquipment = totalAttack + totalDefense + totalHP / 10 + totalLuck * 2;

  return {
    totalAttack,
    totalDefense,
    totalHP,
    totalLuck,
    powerFromEquipment,
  };
}

/**
 * Calculate total character power including level and reputation bonuses
 * Formula (from PLAN 01):
 *   total_power = powerFromEquipment + level × 500 + reputation × 0.1
 */
export function calculateTotalPower(
  equipmentStats: EquipmentStats,
  level: number,
  reputation: number
): number {
  return (
    equipmentStats.powerFromEquipment + 
    level * 500 + 
    reputation * 0.1
  );
}

export function calculateCharacterPowerBreakdown(
  equipmentStats: EquipmentStats,
  level: number,
  reputation: number
): CharacterPowerBreakdown {
  const equipmentPower = Math.round(Math.max(0, equipmentStats.powerFromEquipment));
  const levelPower = Math.max(0, Math.floor(level * 500));
  const reputationPower = Math.max(0, Math.floor(reputation * 0.1));
  const totalPower = equipmentPower + levelPower + reputationPower;

  return {
    equipmentPower,
    levelPower,
    reputationPower,
    totalPower,
  };
}
