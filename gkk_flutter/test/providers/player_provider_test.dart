import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/errors/app_exception.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/repositories/player_repository.dart';

class FakePlayerRepository implements PlayerRepository {
  FakePlayerRepository({this.profile, this.error});

  final PlayerProfile? profile;
  final AppException? error;

  @override
  Future<PlayerProfile> loadCurrentPlayer() async {
    if (error != null) throw error!;
    if (profile != null) return profile!;
    throw AppException('No profile', code: 'NO_PROFILE');
  }
}

PlayerProfile _sampleProfile() {
  return const PlayerProfile(
    id: 'p1',
    authId: 'a1',
    username: 'selcuk',
    email: 's@example.com',
    displayName: null,
    avatarUrl: null,
    level: 10,
    xp: 100,
    gold: 500,
    gems: 20,
    energy: 70,
    maxEnergy: 100,
    attack: 12,
    defense: 8,
    health: 95,
    maxHealth: 100,
    power: 30,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: null,
    guildRole: null,
    referralCode: null,
    referredBy: null,
    pvpRating: 1000,
    pvpWins: 3,
    pvpLosses: 2,
    addictionLevel: 0,
    tolerance: 0,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: null,
    prisonUntil: null,
    prisonReason: null,
    globalSuspicionLevel: 0,
    lastBribeAt: null,
    lastLoginAt: null,
    lastLogin: null,
    createdAt: '2026-03-27T00:00:00Z',
    updatedAt: '2026-03-27T00:00:00Z',
  );
}

void main() {
  test('loadProfile sets ready state on success', () async {
    final container = ProviderContainer(
      overrides: [
        playerRepositoryProvider.overrideWithValue(
          FakePlayerRepository(profile: _sampleProfile()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(playerProvider.notifier).loadProfile();

    final PlayerState state = container.read(playerProvider);
    expect(state.status, PlayerStatus.ready);
    expect(state.profile?.username, 'selcuk');
  });

  test('loadProfile sets error state on AppException', () async {
    final container = ProviderContainer(
      overrides: [
        playerRepositoryProvider.overrideWithValue(
          FakePlayerRepository(
            error: AppException('Profil yuklenemedi', code: 'PLAYER_LOAD_FAILED'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(playerProvider.notifier).loadProfile();

    final PlayerState state = container.read(playerProvider);
    expect(state.status, PlayerStatus.error);
    expect(state.errorMessage, 'Profil yuklenemedi');
  });
}
