import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../models/player_model.dart';
import '../repositories/player_repository.dart';

enum PlayerStatus {
  initial,
  loading,
  ready,
  error,
}

class PlayerState {
  const PlayerState({
    required this.status,
    this.profile,
    this.errorMessage,
  });

  final PlayerStatus status;
  final PlayerProfile? profile;
  final String? errorMessage;

  factory PlayerState.initial() => const PlayerState(status: PlayerStatus.initial);

  PlayerState copyWith({
    PlayerStatus? status,
    PlayerProfile? profile,
    String? errorMessage,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return PlayerState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final Provider<PlayerRepository> playerRepositoryProvider = Provider<PlayerRepository>((Ref ref) {
  return SupabasePlayerRepository();
});

class PlayerNotifier extends Notifier<PlayerState> {
  PlayerRepository get _repository => ref.read(playerRepositoryProvider);

  @override
  PlayerState build() => PlayerState.initial();

  Future<void> loadProfile() async {
    state = state.copyWith(status: PlayerStatus.loading, clearError: true);
    try {
      final profile = await _repository.loadCurrentPlayer();
      state = state.copyWith(status: PlayerStatus.ready, profile: profile);
    } on AppException catch (e) {
      state = state.copyWith(status: PlayerStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: PlayerStatus.error,
        errorMessage: 'Profil yuklenirken beklenmeyen bir hata olustu.',
      );
    }
  }

  void clear() {
    state = state.copyWith(status: PlayerStatus.initial, clearProfile: true, clearError: true);
  }
}

final NotifierProvider<PlayerNotifier, PlayerState> playerProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);
