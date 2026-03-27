class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresAt;

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? expiresAt,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: (json['expires_at'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSession &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, expiresAt);
}

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
    required this.deviceId,
  });

  final String email;
  final String password;
  final String deviceId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'password': password,
      'device_id': deviceId,
    };
  }
}

class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.username,
    required this.password,
    required this.deviceId,
    this.referralCode,
  });

  final String email;
  final String username;
  final String password;
  final String deviceId;
  final String? referralCode;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'username': username,
      'password': password,
      'device_id': deviceId,
      'referral_code': referralCode,
    };
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.level,
    required this.gold,
    required this.gems,
    required this.energy,
    required this.maxEnergy,
    required this.attack,
    required this.defense,
    required this.health,
    required this.maxHealth,
    required this.power,
    required this.guildId,
    required this.guildRole,
  });

  final String id;
  final String username;
  final String email;
  final int level;
  final int gold;
  final int gems;
  final int energy;
  final int maxEnergy;
  final int attack;
  final int defense;
  final int health;
  final int maxHealth;
  final int power;
  final String? guildId;
  final String? guildRole;

  AuthUser copyWith({
    String? id,
    String? username,
    String? email,
    int? level,
    int? gold,
    int? gems,
    int? energy,
    int? maxEnergy,
    int? attack,
    int? defense,
    int? health,
    int? maxHealth,
    int? power,
    String? guildId,
    String? guildRole,
    bool clearGuildId = false,
    bool clearGuildRole = false,
  }) {
    return AuthUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      level: level ?? this.level,
      gold: gold ?? this.gold,
      gems: gems ?? this.gems,
      energy: energy ?? this.energy,
      maxEnergy: maxEnergy ?? this.maxEnergy,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      health: health ?? this.health,
      maxHealth: maxHealth ?? this.maxHealth,
      power: power ?? this.power,
      guildId: clearGuildId ? null : (guildId ?? this.guildId),
      guildRole: clearGuildRole ? null : (guildRole ?? this.guildRole),
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      level: (json['level'] as num).toInt(),
      gold: (json['gold'] as num).toInt(),
      gems: (json['gems'] as num).toInt(),
      energy: (json['energy'] as num).toInt(),
      maxEnergy: (json['max_energy'] as num).toInt(),
      attack: (json['attack'] as num).toInt(),
      defense: (json['defense'] as num).toInt(),
      health: (json['health'] as num).toInt(),
      maxHealth: (json['max_health'] as num).toInt(),
      power: (json['power'] as num).toInt(),
      guildId: json['guild_id'] as String?,
      guildRole: json['guild_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,
      'level': level,
      'gold': gold,
      'gems': gems,
      'energy': energy,
      'max_energy': maxEnergy,
      'attack': attack,
      'defense': defense,
      'health': health,
      'max_health': maxHealth,
      'power': power,
      'guild_id': guildId,
      'guild_role': guildRole,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthUser &&
        other.id == id &&
        other.username == username &&
        other.email == email &&
        other.level == level &&
        other.gold == gold &&
        other.gems == gems &&
        other.energy == energy &&
        other.maxEnergy == maxEnergy &&
        other.attack == attack &&
        other.defense == defense &&
        other.health == health &&
        other.maxHealth == maxHealth &&
        other.power == power &&
        other.guildId == guildId &&
        other.guildRole == guildRole;
  }

  @override
  int get hashCode => Object.hash(
        id,
        username,
        email,
        level,
        gold,
        gems,
        energy,
        maxEnergy,
        attack,
        defense,
        health,
        maxHealth,
        power,
        guildId,
        guildRole,
      );
}

class AuthResponse {
  const AuthResponse({
    required this.session,
    required this.user,
  });

  final AuthSession session;
  final AuthUser user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      session: AuthSession.fromJson(json['session'] as Map<String, dynamic>),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'session': session.toJson(),
      'user': user.toJson(),
    };
  }
}
