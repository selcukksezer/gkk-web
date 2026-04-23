class CraftIngredient {
  const CraftIngredient({
    required this.itemId,
    required this.itemName,
    required this.quantity,
  });

  final String itemId;
  final String itemName;
  final int quantity;

  factory CraftIngredient.fromJson(Map<String, dynamic> json) {
    final String rawName = (json['item_name'] ?? json['name'] ?? json['itemName'] ?? '')
        .toString()
        .trim();
    return CraftIngredient(
      itemId: (json['item_id'] ?? '').toString(),
      itemName: rawName,
      quantity: _asInt(json['quantity']),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_name': itemName,
        'quantity': quantity,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class CraftRecipe {
  const CraftRecipe({
    required this.id,
    this.recipeId,
    required this.name,
    this.outputName,
    required this.description,
    required this.recipeType,
    required this.itemType,
    required this.outputItemId,
    required this.outputQuantity,
    required this.outputRarity,
    required this.requiredLevel,
    this.requiredFacility,
    required this.requiredFacilityLevel,
    this.productionTimeSeconds,
    required this.successRate,
    required this.ingredients,
    required this.gemCost,
    required this.goldCost,
    this.xpReward,
  });

  final String id;
  final String? recipeId;
  final String name;
  final String? outputName;
  final String description;
  final String recipeType;
  final String itemType;
  final String outputItemId;
  final int outputQuantity;
  final String outputRarity;
  final int requiredLevel;
  final String? requiredFacility;
  final int requiredFacilityLevel;
  final int? productionTimeSeconds;
  final double successRate;
  final List<CraftIngredient> ingredients;
  final int gemCost;
  final int goldCost;
  final int? xpReward;

  factory CraftRecipe.fromJson(Map<String, dynamic> json) {
    final dynamic ingredientsRaw = json['ingredients'];
    final List<CraftIngredient> ingredients = ingredientsRaw is List
        ? ingredientsRaw
            .whereType<Map<String, dynamic>>()
            .map(CraftIngredient.fromJson)
            .toList()
        : <CraftIngredient>[];

    return CraftRecipe(
      id: (json['id'] ?? '').toString(),
      recipeId: json['recipe_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      outputName: json['output_name']?.toString(),
      description: (json['description'] ?? '').toString(),
      recipeType: (json['recipe_type'] ?? '').toString(),
      itemType: (json['item_type'] ?? '').toString(),
      outputItemId: (json['output_item_id'] ?? '').toString(),
      outputQuantity: _asInt(json['output_quantity'], fallback: 1),
      outputRarity: (json['output_rarity'] ?? 'common').toString(),
      requiredLevel: _asInt(json['required_level'], fallback: 1),
      requiredFacility: json['required_facility']?.toString(),
      requiredFacilityLevel: _asInt(json['required_facility_level']),
      productionTimeSeconds: json['production_time_seconds'] == null
          ? null
          : _asInt(json['production_time_seconds']),
      successRate: _asDouble(json['success_rate'], fallback: 1.0),
      ingredients: ingredients,
      gemCost: _asInt(json['gem_cost']),
      goldCost: _asInt(json['gold_cost']),
      xpReward: json['xp_reward'] == null ? null : _asInt(json['xp_reward']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_id': recipeId,
        'name': name,
        'output_name': outputName,
        'description': description,
        'recipe_type': recipeType,
        'item_type': itemType,
        'output_item_id': outputItemId,
        'output_quantity': outputQuantity,
        'output_rarity': outputRarity,
        'required_level': requiredLevel,
        'required_facility': requiredFacility,
        'required_facility_level': requiredFacilityLevel,
        'production_time_seconds': productionTimeSeconds,
        'success_rate': successRate,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'gem_cost': gemCost,
        'gold_cost': goldCost,
        'xp_reward': xpReward,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}

class CraftQueueItem {
  const CraftQueueItem({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    this.recipeIcon,
    required this.batchCount,
    required this.startedAt,
    required this.completesAt,
    required this.isCompleted,
    required this.claimed,
    this.failed,
    this.xpReward,
    this.outputItemId,
    this.outputQuantity,
    this.outputName,
  });

  final String id;
  final String recipeId;
  final String recipeName;
  final String? recipeIcon;
  final int batchCount;
  final String startedAt;
  final String completesAt;
  final bool isCompleted;
  final bool claimed;
  final bool? failed;
  final int? xpReward;
  final String? outputItemId;
  final int? outputQuantity;
  final String? outputName;

  factory CraftQueueItem.fromJson(Map<String, dynamic> json) {
    return CraftQueueItem(
      id: (json['id'] ?? '').toString(),
      recipeId: (json['recipe_id'] ?? '').toString(),
      recipeName: (json['recipe_name'] ?? '').toString(),
      recipeIcon: json['recipe_icon']?.toString(),
      batchCount: _asInt(json['batch_count'], fallback: 1),
      startedAt: (json['started_at'] ?? '').toString(),
      completesAt: (json['completes_at'] ?? '').toString(),
      isCompleted: json['is_completed'] == true,
      claimed: json['claimed'] == true,
      failed: json['failed'] == null ? null : json['failed'] == true,
      xpReward: json['xp_reward'] == null ? null : _asInt(json['xp_reward']),
      outputItemId: json['output_item_id']?.toString(),
      outputQuantity: json['output_quantity'] == null
          ? null
          : _asInt(json['output_quantity']),
      outputName: json['output_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_id': recipeId,
        'recipe_name': recipeName,
        'recipe_icon': recipeIcon,
        'batch_count': batchCount,
        'started_at': startedAt,
        'completes_at': completesAt,
        'is_completed': isCompleted,
        'claimed': claimed,
        'failed': failed,
        'xp_reward': xpReward,
        'output_item_id': outputItemId,
        'output_quantity': outputQuantity,
        'output_name': outputName,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
