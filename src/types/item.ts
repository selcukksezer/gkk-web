// ============================================================
// Item Types — Kaynak: core/data/ItemData.gd
// ============================================================

export type ItemType =
  | "weapon"
  | "armor"
  | "potion"
  | "consumable"
  | "material"
  | "recipe"
  | "scroll"
  | "rune"
  | "cosmetic";

export type Rarity =
  | "common"
  | "uncommon"
  | "rare"
  | "epic"
  | "legendary"
  | "mythic";

export type EquipSlot =
  | "weapon"
  | "chest"
  | "head"
  | "legs"
  | "boots"
  | "gloves"
  | "ring"
  | "necklace"
  | "none";

export type WeaponType =
  | "sword"
  | "axe"
  | "staff"
  | "bow"
  | "dagger"
  | "mace"
  | "none";

export type ArmorType =
  | "plate"
  | "chain"
  | "leather"
  | "robe"
  | "cloth"
  | "shield"
  | "none";

export type SubType =
  | "dagger"
  | "sword"
  | "axe"
  | "staff"
  | "plate"
  | "chain"
  | "leather"
  | "robe"
  | "helm"
  | "hood"
  | "crown"
  | "circlet"
  | "greaves"
  | "leggings"
  | "tassets"
  | "pteruges"
  | "sabaton"
  | "treads"
  | "sandals"
  | "moccasins"
  | "gauntlet"
  | "bracers"
  | "wraps"
  | "mitts"
  | "signet"
  | "band"
  | "loop"
  | "seal"
  | "pendant"
  | "amulet"
  | "choker"
  | "talisman"
  | "detox"
  | "none";

export type PotionType = "health" | "mana" | "energy" | "buff" | "none";

export interface ItemData {
  item_id: string;
  name: string;
  description: string;
  icon: string;
  item_type: ItemType;
  rarity: Rarity;
  facility_type?: string;
  base_price: number;
  vendor_sell_price: number;
  // Combat stats
  attack: number;
  defense: number;
  health: number;
  power: number;
  luck: number;
  mana: number;
  // Equipment
  equip_slot: EquipSlot;
  weapon_type: WeaponType;
  armor_type: ArmorType;
  sub_type: SubType;
  required_level: number;
  // Enhancement
  can_enhance: boolean;
  max_enhancement: number;
  enhancement_level: number;
  // Stacking
  is_stackable: boolean;
  max_stack: number;
  quantity: number;
  // Trade
  is_tradeable: boolean;
  is_han_only: boolean;
  is_market_tradeable: boolean;
  is_direct_tradeable: boolean;
  // Potion specifics
  potion_type: PotionType;
  energy_restore: number;
  health_restore: number;
  mana_restore: number;
  tolerance_increase: number;
  overdose_risk: number;
  buff_duration: number;
  // Material specifics
  material_type: string;
  production_building_type: string;
  production_rate_per_hour: number;
  // Rune specifics
  rune_enhancement_type: string;
  rune_success_bonus: number;
  rune_destruction_reduction: number;
  // Cosmetic specifics
  cosmetic_effect: string;
  cosmetic_bind_on_pickup: boolean;
}

// ============================================================
// Helper Functions — Kaynak: ItemData.gd utility methods
// ============================================================

export function isWeapon(item: ItemData): boolean {
  return item.item_type === "weapon";
}

export function isArmor(item: ItemData): boolean {
  return item.item_type === "armor";
}

export function isPotion(item: ItemData): boolean {
  return item.item_type === "potion";
}

export function isConsumable(item: ItemData): boolean {
  return item.item_type === "consumable";
}

export function isMaterial(item: ItemData): boolean {
  return item.item_type === "material";
}

export function isRecipe(item: ItemData): boolean {
  return item.item_type === "recipe";
}

export function isRune(item: ItemData): boolean {
  return item.item_type === "rune";
}

export function isCosmetic(item: ItemData): boolean {
  return item.item_type === "cosmetic";
}

export function isScroll(item: ItemData): boolean {
  return item.item_type === "scroll";
}

export function isEquippable(item: ItemData): boolean {
  return item.equip_slot !== "none";
}

export function getDisplayName(item: Pick<ItemData, "name" | "enhancement_level">): string {
  if (item.enhancement_level > 0) {
    return `+${item.enhancement_level} ${item.name}`;
  }
  return item.name;
}

export function getRarityColor(rarity: Rarity): string {
  const colors: Record<Rarity, string> = {
    common: "#E6E6E6",
    uncommon: "#33CC33",
    rare: "#4D80FF",
    epic: "#9933CC",
    legendary: "#FF8000",
    mythic: "#FF3333",
  };
  return colors[rarity];
}

export function getRarityLabel(rarity: Rarity): string {
  const labels: Record<Rarity, string> = {
    common: "Sıradan",
    uncommon: "Yaygın Olmayan",
    rare: "Nadir",
    epic: "Destansı",
    legendary: "Efsanevi",
    mythic: "Mitik",
  };
  return labels[rarity];
}
