// ============================================================
// Item Database — Kaynak: ItemDatabase.gd (839 satır)
// Tüm oyun item'ları statik obje olarak
// ============================================================

import type { ItemData } from "@/types/item";

// Partial defaults — missing fields fallback
const defaults: Omit<ItemData, "item_id" | "name" | "description" | "icon" | "item_type" | "rarity"> = {
  base_price: 0,
  vendor_sell_price: 0,
  attack: 0,
  defense: 0,
  health: 0,
  power: 0,
  mana: 0,
  equip_slot: "none",
  weapon_type: "none",
  armor_type: "none",
  required_level: 1,
  can_enhance: false,
  max_enhancement: 0,
  enhancement_level: 0,
  is_stackable: false,
  max_stack: 1,
  quantity: 1,
  is_tradeable: true,
  potion_type: "none",
  energy_restore: 0,
  health_restore: 0,
  mana_restore: 0,
  tolerance_increase: 0,
  overdose_risk: 0,
  buff_duration: 0,
  material_type: "",
  production_building_type: "",
  production_rate_per_hour: 0,
  rune_enhancement_type: "",
  rune_success_bonus: 0,
  rune_destruction_reduction: 0,
  cosmetic_effect: "",
  cosmetic_bind_on_pickup: false,
};

function item(partial: Partial<ItemData> & Pick<ItemData, "item_id" | "name" | "description" | "icon" | "item_type" | "rarity">): ItemData {
  return { ...defaults, ...partial } as ItemData;
}

