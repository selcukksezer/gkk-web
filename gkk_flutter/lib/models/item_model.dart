import 'package:flutter/material.dart';

enum ItemType {
  weapon,
  armor,
  potion,
  consumable,
  material,
  recipe,
  scroll,
  rune,
  cosmetic,
}

enum Rarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  mythic,
}

enum EquipSlot {
  weapon,
  chest,
  head,
  legs,
  boots,
  gloves,
  ring,
  necklace,
  none,
}

enum WeaponType {
  sword,
  axe,
  staff,
  bow,
  dagger,
  mace,
  none,
}

enum ArmorType {
  plate,
  chain,
  leather,
  robe,
  cloth,
  shield,
  none,
}

enum SubType {
  dagger,
  sword,
  axe,
  staff,
  plate,
  chain,
  leather,
  robe,
  helm,
  hood,
  crown,
  circlet,
  greaves,
  leggings,
  tassets,
  pteruges,
  sabaton,
  treads,
  sandals,
  moccasins,
  gauntlet,
  bracers,
  wraps,
  mitts,
  signet,
  band,
  loop,
  seal,
  pendant,
  amulet,
  choker,
  talisman,
  detox,
  none,
}

enum PotionType {
  health,
  mana,
  energy,
  buff,
  none,
}

class ItemData {
  const ItemData({
    required this.itemId,
    required this.name,
    required this.description,
    required this.icon,
    required this.itemType,
    required this.rarity,
    this.facilityType,
    required this.basePrice,
    required this.vendorSellPrice,
    required this.attack,
    required this.defense,
    required this.health,
    required this.power,
    required this.luck,
    required this.mana,
    required this.equipSlot,
    required this.weaponType,
    required this.armorType,
    required this.subType,
    required this.requiredLevel,
    required this.canEnhance,
    required this.maxEnhancement,
    required this.enhancementLevel,
    required this.isStackable,
    required this.maxStack,
    required this.quantity,
    required this.isTradeable,
    required this.isHanOnly,
    required this.isMarketTradeable,
    required this.isDirectTradeable,
    required this.potionType,
    required this.energyRestore,
    required this.healthRestore,
    required this.manaRestore,
    required this.toleranceIncrease,
    required this.overdoseRisk,
    required this.buffDuration,
    required this.materialType,
    required this.productionBuildingType,
    required this.productionRatePerHour,
    required this.runeEnhancementType,
    required this.runeSuccessBonus,
    required this.runeDestructionReduction,
    required this.cosmeticEffect,
    required this.cosmeticBindOnPickup,
  });

  final String itemId;
  final String name;
  final String description;
  final String icon;
  final ItemType itemType;
  final Rarity rarity;
  final String? facilityType;
  final int basePrice;
  final int vendorSellPrice;
  final int attack;
  final int defense;
  final int health;
  final int power;
  final int luck;
  final int mana;
  final EquipSlot equipSlot;
  final WeaponType weaponType;
  final ArmorType armorType;
  final SubType subType;
  final int requiredLevel;
  final bool canEnhance;
  final int maxEnhancement;
  final int enhancementLevel;
  final bool isStackable;
  final int maxStack;
  final int quantity;
  final bool isTradeable;
  final bool isHanOnly;
  final bool isMarketTradeable;
  final bool isDirectTradeable;
  final PotionType potionType;
  final int energyRestore;
  final int healthRestore;
  final int manaRestore;
  final int toleranceIncrease;
  final double overdoseRisk;
  final int buffDuration;
  final String materialType;
  final String productionBuildingType;
  final int productionRatePerHour;
  final String runeEnhancementType;
  final double runeSuccessBonus;
  final double runeDestructionReduction;
  final String cosmeticEffect;
  final bool cosmeticBindOnPickup;

