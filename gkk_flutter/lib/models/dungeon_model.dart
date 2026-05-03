import 'dart:convert';

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
    required this.isGroup,
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
  final bool isGroup;
  final int? powerRequirement;

  factory DungeonData.fromJson(Map<String, dynamic> json) {
    List<String> loot = _parseLootTable(
      json['loot_table'] ?? json['lootTable'] ?? json['loot'] ?? json['drops'],
    );
    final bool isGroup = _asBool(json['is_group']) ||
        _asInt(json['max_players'], fallback: 1) > 1;

    final List<String> rarityRows = _parseRarityWeights(json['loot_rarity_weights']);
    if (rarityRows.isNotEmpty) {
      loot = <String>[...rarityRows, ...loot];
    }

    if (loot.isEmpty) {
      final double equipmentChance = _asDouble(json['equipment_drop_chance']);
      final double resourceChance = _asDouble(json['resource_drop_chance']);
      final double catalystChance = _asDouble(json['catalyst_drop_chance']);
      final double scrollChance = _asDouble(json['scroll_drop_chance']);

      if (equipmentChance > 0) {
        loot.add('equipment ${(equipmentChance * 100).toStringAsFixed(0)}%');
      }
      if (resourceChance > 0) {
        loot.add('resource ${(resourceChance * 100).toStringAsFixed(0)}%');
      }
      if (catalystChance > 0) {
        loot.add('catalyst ${(catalystChance * 100).toStringAsFixed(0)}%');
      }
      if (scrollChance > 0) {
        loot.add('scroll ${(scrollChance * 100).toStringAsFixed(0)}%');
      }
    }

    final int? rawPowerReq = json['power_requirement'] == null
        ? null
        : _asInt(json['power_requirement']);

    int requiredLevel;
    if (json['required_level'] != null) {
      requiredLevel = _asInt(json['required_level'], fallback: 1);
    } else if (rawPowerReq != null && rawPowerReq > 0) {
      requiredLevel = (rawPowerReq / 500).floor();
      if (requiredLevel < 1) requiredLevel = 1;
    } else {
      requiredLevel = 1;
    }

    final int effectivePower = rawPowerReq ?? (requiredLevel * 500);

    final bool isBoss = json['is_boss'] == true;
    final String difficulty;
    if (isBoss) {
      difficulty = 'dungeon';
    } else if (effectivePower <= 0) {
      difficulty = 'easy';
    } else if (effectivePower < 15000) {
      difficulty = 'easy';
    } else if (effectivePower < 45000) {
      difficulty = 'medium';
    } else {
      difficulty = 'hard';
    }

    return DungeonData(
      id: (json['id'] ?? json['dungeon_id'] ?? '').toString(),
      dungeonId: (json['dungeon_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Dungeon').toString(),
      description: (json['description'] ?? '').toString(),
      difficulty: difficulty,
      requiredLevel: requiredLevel,
      maxPlayers: _asInt(json['max_players'], fallback: 1),
      energyCost: _asInt(json['energy_cost']),
      // Support both naming conventions coming from RPC/table payloads.
      minGold: _asInt(json['min_gold'] ?? json['gold_min']),
      maxGold: _asInt(json['max_gold'] ?? json['gold_max']),
      lootTable: loot,
      isGroup: isGroup,
      powerRequirement: rawPowerReq,
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String n = value.toLowerCase().trim();
      if (n == 'true' || n == '1' || n == 'yes') return true;
      if (n == 'false' || n == '0' || n == 'no') return false;
    }
    return fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static List<String> _parseLootTable(dynamic raw) {
    if (raw == null) return <String>[];

    if (raw is List) {
      final List<String> out = <String>[];
      for (final dynamic entry in raw) {
        if (entry == null) continue;
        if (entry is String) {
          out.add(entry);
          continue;
        }
        if (entry is Map) {
          final Map<dynamic, dynamic> map = entry;
          final dynamic named = map['item_name'] ?? map['item_id'] ?? map['name'] ?? map['type'];
          if (named != null) {
            out.add(named.toString());
          }
          continue;
        }
        out.add(entry.toString());
      }
      return out;
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return <String>[];
      if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
          (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
        try {
          final dynamic decoded = jsonDecode(trimmed);
          return _parseLootTable(decoded);
        } catch (_) {
          return <String>[trimmed];
        }
      }
      return <String>[trimmed];
    }

    if (raw is Map) {
      final List<String> out = <String>[];
      raw.forEach((key, value) {
        if (value == null) return;
        out.add('$key:$value');
      });
      return out;
    }

    return <String>[raw.toString()];
  }

  static List<String> _parseRarityWeights(dynamic raw) {
    if (raw == null) return <String>[];

    Map<String, dynamic>? map;
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return <String>[];
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return <String>[];
      }
    }

    if (map == null || map.isEmpty) return <String>[];

    const List<String> preferredOrder = <String>[
      'mythic',
      'legendary',
      'epic',
      'rare',
      'uncommon',
      'common',
    ];

    final List<String> rows = <String>[];
    for (final String key in preferredOrder) {
      if (!map.containsKey(key)) continue;
      final double pct = _asDouble(map[key]) * 100;
      if (pct <= 0) continue;
      rows.add('$key ${pct.toStringAsFixed(0)}%');
    }

    map.forEach((dynamic rawKey, dynamic value) {
      final String key = rawKey.toString().toLowerCase();
      if (preferredOrder.contains(key)) return;
      final double pct = _asDouble(value) * 100;
      if (pct <= 0) return;
      rows.add('$key ${pct.toStringAsFixed(0)}%');
    });

    return rows;
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
    final dynamic itemsRaw = json['items'] ?? json['items_dropped'];
    final List<String> itemList = <String>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map) {
          itemList.add((e['item_name'] ?? e['item_id'] ?? e.toString()).toString());
        } else {
          itemList.add(e.toString());
        }
      }
    }

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