export const ITEMS: Record<string, ItemData> = {
  // ======================= WEAPONS =======================
  weapon_sword_basic: item({
    item_id: "weapon_sword_basic", name: "Demir Kılıç",
    description: "Basit bir demir kılıç. Yeni başlayanlar için ideal.",
    icon: "/assets/sprites/items/sword_basic.png", item_type: "weapon", rarity: "common",
    equip_slot: "weapon", weapon_type: "sword", base_price: 100, vendor_sell_price: 50,
    attack: 15, defense: 5, required_level: 1, can_enhance: true, max_enhancement: 10,
  }),
  weapon_bow_elven: item({
    item_id: "weapon_bow_elven", name: "Elf Yayı",
    description: "Elf ustalarının yaptığı hafif ve güçlü yay.",
    icon: "/assets/sprites/items/bow.png", item_type: "weapon", rarity: "rare",
    equip_slot: "weapon", weapon_type: "bow", base_price: 2500, vendor_sell_price: 1250,
    attack: 35, power: 10, required_level: 15, can_enhance: true, max_enhancement: 10,
  }),
  weapon_custom_longsword: item({
    item_id: "weapon_custom_longsword", name: "Eşsiz Uzun Kılıç",
    description: "Kullanıcının eklediği kılıç.",
    icon: "/assets/sprites/items/sword_custom.png", item_type: "weapon", rarity: "epic",
    equip_slot: "weapon", weapon_type: "sword", base_price: 1200, vendor_sell_price: 600,
    attack: 60, required_level: 10, can_enhance: true, max_enhancement: 15,
  }),
  weapon_iron_sword: item({
    item_id: "weapon_iron_sword", name: "Demir Kılıç",
    description: "Temel demir kılıç. İyi bir başlangıç silahı.",
    icon: "/assets/sprites/items/iron_sword.png", item_type: "weapon", rarity: "common",
    equip_slot: "weapon", weapon_type: "sword", base_price: 100, vendor_sell_price: 50,
    attack: 12, can_enhance: true, max_enhancement: 10,
  }),
  weapon_steel_sword: item({
    item_id: "weapon_steel_sword", name: "Çelik Kılıç",
    description: "Çelikten yapılmış güçlü kılıç.",
    icon: "/assets/sprites/items/steel_sword.png", item_type: "weapon", rarity: "rare",
    equip_slot: "weapon", weapon_type: "sword", base_price: 400, vendor_sell_price: 200,
    attack: 25, can_enhance: true, max_enhancement: 10,
  }),
  weapon_legendary_sword: item({
    item_id: "weapon_legendary_sword", name: "Efsanevi Kılıç",
    description: "Efsanevi bir kılıç. Muazzam güce sahip.",
    icon: "/assets/sprites/items/legendary_sword.png", item_type: "weapon", rarity: "legendary",
    equip_slot: "weapon", weapon_type: "sword", base_price: 5000, vendor_sell_price: 2500,
    attack: 80, power: 20, can_enhance: true, max_enhancement: 10,
  }),

  // ======================= ARMOR =======================
  armor_chest_leather: item({
    item_id: "armor_chest_leather", name: "Deri Göğüslük",
    description: "Esnek deri zırh. Hareket özgürlüğü sağlar.",
    icon: "/assets/sprites/items/chest_leather.png", item_type: "armor", rarity: "common",
    armor_type: "leather", equip_slot: "chest", base_price: 80, vendor_sell_price: 40,
    defense: 12, health: 20, required_level: 1, can_enhance: true, max_enhancement: 10,
  }),
  armor_chest_plate: item({
    item_id: "armor_chest_plate", name: "Plaka Göğüslük",
    description: "Ağır plaka zırh. Maksimum koruma sağlar.",
    icon: "/assets/sprites/items/chest_plate.png", item_type: "armor", rarity: "uncommon",
    armor_type: "plate", equip_slot: "chest", base_price: 500, vendor_sell_price: 250,
    defense: 25, health: 40, required_level: 8, can_enhance: true, max_enhancement: 10,
  }),
  armor_custom_plate: item({
    item_id: "armor_custom_plate", name: "Eşsiz Zırh",
    description: "Kullanıcının eklediği plaka zırh.",
    icon: "/assets/sprites/items/armor_custom.png", item_type: "armor", rarity: "epic",
    armor_type: "plate", equip_slot: "chest", base_price: 1500, vendor_sell_price: 750,
    defense: 80, health: 120, required_level: 12, can_enhance: true, max_enhancement: 15,
  }),

  // ======================= POTIONS =======================
  potion_energy_minor: item({
    item_id: "potion_energy_minor", name: "Minör Enerji İksiri",
    description: "+20 enerji geri yükler. Hafif bağımlılık yapar.",
    icon: "/assets/sprites/items/potion_energy.png", item_type: "potion", rarity: "common",
    potion_type: "energy", base_price: 25, vendor_sell_price: 10,
    energy_restore: 20, tolerance_increase: 1, overdose_risk: 0.01,
    is_stackable: true, max_stack: 50,
  }),
  potion_antidote: item({
    item_id: "potion_antidote", name: "Antidot",
    description: "Bağımlılığı azaltır ve toleransı sıfırlar.",
    icon: "/assets/sprites/items/potion_antidote.png", item_type: "potion", rarity: "uncommon",
    potion_type: "health", base_price: 100, vendor_sell_price: 50,
    tolerance_increase: -5, is_stackable: true, max_stack: 50,
  }),

  // ======================= MATERIALS =======================
  material_iron_ore: item({
    item_id: "material_iron_ore", name: "Demir Cevheri",
    description: "Demir üretimi için kullanılır.",
    icon: "/assets/sprites/items/ore_iron.png", item_type: "material", rarity: "common",
    material_type: "ore", production_building_type: "mine",
    base_price: 5, vendor_sell_price: 2, is_stackable: true, max_stack: 500,
  }),
  material_copper_ore: item({
    item_id: "material_copper_ore", name: "Bakır Cevheri",
    description: "Bakır ve tunç eşyalar üretmek için kullanılır.",
    icon: "/assets/sprites/items/ore_copper.png", item_type: "material", rarity: "common",
    material_type: "ore", production_building_type: "mine",
    base_price: 8, vendor_sell_price: 3, is_stackable: true, max_stack: 500,
  }),
  material_gold_ore: item({
    item_id: "material_gold_ore", name: "Altın Cevheri",
    description: "Altın ve değerli eşyalar üretmek için kullanılır.",
    icon: "/assets/sprites/items/ore_gold.png", item_type: "material", rarity: "uncommon",
    material_type: "ore", production_building_type: "mine",
    base_price: 20, vendor_sell_price: 10, is_stackable: true, max_stack: 500,
  }),
  material_silver_ore: item({
    item_id: "material_silver_ore", name: "Gümüş Cevheri",
    description: "Gümüş ve aksesuarlar üretmek için kullanılır.",
    icon: "/assets/sprites/items/ore_silver.png", item_type: "material", rarity: "uncommon",
    material_type: "ore", production_building_type: "mine",
    base_price: 15, vendor_sell_price: 7, is_stackable: true, max_stack: 500,
  }),
  material_crystal: item({
    item_id: "material_crystal", name: "Kristal",
    description: "Büyü ve rün yapımında kullanılan değerli taş.",
    icon: "/assets/sprites/items/crystal.png", item_type: "material", rarity: "rare",
    material_type: "crystal", production_building_type: "mine",
    base_price: 50, vendor_sell_price: 25, is_stackable: true, max_stack: 500,
  }),
  material_diamond: item({
    item_id: "material_diamond", name: "Elmas",
    description: "En değerli efsanevi eşyalar yapılırken gerekli olan taş.",
    icon: "/assets/sprites/items/diamond.png", item_type: "material", rarity: "legendary",
    material_type: "gem", production_building_type: "mine",
    base_price: 500, vendor_sell_price: 250, is_stackable: true, max_stack: 500,
  }),
  material_wood: item({
    item_id: "material_wood", name: "Kereste",
    description: "İnşaat ve üretim için kullanılır.",
    icon: "/assets/sprites/items/wood.png", item_type: "material", rarity: "common",
    material_type: "wood", production_building_type: "sawmill",
    base_price: 3, vendor_sell_price: 1, is_stackable: true, max_stack: 500,
  }),
  material_hardwood: item({
    item_id: "material_hardwood", name: "Sert Kereste",
    description: "Dayanıklı kaliteli kereste.",
    icon: "/assets/sprites/items/hardwood.png", item_type: "material", rarity: "uncommon",
    material_type: "wood", production_building_type: "sawmill",
    base_price: 10, vendor_sell_price: 5, is_stackable: true, max_stack: 500,
  }),
  material_bamboo: item({
    item_id: "material_bamboo", name: "Bambu",
    description: "Hafif ve esnek. Yaylar ve çubuklardan yapılır.",
    icon: "/assets/sprites/items/bamboo.png", item_type: "material", rarity: "common",
    material_type: "wood", production_building_type: "sawmill",
    base_price: 5, vendor_sell_price: 2, is_stackable: true, max_stack: 500,
  }),
  material_leather: item({
    item_id: "material_leather", name: "Deri",
    description: "Hayvan derisi. Zırh ve aksesuarlar yapımında kullanılır.",
    icon: "/assets/sprites/items/leather.png", item_type: "material", rarity: "common",
    material_type: "leather", production_building_type: "farm",
    base_price: 8, vendor_sell_price: 4, is_stackable: true, max_stack: 500,
  }),
  material_quality_leather: item({
    item_id: "material_quality_leather", name: "Kaliteli Deri",
    description: "İşlenmiş yüksek kaliteli deri.",
    icon: "/assets/sprites/items/quality_leather.png", item_type: "material", rarity: "rare",
    material_type: "leather", production_building_type: "farm",
    base_price: 40, vendor_sell_price: 20, is_stackable: true, max_stack: 500,
  }),
  material_wool: item({
    item_id: "material_wool", name: "Yün",
    description: "Kumaş eşyalar yapımında kullanılır.",
    icon: "/assets/sprites/items/wool.png", item_type: "material", rarity: "common",
    material_type: "leather", production_building_type: "farm",
    base_price: 6, vendor_sell_price: 3, is_stackable: true, max_stack: 500,
  }),
  material_herb: item({
    item_id: "material_herb", name: "Tıbbi Ot",
    description: "İksir yapımında temel malzeme.",
    icon: "/assets/sprites/items/herb.png", item_type: "material", rarity: "common",
    material_type: "herb", production_building_type: "herb_garden",
    base_price: 5, vendor_sell_price: 2, is_stackable: true, max_stack: 500,
  }),
  material_rare_herb: item({
    item_id: "material_rare_herb", name: "Nadir Ot",
    description: "Nadir ve kuvvetli bitki. Güçlü potion yapımında gereklidir.",
    icon: "/assets/sprites/items/rare_herb.png", item_type: "material", rarity: "epic",
    material_type: "herb", production_building_type: "herb_garden",
    base_price: 100, vendor_sell_price: 50, is_stackable: true, max_stack: 500,
  }),
  material_dragon_blood: item({
    item_id: "material_dragon_blood", name: "Ejderha Kanı",
    description: "Efsanevi gücü olan sıvı.",
    icon: "/assets/sprites/items/dragon_blood.png", item_type: "material", rarity: "legendary",
    material_type: "herb", production_building_type: "herb_garden",
    base_price: 300, vendor_sell_price: 150, is_stackable: true, max_stack: 500,
  }),

  // ======================= SCROLLS =======================
  scroll_upgrade_low: item({
    item_id: "scroll_upgrade_low", name: "Düşük Sınıf Yükseltme Kağıdı",
    description: "Common ve Uncommon eşyaları yükseltmek için kullanılır.",
    icon: "/assets/sprites/items/lowclassscroll.png", item_type: "scroll", rarity: "uncommon",
    base_price: 500, vendor_sell_price: 250, is_stackable: true, max_stack: 50,
  }),
  scroll_upgrade_middle: item({
    item_id: "scroll_upgrade_middle", name: "Orta Sınıf Yükseltme Kağıdı",
    description: "Rare ve Epic eşyaları yükseltmek için kullanılır.",
    icon: "/assets/sprites/items/middleclassscroll.png", item_type: "scroll", rarity: "rare",
    base_price: 2500, vendor_sell_price: 1250, is_stackable: true, max_stack: 50,
  }),
  scroll_upgrade_high: item({
    item_id: "scroll_upgrade_high", name: "Yüksek Sınıf Yükseltme Kağıdı",
    description: "Legendary ve Mythic eşyaları yükseltmek için kullanılır.",
    icon: "/assets/sprites/items/highclassscroll.png", item_type: "scroll", rarity: "epic",
    base_price: 10000, vendor_sell_price: 5000, is_stackable: true, max_stack: 30,
  }),

  // ======================= RUNES =======================
  rune_minor_protection: item({
    item_id: "rune_minor_protection", name: "Küçük Koruma Rünü",
    description: "Yükseltme başarısızlığında yıkımı önler.",
    icon: "/assets/sprites/items/rune_minor.png", item_type: "rune", rarity: "rare",
    base_price: 1000, vendor_sell_price: 500,
    rune_enhancement_type: "protection", rune_success_bonus: 0, rune_destruction_reduction: 0.5,
    is_stackable: true, max_stack: 20,
  }),
  rune_major_success: item({
    item_id: "rune_major_success", name: "Büyük Başarı Rünü",
    description: "Yükseltme başarı oranını artırır.",
    icon: "/assets/sprites/items/rune_major.png", item_type: "rune", rarity: "epic",
    base_price: 5000, vendor_sell_price: 2500,
    rune_enhancement_type: "success", rune_success_bonus: 0.15, rune_destruction_reduction: 0,
    is_stackable: true, max_stack: 10,
  }),
  rune_legendary_blessed: item({
    item_id: "rune_legendary_blessed", name: "Efsanevi Kutsanmış Rün",
    description: "Hem başarı oranını artırır hem de yıkımı önler.",
    icon: "/assets/sprites/items/rune_legendary.png", item_type: "rune", rarity: "legendary",
    base_price: 20000, vendor_sell_price: 10000,
    rune_enhancement_type: "blessed", rune_success_bonus: 0.1, rune_destruction_reduction: 1.0,
    is_stackable: true, max_stack: 5,
  }),

  // ======================= RECIPES =======================
  recipe_sword_basic: item({
    item_id: "recipe_sword_basic", name: "Demir Kılıç Tarifi",
    description: "Demir kılıç üretme tarifi.",
    icon: "/assets/sprites/items/recipe_sword.png", item_type: "recipe", rarity: "common",
    base_price: 50, vendor_sell_price: 25, is_stackable: false,
  }),
};

// ============================================================
// Helper functions — ItemDatabase.gd utility karşılıkları
// ============================================================

export function getItem(itemId: string): ItemData | undefined {
  return ITEMS[itemId];
}

export function getAllItems(): ItemData[] {
  return Object.values(ITEMS);
}

export function getItemsByType(type: string): ItemData[] {
  return getAllItems().filter((i) => i.item_type === type);
}

export function getWeapons(): ItemData[] {
  return getItemsByType("weapon");
}

export function getArmor(): ItemData[] {
  return getItemsByType("armor");
}

export function getPotions(): ItemData[] {
  return getItemsByType("potion");
}

export function getMaterials(): ItemData[] {
  return getItemsByType("material");
}

export function getScrolls(): ItemData[] {
  return getItemsByType("scroll");
}

export function getRunes(): ItemData[] {
  return getItemsByType("rune");
}

export function getRecipes(): ItemData[] {
  return getItemsByType("recipe");
}

export function itemExists(itemId: string): boolean {
  return itemId in ITEMS;
}

export function getItemValue(itemId: string): number {
  return ITEMS[itemId]?.vendor_sell_price ?? 0;
}