  ItemData copyWith({
    String? itemId,
    String? name,
    String? description,
    String? icon,
    ItemType? itemType,
    Rarity? rarity,
    String? facilityType,
    int? basePrice,
    int? vendorSellPrice,
    int? attack,
    int? defense,
    int? health,
    int? power,
    int? luck,
    int? mana,
    EquipSlot? equipSlot,
    WeaponType? weaponType,
    ArmorType? armorType,
    SubType? subType,
    int? requiredLevel,
    bool? canEnhance,
    int? maxEnhancement,
    int? enhancementLevel,
    bool? isStackable,
    int? maxStack,
    int? quantity,
    bool? isTradeable,
    bool? isHanOnly,
    bool? isMarketTradeable,
    bool? isDirectTradeable,
    PotionType? potionType,
    int? energyRestore,
    int? healthRestore,
    int? manaRestore,
    int? toleranceIncrease,
    double? overdoseRisk,
    int? buffDuration,
    String? materialType,
    String? productionBuildingType,
    int? productionRatePerHour,
    String? runeEnhancementType,
    double? runeSuccessBonus,
    double? runeDestructionReduction,
    String? cosmeticEffect,
    bool? cosmeticBindOnPickup,
  }) {
    return ItemData(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      itemType: itemType ?? this.itemType,
      rarity: rarity ?? this.rarity,
      facilityType: facilityType ?? this.facilityType,
      basePrice: basePrice ?? this.basePrice,
      vendorSellPrice: vendorSellPrice ?? this.vendorSellPrice,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      health: health ?? this.health,
      power: power ?? this.power,
      luck: luck ?? this.luck,
      mana: mana ?? this.mana,
      equipSlot: equipSlot ?? this.equipSlot,
      weaponType: weaponType ?? this.weaponType,
      armorType: armorType ?? this.armorType,
      subType: subType ?? this.subType,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      canEnhance: canEnhance ?? this.canEnhance,
      maxEnhancement: maxEnhancement ?? this.maxEnhancement,
      enhancementLevel: enhancementLevel ?? this.enhancementLevel,
      isStackable: isStackable ?? this.isStackable,
      maxStack: maxStack ?? this.maxStack,
      quantity: quantity ?? this.quantity,
      isTradeable: isTradeable ?? this.isTradeable,
      isHanOnly: isHanOnly ?? this.isHanOnly,
      isMarketTradeable: isMarketTradeable ?? this.isMarketTradeable,
      isDirectTradeable: isDirectTradeable ?? this.isDirectTradeable,
      potionType: potionType ?? this.potionType,
      energyRestore: energyRestore ?? this.energyRestore,
      healthRestore: healthRestore ?? this.healthRestore,
      manaRestore: manaRestore ?? this.manaRestore,
      toleranceIncrease: toleranceIncrease ?? this.toleranceIncrease,
      overdoseRisk: overdoseRisk ?? this.overdoseRisk,
      buffDuration: buffDuration ?? this.buffDuration,
      materialType: materialType ?? this.materialType,
      productionBuildingType: productionBuildingType ?? this.productionBuildingType,
      productionRatePerHour: productionRatePerHour ?? this.productionRatePerHour,
      runeEnhancementType: runeEnhancementType ?? this.runeEnhancementType,
      runeSuccessBonus: runeSuccessBonus ?? this.runeSuccessBonus,
      runeDestructionReduction: runeDestructionReduction ?? this.runeDestructionReduction,
      cosmeticEffect: cosmeticEffect ?? this.cosmeticEffect,
      cosmeticBindOnPickup: cosmeticBindOnPickup ?? this.cosmeticBindOnPickup,
    );
  }

