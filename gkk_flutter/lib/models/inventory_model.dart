import 'item_model.dart';

const int inventoryCapacity = 20;

class InventoryItem {
  const InventoryItem({
    required this.rowId,
    required this.itemId,
    required this.quantity,
    required this.slotPosition,
    required this.isEquipped,
    required this.equippedSlot,
    required this.enhancementLevel,
    required this.isFavorite,
    required this.pendingSync,
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
    this.subType,
    required this.requiredLevel,
    required this.canEnhance,
    required this.maxEnhancement,
    required this.isStackable,
    required this.maxStack,
    required this.isTradeable,
    this.isHanOnly,
    this.isMarketTradeable,
    this.isDirectTradeable,
    required this.potionType,
    required this.energyRestore,
    required this.healthRestore,
    required this.toleranceIncrease,
  });

  final String rowId;
  final String itemId;
  final int quantity;
  final int slotPosition;
  final bool isEquipped;
  final String equippedSlot;
  final int enhancementLevel;
  final bool isFavorite;
  final bool pendingSync;
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
  final SubType? subType;
  final int requiredLevel;
  final bool canEnhance;
  final int maxEnhancement;
  final bool isStackable;
  final int maxStack;
  final bool isTradeable;
  final bool? isHanOnly;
  final bool? isMarketTradeable;
  final bool? isDirectTradeable;
  final PotionType potionType;
  final int energyRestore;
  final int healthRestore;
  final int toleranceIncrease;

  InventoryItem copyWith({
    String? rowId,
    String? itemId,
    int? quantity,
    int? slotPosition,
    bool? isEquipped,
    String? equippedSlot,
    int? enhancementLevel,
    bool? isFavorite,
    bool? pendingSync,
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
    bool? isStackable,
    int? maxStack,
    bool? isTradeable,
    bool? isHanOnly,
    bool? isMarketTradeable,
    bool? isDirectTradeable,
    PotionType? potionType,
    int? energyRestore,
    int? healthRestore,
    int? toleranceIncrease,
  }) {
    return InventoryItem(
      rowId: rowId ?? this.rowId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      slotPosition: slotPosition ?? this.slotPosition,
      isEquipped: isEquipped ?? this.isEquipped,
      equippedSlot: equippedSlot ?? this.equippedSlot,
      enhancementLevel: enhancementLevel ?? this.enhancementLevel,
      isFavorite: isFavorite ?? this.isFavorite,
      pendingSync: pendingSync ?? this.pendingSync,
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
      isStackable: isStackable ?? this.isStackable,
      maxStack: maxStack ?? this.maxStack,
      isTradeable: isTradeable ?? this.isTradeable,
      isHanOnly: isHanOnly ?? this.isHanOnly,
      isMarketTradeable: isMarketTradeable ?? this.isMarketTradeable,
      isDirectTradeable: isDirectTradeable ?? this.isDirectTradeable,
      potionType: potionType ?? this.potionType,
      energyRestore: energyRestore ?? this.energyRestore,
      healthRestore: healthRestore ?? this.healthRestore,
      toleranceIncrease: toleranceIncrease ?? this.toleranceIncrease,
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      rowId: json['row_id'] as String,
      itemId: json['item_id'] as String,
      quantity: (json['quantity'] as num).toInt(),
      slotPosition: (json['slot_position'] as num).toInt(),
      isEquipped: json['is_equipped'] as bool,
      equippedSlot: json['equipped_slot'] as String,
      enhancementLevel: (json['enhancement_level'] as num).toInt(),
      isFavorite: json['is_favorite'] as bool,
      pendingSync: json['pending_sync'] as bool,
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
      subType: (json['sub_type'] == null || (json['sub_type'] as String).isEmpty)
          ? null
          : SubTypeParsing.fromValue(json['sub_type'] as String),
      requiredLevel: (json['required_level'] as num).toInt(),
      canEnhance: json['can_enhance'] as bool,
      maxEnhancement: (json['max_enhancement'] as num).toInt(),
      isStackable: json['is_stackable'] as bool,
      maxStack: (json['max_stack'] as num).toInt(),
      isTradeable: json['is_tradeable'] as bool,
      isHanOnly: json['is_han_only'] as bool?,
      isMarketTradeable: json['is_market_tradeable'] as bool?,
      isDirectTradeable: json['is_direct_tradeable'] as bool?,
      potionType: PotionTypeParsing.fromValue(json['potion_type'] as String),
      energyRestore: (json['energy_restore'] as num).toInt(),
      healthRestore: (json['health_restore'] as num).toInt(),
      toleranceIncrease: (json['tolerance_increase'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'row_id': rowId,
      'item_id': itemId,
      'quantity': quantity,
      'slot_position': slotPosition,
      'is_equipped': isEquipped,
      'equipped_slot': equippedSlot,
      'enhancement_level': enhancementLevel,
      'is_favorite': isFavorite,
      'pending_sync': pendingSync,
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
      'sub_type': subType?.name,
      'required_level': requiredLevel,
      'can_enhance': canEnhance,
      'max_enhancement': maxEnhancement,
      'is_stackable': isStackable,
      'max_stack': maxStack,
      'is_tradeable': isTradeable,
      'is_han_only': isHanOnly,
      'is_market_tradeable': isMarketTradeable,
      'is_direct_tradeable': isDirectTradeable,
      'potion_type': potionType.name,
      'energy_restore': energyRestore,
      'health_restore': healthRestore,
      'tolerance_increase': toleranceIncrease,
    };
  }
}
