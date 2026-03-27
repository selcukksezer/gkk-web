enum CharacterClass {
  warrior,
  alchemist,
  shadow,
}

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.authId,
    required this.username,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.level,
    required this.xp,
    required this.gold,
    required this.gems,
    required this.energy,
    required this.maxEnergy,
    required this.attack,
    required this.defense,
    required this.health,
    required this.maxHealth,
    required this.power,
    required this.isOnline,
    required this.isBanned,
    required this.tutorialCompleted,
    required this.guildId,
    required this.guildRole,
    required this.referralCode,
    required this.referredBy,
    required this.pvpRating,
    required this.pvpWins,
    required this.pvpLosses,
    required this.addictionLevel,
    required this.tolerance,
    required this.lastPotionUsedAt,
    required this.warriorBloodlustUntil,
    required this.hospitalUntil,
    required this.prisonUntil,
    required this.prisonReason,
    required this.globalSuspicionLevel,
    required this.lastBribeAt,
    required this.lastLoginAt,
    required this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
    this.reputation,
    this.guildName,
    this.title,
    this.endurance,
    this.agility,
    this.intelligence,
    this.luck,
    this.characterClass,
    this.hp,
  });

  final String id;
  final String authId;
  final String username;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int gold;
  final int gems;
  final int energy;
  final int maxEnergy;
  final int attack;
  final int defense;
  final int health;
  final int maxHealth;
  final int power;
  final bool isOnline;
  final bool isBanned;
  final bool tutorialCompleted;
  final String? guildId;
  final String? guildRole;
  final String? referralCode;
  final String? referredBy;
  final int pvpRating;
  final int pvpWins;
  final int pvpLosses;
  final int addictionLevel;
  final int tolerance;
  final String? lastPotionUsedAt;
  final String? warriorBloodlustUntil;
  final String? hospitalUntil;
  final String? prisonUntil;
  final String? prisonReason;
  final int globalSuspicionLevel;
  final String? lastBribeAt;
  final String? lastLoginAt;
  final String? lastLogin;
  final String createdAt;
  final String updatedAt;

  final int? reputation;
  final String? guildName;
  final String? title;
  final int? endurance;
  final int? agility;
  final int? intelligence;
  final int? luck;
  final CharacterClass? characterClass;
  final int? hp;

  PlayerProfile copyWith({
    String? id,
    String? authId,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    int? level,
    int? xp,
    int? gold,
    int? gems,
    int? energy,
    int? maxEnergy,
    int? attack,
    int? defense,
    int? health,
    int? maxHealth,
    int? power,
    bool? isOnline,
    bool? isBanned,
    bool? tutorialCompleted,
    String? guildId,
    String? guildRole,
    String? referralCode,
    String? referredBy,
    int? pvpRating,
    int? pvpWins,
    int? pvpLosses,
    int? addictionLevel,
    int? tolerance,
    String? lastPotionUsedAt,
    String? warriorBloodlustUntil,
    String? hospitalUntil,
    String? prisonUntil,
    String? prisonReason,
    int? globalSuspicionLevel,
    String? lastBribeAt,
    String? lastLoginAt,
    String? lastLogin,
    String? createdAt,
    String? updatedAt,
    int? reputation,
    String? guildName,
    String? title,
    int? endurance,
    int? agility,
    int? intelligence,
    int? luck,
    CharacterClass? characterClass,
    int? hp,
    bool clearDisplayName = false,
    bool clearAvatarUrl = false,
    bool clearGuildId = false,
    bool clearGuildRole = false,
    bool clearReferralCode = false,
    bool clearReferredBy = false,
    bool clearLastPotionUsedAt = false,
    bool clearWarriorBloodlustUntil = false,
    bool clearHospitalUntil = false,
    bool clearPrisonUntil = false,
    bool clearPrisonReason = false,
    bool clearLastBribeAt = false,
    bool clearLastLoginAt = false,
    bool clearLastLogin = false,
    bool clearGuildName = false,
    bool clearTitle = false,
    bool clearCharacterClass = false,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      authId: authId ?? this.authId,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      level: level ?? this.level,
      xp: xp ?? this.xp,
      gold: gold ?? this.gold,
      gems: gems ?? this.gems,
      energy: energy ?? this.energy,
      maxEnergy: maxEnergy ?? this.maxEnergy,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      health: health ?? this.health,
      maxHealth: maxHealth ?? this.maxHealth,
      power: power ?? this.power,
      isOnline: isOnline ?? this.isOnline,
      isBanned: isBanned ?? this.isBanned,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      guildId: clearGuildId ? null : (guildId ?? this.guildId),
      guildRole: clearGuildRole ? null : (guildRole ?? this.guildRole),
      referralCode: clearReferralCode ? null : (referralCode ?? this.referralCode),
      referredBy: clearReferredBy ? null : (referredBy ?? this.referredBy),
      pvpRating: pvpRating ?? this.pvpRating,
      pvpWins: pvpWins ?? this.pvpWins,
      pvpLosses: pvpLosses ?? this.pvpLosses,
      addictionLevel: addictionLevel ?? this.addictionLevel,
      tolerance: tolerance ?? this.tolerance,
      lastPotionUsedAt:
          clearLastPotionUsedAt ? null : (lastPotionUsedAt ?? this.lastPotionUsedAt),
      warriorBloodlustUntil: clearWarriorBloodlustUntil
          ? null
          : (warriorBloodlustUntil ?? this.warriorBloodlustUntil),
      hospitalUntil: clearHospitalUntil ? null : (hospitalUntil ?? this.hospitalUntil),
      prisonUntil: clearPrisonUntil ? null : (prisonUntil ?? this.prisonUntil),
      prisonReason: clearPrisonReason ? null : (prisonReason ?? this.prisonReason),
      globalSuspicionLevel: globalSuspicionLevel ?? this.globalSuspicionLevel,
      lastBribeAt: clearLastBribeAt ? null : (lastBribeAt ?? this.lastBribeAt),
      lastLoginAt: clearLastLoginAt ? null : (lastLoginAt ?? this.lastLoginAt),
      lastLogin: clearLastLogin ? null : (lastLogin ?? this.lastLogin),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reputation: reputation ?? this.reputation,
      guildName: clearGuildName ? null : (guildName ?? this.guildName),
      title: clearTitle ? null : (title ?? this.title),
      endurance: endurance ?? this.endurance,
      agility: agility ?? this.agility,
      intelligence: intelligence ?? this.intelligence,
      luck: luck ?? this.luck,
      characterClass:
          clearCharacterClass ? null : (characterClass ?? this.characterClass),
      hp: hp ?? this.hp,
    );
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final String? rawCharacterClass = json['character_class'] as String?;
    return PlayerProfile(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      level: (json['level'] as num).toInt(),
      xp: (json['xp'] as num).toInt(),
      gold: (json['gold'] as num).toInt(),
      gems: (json['gems'] as num).toInt(),
      energy: (json['energy'] as num).toInt(),
      maxEnergy: (json['max_energy'] as num).toInt(),
      attack: (json['attack'] as num).toInt(),
      defense: (json['defense'] as num).toInt(),
      health: (json['health'] as num).toInt(),
      maxHealth: (json['max_health'] as num).toInt(),
      power: (json['power'] as num).toInt(),
      isOnline: json['is_online'] as bool,
      isBanned: json['is_banned'] as bool,
      tutorialCompleted: json['tutorial_completed'] as bool,
      guildId: json['guild_id'] as String?,
      guildRole: json['guild_role'] as String?,
      referralCode: json['referral_code'] as String?,
      referredBy: json['referred_by'] as String?,
      pvpRating: (json['pvp_rating'] as num).toInt(),
      pvpWins: (json['pvp_wins'] as num).toInt(),
      pvpLosses: (json['pvp_losses'] as num).toInt(),
      addictionLevel: (json['addiction_level'] as num).toInt(),
      tolerance: (json['tolerance'] as num).toInt(),
      lastPotionUsedAt: json['last_potion_used_at'] as String?,
      warriorBloodlustUntil: json['warrior_bloodlust_until'] as String?,
      hospitalUntil: json['hospital_until'] as String?,
      prisonUntil: json['prison_until'] as String?,
      prisonReason: json['prison_reason'] as String?,
      globalSuspicionLevel: (json['global_suspicion_level'] as num).toInt(),
      lastBribeAt: json['last_bribe_at'] as String?,
      lastLoginAt: json['last_login_at'] as String?,
      lastLogin: json['last_login'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      reputation: (json['reputation'] as num?)?.toInt(),
      guildName: json['guild_name'] as String?,
      title: json['title'] as String?,
      endurance: (json['endurance'] as num?)?.toInt(),
      agility: (json['agility'] as num?)?.toInt(),
      intelligence: (json['intelligence'] as num?)?.toInt(),
      luck: (json['luck'] as num?)?.toInt(),
      characterClass: CharacterClassParsing.fromNullable(rawCharacterClass),
      hp: (json['hp'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'auth_id': authId,
      'username': username,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'level': level,
      'xp': xp,
      'gold': gold,
      'gems': gems,
      'energy': energy,
      'max_energy': maxEnergy,
      'attack': attack,
      'defense': defense,
      'health': health,
      'max_health': maxHealth,
      'power': power,
      'is_online': isOnline,
      'is_banned': isBanned,
      'tutorial_completed': tutorialCompleted,
      'guild_id': guildId,
      'guild_role': guildRole,
      'referral_code': referralCode,
      'referred_by': referredBy,
      'pvp_rating': pvpRating,
      'pvp_wins': pvpWins,
      'pvp_losses': pvpLosses,
      'addiction_level': addictionLevel,
      'tolerance': tolerance,
      'last_potion_used_at': lastPotionUsedAt,
      'warrior_bloodlust_until': warriorBloodlustUntil,
      'hospital_until': hospitalUntil,
      'prison_until': prisonUntil,
      'prison_reason': prisonReason,
      'global_suspicion_level': globalSuspicionLevel,
      'last_bribe_at': lastBribeAt,
      'last_login_at': lastLoginAt,
      'last_login': lastLogin,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'reputation': reputation,
      'guild_name': guildName,
      'title': title,
      'endurance': endurance,
      'agility': agility,
      'intelligence': intelligence,
      'luck': luck,
      'character_class': characterClass?.name,
      'hp': hp,
    };
  }
}

class PlayerStats {
  const PlayerStats({
    required this.totalPower,
    required this.winRate,
    required this.questsCompleted,
    required this.dungeonClears,
  });

  final int totalPower;
  final double winRate;
  final int questsCompleted;
  final int dungeonClears;

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      totalPower: (json['totalPower'] as num).toInt(),
      winRate: (json['winRate'] as num).toDouble(),
      questsCompleted: (json['questsCompleted'] as num).toInt(),
      dungeonClears: (json['dungeonClears'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'totalPower': totalPower,
      'winRate': winRate,
      'questsCompleted': questsCompleted,
      'dungeonClears': dungeonClears,
    };
  }
}

extension CharacterClassParsing on CharacterClass {
  static CharacterClass fromValue(String value) {
    return CharacterClass.values.firstWhere((CharacterClass e) => e.name == value);
  }

  static CharacterClass? fromNullable(String? value) {
    if (value == null || value.isEmpty) return null;
    return fromValue(value);
  }
}