  factory ItemData.fromJson(Map<String, dynamic> json) {
    return ItemData(
      itemId: json['item_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      itemType: ItemTypeParsing.fromValue(json['item_type'] as String),
      rarity: RarityParsing.fromValue(json['rarity'] as String),
      facilityType: json['facility_type'] as String?,
      basePrice: (json['base_price'] as num).toInt(),
      vendorSellPrice: (json['vendor_sell_price'] as num).toInt(),
      attack: (json['attack'] as num).toInt(),
      defense: (json['defense'] as num).toInt(),
      health: (json['health'] as num).toInt(),
      power: (json['power'] as num).toInt(),
      luck: (json['luck'] as num).toInt(),
      mana: (json['mana'] as num).toInt(),
      equipSlot: EquipSlotParsing.fromValue(json['equip_slot'] as String),
      weaponType: WeaponTypeParsing.fromValue(json['weapon_type'] as String),
      armorType: ArmorTypeParsing.fromValue(json['armor_type'] as String),
      subType: SubTypeParsing.fromValue(json['sub_type'] as String),
      requiredLevel: (json['required_level'] as num).toInt(),
      canEnhance: json['can_enhance'] as bool,
      maxEnhancement: (json['max_enhancement'] as num).toInt(),
      enhancementLevel: (json['enhancement_level'] as num).toInt(),
      isStackable: json['is_stackable'] as bool,
      maxStack: (json['max_stack'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      isTradeable: json['is_tradeable'] as bool,
      isHanOnly: json['is_han_only'] as bool,
      isMarketTradeable: json['is_market_tradeable'] as bool,
      isDirectTradeable: json['is_direct_tradeable'] as bool,
      potionType: PotionTypeParsing.fromValue(json['potion_type'] as String),
      energyRestore: (json['energy_restore'] as num).toInt(),
      healthRestore: (json['health_restore'] as num).toInt(),
      manaRestore: (json['mana_restore'] as num).toInt(),
      toleranceIncrease: (json['tolerance_increase'] as num).toInt(),
      overdoseRisk: (json['overdose_risk'] as num).toDouble(),
      buffDuration: (json['buff_duration'] as num).toInt(),
      materialType: json['material_type'] as String,
      productionBuildingType: json['production_building_type'] as String,
      productionRatePerHour: (json['production_rate_per_hour'] as num).toInt(),
      runeEnhancementType: json['rune_enhancement_type'] as String,
      runeSuccessBonus: (json['rune_success_bonus'] as num).toDouble(),
      runeDestructionReduction: (json['rune_destruction_reduction'] as num).toDouble(),
      cosmeticEffect: json['cosmetic_effect'] as String,
      cosmeticBindOnPickup: json['cosmetic_bind_on_pickup'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'item_id': itemId,
      'name': name,
      'description': description,
      'icon': icon,
      'item_type': itemType.name,
      'rarity': rarity.name,
      'facility_type': facilityType,
      'base_price': basePrice,
      'vendor_sell_price': vendorSellPrice,
      'attack': attack,
      'defense': defense,
      'health': health,
      'power': power,
      'luck': luck,
      'mana': mana,
      'equip_slot': equipSlot.name,
      'weapon_type': weaponType.name,
      'armor_type': armorType.name,
      'sub_type': subType.name,
      'required_level': requiredLevel,
      'can_enhance': canEnhance,
      'max_enhancement': maxEnhancement,
      'enhancement_level': enhancementLevel,
      'is_stackable': isStackable,
      'max_stack': maxStack,
      'quantity': quantity,
      'is_tradeable': isTradeable,
      'is_han_only': isHanOnly,
      'is_market_tradeable': isMarketTradeable,
      'is_direct_tradeable': isDirectTradeable,
      'potion_type': potionType.name,
      'energy_restore': energyRestore,
      'health_restore': healthRestore,
      'mana_restore': manaRestore,
      'tolerance_increase': toleranceIncrease,
      'overdose_risk': overdoseRisk,
      'buff_duration': buffDuration,
      'material_type': materialType,
      'production_building_type': productionBuildingType,
      'production_rate_per_hour': productionRatePerHour,
      'rune_enhancement_type': runeEnhancementType,
      'rune_success_bonus': runeSuccessBonus,
      'rune_destruction_reduction': runeDestructionReduction,
      'cosmetic_effect': cosmeticEffect,
      'cosmetic_bind_on_pickup': cosmeticBindOnPickup,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemData &&
        other.itemId == itemId &&
        other.name == name &&
        other.description == description &&
        other.icon == icon &&
        other.itemType == itemType &&
        other.rarity == rarity &&
        other.facilityType == facilityType &&
        other.basePrice == basePrice &&
        other.vendorSellPrice == vendorSellPrice &&
        other.attack == attack &&
        other.defense == defense &&
        other.health == health &&
        other.power == power &&
        other.luck == luck &&
        other.mana == mana &&
        other.equipSlot == equipSlot &&
        other.weaponType == weaponType &&
        other.armorType == armorType &&
        other.subType == subType &&
        other.requiredLevel == requiredLevel &&
        other.canEnhance == canEnhance &&
        other.maxEnhancement == maxEnhancement &&
        other.enhancementLevel == enhancementLevel &&
        other.isStackable == isStackable &&
        other.maxStack == maxStack &&
        other.quantity == quantity &&
        other.isTradeable == isTradeable &&
        other.isHanOnly == isHanOnly &&
        other.isMarketTradeable == isMarketTradeable &&
        other.isDirectTradeable == isDirectTradeable &&
        other.potionType == potionType &&
        other.energyRestore == energyRestore &&
        other.healthRestore == healthRestore &&
        other.manaRestore == manaRestore &&
        other.toleranceIncrease == toleranceIncrease &&
        other.overdoseRisk == overdoseRisk &&
        other.buffDuration == buffDuration &&
        other.materialType == materialType &&
        other.productionBuildingType == productionBuildingType &&
        other.productionRatePerHour == productionRatePerHour &&
        other.runeEnhancementType == runeEnhancementType &&
        other.runeSuccessBonus == runeSuccessBonus &&
        other.runeDestructionReduction == runeDestructionReduction &&
        other.cosmeticEffect == cosmeticEffect &&
        other.cosmeticBindOnPickup == cosmeticBindOnPickup;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        itemId,
        name,
        description,
        icon,
        itemType,
        rarity,
        facilityType,
        basePrice,
        vendorSellPrice,
        attack,
        defense,
        health,
        power,
        luck,
        mana,
        equipSlot,
        weaponType,
        armorType,
        subType,
        requiredLevel,
        canEnhance,
        maxEnhancement,
        enhancementLevel,
        isStackable,
        maxStack,
        quantity,
        isTradeable,
        isHanOnly,
        isMarketTradeable,
        isDirectTradeable,
        potionType,
        energyRestore,
        healthRestore,
        manaRestore,
        toleranceIncrease,
        overdoseRisk,
        buffDuration,
        materialType,
        productionBuildingType,
        productionRatePerHour,
        runeEnhancementType,
        runeSuccessBonus,
        runeDestructionReduction,
        cosmeticEffect,
        cosmeticBindOnPickup,
      ]);
}

bool isWeapon(ItemData item) => item.itemType == ItemType.weapon;
bool isArmor(ItemData item) => item.itemType == ItemType.armor;
bool isPotion(ItemData item) => item.itemType == ItemType.potion;
bool isConsumable(ItemData item) => item.itemType == ItemType.consumable;
bool isMaterial(ItemData item) => item.itemType == ItemType.material;
bool isRecipe(ItemData item) => item.itemType == ItemType.recipe;
bool isRune(ItemData item) => item.itemType == ItemType.rune;
bool isCosmetic(ItemData item) => item.itemType == ItemType.cosmetic;
bool isScroll(ItemData item) => item.itemType == ItemType.scroll;
bool isEquippable(ItemData item) => item.equipSlot != EquipSlot.none;

String getDisplayName(String name, int enhancementLevel) {
  if (enhancementLevel > 0) {
    return '+$enhancementLevel $name';
  }
  return name;
}

String getRarityHexColor(Rarity rarity) {
  switch (rarity) {
    case Rarity.common:
      return '#E6E6E6';
    case Rarity.uncommon:
      return '#33CC33';
    case Rarity.rare:
      return '#4D80FF';
    case Rarity.epic:
      return '#9933CC';
    case Rarity.legendary:
      return '#FF8000';
    case Rarity.mythic:
      return '#FF3333';
  }
}

Color getRarityColor(Rarity rarity) {
  final String hex = getRarityHexColor(rarity).replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

String getRarityLabel(Rarity rarity) {
  switch (rarity) {
    case Rarity.common:
      return 'Siradan';
    case Rarity.uncommon:
      return 'Yaygin Olmayan';
    case Rarity.rare:
      return 'Nadir';
    case Rarity.epic:
      return 'Destansi';
    case Rarity.legendary:
      return 'Efsanevi';
    case Rarity.mythic:
      return 'Mitik';
  }
}

extension ItemTypeParsing on ItemType {
  static ItemType fromValue(String value) {
    return ItemType.values.firstWhere((ItemType e) => e.name == value);
  }
}

extension RarityParsing on Rarity {
  static Rarity fromValue(String value) {
    return Rarity.values.firstWhere((Rarity e) => e.name == value);
  }
}

extension EquipSlotParsing on EquipSlot {
  static EquipSlot fromValue(String value) {
    return EquipSlot.values.firstWhere((EquipSlot e) => e.name == value);
  }
}

extension WeaponTypeParsing on WeaponType {
  static WeaponType fromValue(String value) {
    return WeaponType.values.firstWhere((WeaponType e) => e.name == value);
  }
}

extension ArmorTypeParsing on ArmorType {
  static ArmorType fromValue(String value) {
    return ArmorType.values.firstWhere((ArmorType e) => e.name == value);
  }
}

extension SubTypeParsing on SubType {
  static SubType fromValue(String value) {
    return SubType.values.firstWhere((SubType e) => e.name == value);
  }
}

extension PotionTypeParsing on PotionType {
  static PotionType fromValue(String value) {
    return PotionType.values.firstWhere((PotionType e) => e.name == value);
  }
}
