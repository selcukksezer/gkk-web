import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/auth_model.dart';

abstract class AuthRepository {
  Future<AuthSession?> currentSession();
  Future<AuthResponse> login(LoginRequest request);
  Future<AuthResponse> register(RegisterRequest request);
  Future<void> logout();
}

class SupabaseAuthRepository implements AuthRepository {
  @override
  Future<AuthSession?> currentSession() async {
    if (!SupabaseService.isConfigured) return null;

    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;

    return AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      expiresAt: session.expiresAt ?? 0,
    );
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    if (!SupabaseService.isConfigured) {
      throw AppException(
        'Supabase baglantisi ayarlanmadi. app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    final result = await SupabaseService.client.auth.signInWithPassword(
      email: request.email,
      password: request.password,
    );

    final session = result.session;
    final user = result.user;
    if (session == null || user == null) {
      throw AppException('Giris basarisiz. Oturum olusturulamadi.', code: 'AUTH_LOGIN_FAILED');
    }

    return AuthResponse(
      session: AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        expiresAt: session.expiresAt ?? 0,
      ),
      user: AuthUser(
        id: user.id,
        username: user.userMetadata?['username'] as String? ?? user.email ?? 'unknown',
        email: user.email ?? '',
        level: (user.userMetadata?['level'] as num?)?.toInt() ?? 1,
        gold: (user.userMetadata?['gold'] as num?)?.toInt() ?? 0,
        gems: (user.userMetadata?['gems'] as num?)?.toInt() ?? 0,
        energy: (user.userMetadata?['energy'] as num?)?.toInt() ?? 100,
        maxEnergy: (user.userMetadata?['max_energy'] as num?)?.toInt() ?? 100,
        attack: (user.userMetadata?['attack'] as num?)?.toInt() ?? 0,
        defense: (user.userMetadata?['defense'] as num?)?.toInt() ?? 0,
        health: (user.userMetadata?['health'] as num?)?.toInt() ?? 100,
        maxHealth: (user.userMetadata?['max_health'] as num?)?.toInt() ?? 100,
        power: (user.userMetadata?['power'] as num?)?.toInt() ?? 0,
        guildId: user.userMetadata?['guild_id'] as String?,
        guildRole: user.userMetadata?['guild_role'] as String?,
      ),
    );
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    if (!SupabaseService.isConfigured) {
      throw AppException(
        'Supabase baglantisi ayarlanmadi. app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    final result = await SupabaseService.client.auth.signUp(
      email: request.email,
      password: request.password,
      data: <String, dynamic>{
        'username': request.username,
        if (request.referralCode != null) 'referral_code': request.referralCode,
      },
    );

    final session = result.session;
    final user = result.user;
    if (user == null) {
      throw AppException('Kayit basarisiz. Kullanici olusturulamadi.', code: 'AUTH_REGISTER_FAILED');
    }

    return AuthResponse(
      session: AuthSession(
        accessToken: session?.accessToken ?? '',
        refreshToken: session?.refreshToken ?? '',
        expiresAt: session?.expiresAt ?? 0,
      ),
      user: AuthUser(
        id: user.id,
        username: request.username,
        email: user.email ?? request.email,
        level: 1,
        gold: 0,
        gems: 0,
        energy: 100,
        maxEnergy: 100,
        attack: 0,
        defense: 0,
        health: 100,
        maxHealth: 100,
        power: 0,
        guildId: null,
        guildRole: null,
      ),
    );
  }

  @override
  Future<void> logout() async {
    if (!SupabaseService.isConfigured) return;
    await SupabaseService.client.auth.signOut();
  }
}
