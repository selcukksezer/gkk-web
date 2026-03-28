enum GuildRole { leader, officer, member }

GuildRole _parseGuildRole(dynamic value) {
  switch (value?.toString()) {
    case 'leader':
      return GuildRole.leader;
    case 'officer':
      return GuildRole.officer;
    default:
      return GuildRole.member;
  }
}

String _guildRoleToString(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return 'leader';
    case GuildRole.officer:
      return 'officer';
    case GuildRole.member:
      return 'member';
  }
}

class GuildMemberData {
  const GuildMemberData({
    required this.playerId,
    this.userId,
    required this.username,
    required this.level,
    required this.role,
    required this.power,
    this.isOnline,
    this.contribution,
  });

  final String playerId;
  final String? userId;
  final String username;
  final int level;
  final GuildRole role;
  final int power;
  final bool? isOnline;
  final int? contribution;

  factory GuildMemberData.fromJson(Map<String, dynamic> json) {
    return GuildMemberData(
      playerId: (json['player_id'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      username: (json['username'] ?? '').toString(),
      level: _asInt(json['level'], fallback: 1),
      role: _parseGuildRole(json['role']),
      power: _asInt(json['power']),
      isOnline: json['is_online'] == null ? null : json['is_online'] == true,
      contribution: json['contribution'] == null
          ? null
          : _asInt(json['contribution']),
    );
  }

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'user_id': userId,
        'username': username,
        'level': level,
        'role': _guildRoleToString(role),
        'power': power,
        'is_online': isOnline,
        'contribution': contribution,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class GuildData {
  const GuildData({
    required this.guildId,
    required this.name,
    this.description,
    required this.level,
    required this.leaderId,
    required this.memberCount,
    required this.maxMembers,
    required this.totalPower,
    required this.monumentLevel,
    required this.monumentStructural,
    required this.monumentMystical,
    required this.monumentCritical,
    required this.monumentGoldPool,
    this.members,
  });

  final String guildId;
  final String name;
  final String? description;
  final int level;
  final String leaderId;
  final int memberCount;
  final int maxMembers;
  final int totalPower;
  final int monumentLevel;
  final int monumentStructural;
  final int monumentMystical;
  final int monumentCritical;
  final int monumentGoldPool;
  final List<GuildMemberData>? members;

  factory GuildData.fromJson(Map<String, dynamic> json) {
    final dynamic membersRaw = json['members'];
    final List<GuildMemberData>? members = membersRaw is List
        ? membersRaw
            .whereType<Map<String, dynamic>>()
            .map(GuildMemberData.fromJson)
            .toList()
        : null;

    return GuildData(
      guildId: (json['guild_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      level: _asInt(json['level'], fallback: 1),
      leaderId: (json['leader_id'] ?? '').toString(),
      memberCount: _asInt(json['member_count']),
      maxMembers: _asInt(json['max_members'], fallback: 50),
      totalPower: _asInt(json['total_power']),
      monumentLevel: _asInt(json['monument_level']),
      monumentStructural: _asInt(json['monument_structural']),
      monumentMystical: _asInt(json['monument_mystical']),
      monumentCritical: _asInt(json['monument_critical']),
      monumentGoldPool: _asInt(json['monument_gold_pool']),
      members: members,
    );
  }

  Map<String, dynamic> toJson() => {
        'guild_id': guildId,
        'name': name,
        'description': description,
        'level': level,
        'leader_id': leaderId,
        'member_count': memberCount,
        'max_members': maxMembers,
        'total_power': totalPower,
        'monument_level': monumentLevel,
        'monument_structural': monumentStructural,
        'monument_mystical': monumentMystical,
        'monument_critical': monumentCritical,
        'monument_gold_pool': monumentGoldPool,
        'members': members?.map((m) => m.toJson()).toList(),
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
