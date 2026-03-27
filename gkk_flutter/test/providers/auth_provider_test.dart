import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/providers/auth_provider.dart';
import 'package:gkk_flutter/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.session,
    this.loginResponse,
  });

  final AuthSession? session;
  final AuthResponse? loginResponse;

  @override
  Future<AuthSession?> currentSession() async => session;

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    if (loginResponse == null) {
      throw Exception('No fake login response');
    }
    return loginResponse!;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthResponse> register(RegisterRequest request) {
    throw UnimplementedError();
  }
}

void main() {
  test('loadSession sets unauthenticated when no session exists', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session: null)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).loadSession();

    final AuthState state = container.read(authProvider);
    expect(state.status, AuthStatus.unauthenticated);
  });

  test('login sets authenticated with session and user', () async {
    final fakeResponse = AuthResponse(
      session: const AuthSession(accessToken: 'a', refreshToken: 'r', expiresAt: 1),
      user: const AuthUser(
        id: 'u1',
        username: 'selcuk',
        email: 's@example.com',
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

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(loginResponse: fakeResponse)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).login(
          email: 's@example.com',
          password: '123456',
          deviceId: 'device',
        );

    final AuthState state = container.read(authProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.user?.id, 'u1');
  });
}
