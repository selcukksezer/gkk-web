class DungeonData {
  const DungeonData({
    required this.id,
    required this.dungeonId,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.requiredLevel,
    required this.maxPlayers,
    required this.energyCost,
    required this.minGold,
    required this.maxGold,
    required this.lootTable,
    this.powerRequirement,
  });

  final String id;
  final String dungeonId;
  final String name;
  final String description;
  final String difficulty;
  final int requiredLevel;
  final int maxPlayers;
  final int energyCost;
  final int minGold;
  final int maxGold;
  final List<String> lootTable;
  final int? powerRequirement;

  factory DungeonData.fromJson(Map<String, dynamic> json) {
    final dynamic lootRaw = json['loot_table'];
    final List<String> loot = lootRaw is List
        ? lootRaw.map((e) => e.toString()).toList()
        : <String>[];

    return DungeonData(
      id: (json['id'] ?? json['dungeon_id'] ?? '').toString(),
      dungeonId: (json['dungeon_id'] ?? '').toString(),
      name: (json['name'] ?? 'Dungeon').toString(),
      description: (json['description'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? 'medium').toString(),
      requiredLevel: _asInt(json['required_level'], fallback: 1),
      maxPlayers: _asInt(json['max_players'], fallback: 1),
      energyCost: _asInt(json['energy_cost']),
      minGold: _asInt(json['min_gold']),
      maxGold: _asInt(json['max_gold']),
      lootTable: loot,
      powerRequirement: json['power_requirement'] == null
          ? null
          : _asInt(json['power_requirement']),
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class DungeonResult {
  const DungeonResult({
    required this.success,
    this.error,
    this.isCritical = false,
    this.goldEarned = 0,
    this.xpEarned = 0,
    this.items = const <String>[],
    this.hospitalized = false,
    this.hospitalUntil,
    this.hospitalDurationSeconds,
  });

  final bool success;
  final String? error;
  final bool isCritical;
  final int goldEarned;
  final int xpEarned;
  final List<String> items;
  final bool hospitalized;
  final String? hospitalUntil;
  final int? hospitalDurationSeconds;

  factory DungeonResult.fromJson(Map<String, dynamic> json) {
    final dynamic itemsRaw = json['items'];
    final List<String> itemList = itemsRaw is List
        ? itemsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return DungeonResult(
      success: (json['success'] as bool?) ?? false,
      error: json['error'] as String?,
      isCritical: (json['is_critical'] as bool?) ?? false,
      goldEarned: _asInt(json['gold_earned']),
      xpEarned: _asInt(json['xp_earned']),
      items: itemList,
      hospitalized: (json['hospitalized'] as bool?) ?? false,
      hospitalUntil: json['hospital_until'] as String?,
      hospitalDurationSeconds: json['hospital_duration'] == null
          ? null
          : _asInt(json['hospital_duration']),
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
