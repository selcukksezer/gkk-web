// ============================================================
// Inventory Types — Kaynak: core/data/InventoryItemData.gd
// ============================================================

import type { ItemType, Rarity, EquipSlot, WeaponType, ArmorType, PotionType } from "./item";

/**
 * InventoryItem = veritabanındaki envanter satırı + item meta verisi
 * Backend RPC'den gelen yanıt her iki bilgiyi de içerir.
 */
export interface InventoryItem {
  // Inventory row
  row_id: string;
  item_id: string;
  quantity: number;
  slot_position: number; // 0-19 (20 slot)
  is_equipped: boolean;
  equipped_slot: string; // EquipSlot string or ''
  enhancement_level: number;
  pending_sync: boolean;

  // Item catalog data (joined from items table)
  name: string;
  description: string;
  icon: string;
  item_type: ItemType;
  rarity: Rarity;
  base_price: number;
  vendor_sell_price: number;

  // Combat stats
  attack: number;
  defense: number;
  health: number;
  power: number;
  mana: number;

  // Equipment
  equip_slot: EquipSlot;
  weapon_type: WeaponType;
  armor_type: ArmorType;
  required_level: number;

  // Enhancement
  can_enhance: boolean;
  max_enhancement: number;

  // Stacking
  is_stackable: boolean;
  max_stack: number;

  // Trade
  is_tradeable: boolean;

  // Potion
  potion_type: PotionType;
  energy_restore: number;
  health_restore: number;
  tolerance_increase: number;
}

export const INVENTORY_CAPACITY = 20;
