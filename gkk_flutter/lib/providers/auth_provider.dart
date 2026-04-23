import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../models/auth_model.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthSession? session;
  final AuthUser? user;
  final String? errorMessage;

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    AuthUser? user,
    String? errorMessage,
    bool clearSession = false,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return SupabaseAuthRepository();
});

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() => AuthState.initial();

  Future<void> loadSession() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final session = await _repository.currentSession();
      if (session == null || session.accessToken.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          clearUser: true,
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await _repository.login(
        LoginRequest(email: email, password: password, deviceId: deviceId),
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: response.session,
        user: response.user,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Giris sirasinda beklenmeyen bir hata olustu.',
      );
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String deviceId,
    String? referralCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await _repository.register(
        RegisterRequest(
          email: email,
          username: username,
          password: password,
          deviceId: deviceId,
          referralCode: referralCode,
        ),
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: response.session,
        user: response.user,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Kayit sirasinda beklenmeyen bir hata olustu.',
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repository.logout();
    } catch (_) {
      // Oturum sunucuda zaten düşmüş olabilir; istemci durumunu yine de temizle.
    } finally {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        clearUser: true,
      );
    }
  }
}

final NotifierProvider<AuthNotifier, AuthState> authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
