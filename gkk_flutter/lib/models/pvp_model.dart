class PvPTarget {
  const PvPTarget({
    required this.id,
    required this.playerId,
    required this.username,
    required this.level,
    required this.power,
    required this.pvpRating,
    required this.rating,
    required this.attack,
    required this.defense,
    required this.health,
    required this.estimatedGold,
    this.guildName,
  });

  final String id;
  final String playerId;
  final String username;
  final int level;
  final int power;
  final int pvpRating;
  final int rating;
  final int attack;
  final int defense;
  final int health;
  final int estimatedGold;
  final String? guildName;

  factory PvPTarget.fromJson(Map<String, dynamic> json) {
    return PvPTarget(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      level: _asInt(json['level'], fallback: 1),
      power: _asInt(json['power']),
      pvpRating: _asInt(json['pvp_rating']),
      rating: _asInt(json['rating']),
      attack: _asInt(json['attack']),
      defense: _asInt(json['defense']),
      health: _asInt(json['health']),
      estimatedGold: _asInt(json['estimated_gold']),
      guildName: json['guild_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'player_id': playerId,
        'username': username,
        'level': level,
        'power': power,
        'pvp_rating': pvpRating,
        'rating': rating,
        'attack': attack,
        'defense': defense,
        'health': health,
        'estimated_gold': estimatedGold,
        'guild_name': guildName,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class PvPResult {
  const PvPResult({
    required this.success,
    required this.won,
    required this.opponentName,
    required this.attackerDamage,
    required this.defenderDamage,
    required this.goldStolen,
    required this.goldChange,
    required this.ratingChange,
    required this.isCritical,
    required this.defenderHospitalized,
  });

  final bool success;
  final bool won;
  final String opponentName;
  final int attackerDamage;
  final int defenderDamage;
  final int goldStolen;
  final int goldChange;
  final int ratingChange;
  final bool isCritical;
  final bool defenderHospitalized;

  factory PvPResult.fromJson(Map<String, dynamic> json) {
    return PvPResult(
      success: json['success'] == true,
      won: json['won'] == true,
      opponentName: (json['opponent_name'] ?? '').toString(),
      attackerDamage: _asInt(json['attacker_damage']),
      defenderDamage: _asInt(json['defender_damage']),
      goldStolen: _asInt(json['gold_stolen']),
      goldChange: _asInt(json['gold_change']),
      ratingChange: _asInt(json['rating_change']),
      isCritical: json['is_critical'] == true,
      defenderHospitalized: json['defender_hospitalized'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'won': won,
        'opponent_name': opponentName,
        'attacker_damage': attackerDamage,
        'defender_damage': defenderDamage,
        'gold_stolen': goldStolen,
        'gold_change': goldChange,
        'rating_change': ratingChange,
        'is_critical': isCritical,
        'defender_hospitalized': defenderHospitalized,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class PvPHistoryEntry {
  const PvPHistoryEntry({
    required this.id,
    required this.opponentId,
    required this.opponentName,
    required this.opponentUsername,
    required this.isAttacker,
    required this.won,
    required this.result,
    required this.goldChange,
    required this.ratingChange,
    required this.timestamp,
    required this.createdAt,
    required this.battleLog,
  });

  final String id;
  final String opponentId;
  final String opponentName;
  final String opponentUsername;
  final bool isAttacker;
  final bool won;
  final String result;
  final int goldChange;
  final int ratingChange;
  final String timestamp;
  final String createdAt;
  final List<String> battleLog;

  factory PvPHistoryEntry.fromJson(Map<String, dynamic> json) {
    final dynamic logRaw = json['battle_log'];
    final List<String> battleLog = logRaw is List
        ? logRaw.map((e) => e.toString()).toList()
        : <String>[];

    return PvPHistoryEntry(
      id: (json['id'] ?? '').toString(),
      opponentId: (json['opponent_id'] ?? '').toString(),
      opponentName: (json['opponent_name'] ?? '').toString(),
      opponentUsername: (json['opponent_username'] ?? '').toString(),
      isAttacker: json['is_attacker'] == true,
      won: json['won'] == true,
      result: (json['result'] ?? 'draw').toString(),
      goldChange: _asInt(json['gold_change']),
      ratingChange: _asInt(json['rating_change']),
      timestamp: (json['timestamp'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      battleLog: battleLog,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'opponent_id': opponentId,
        'opponent_name': opponentName,
        'opponent_username': opponentUsername,
        'is_attacker': isAttacker,
        'won': won,
        'result': result,
        'gold_change': goldChange,
        'rating_change': ratingChange,
        'timestamp': timestamp,
        'created_at': createdAt,
        'battle_log': battleLog,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
