import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../models/dungeon_model.dart';
import '../repositories/dungeon_repository.dart';

enum DungeonStatus {
  initial,
  loading,
  ready,
  error,
}

class DungeonState {
  const DungeonState({
    required this.status,
    required this.dungeons,
    this.lastResult,
    this.errorMessage,
    this.entering = false,
  });

  final DungeonStatus status;
  final List<DungeonData> dungeons;
  final DungeonResult? lastResult;
  final String? errorMessage;
  final bool entering;

  factory DungeonState.initial() => const DungeonState(
        status: DungeonStatus.initial,
        dungeons: <DungeonData>[],
      );

  DungeonState copyWith({
    DungeonStatus? status,
    List<DungeonData>? dungeons,
    DungeonResult? lastResult,
    String? errorMessage,
    bool? entering,
    bool clearError = false,
    bool clearLastResult = false,
  }) {
    return DungeonState(
      status: status ?? this.status,
      dungeons: dungeons ?? this.dungeons,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      entering: entering ?? this.entering,
    );
  }
}

final Provider<DungeonRepository> dungeonRepositoryProvider =
    Provider<DungeonRepository>((Ref ref) {
  return SupabaseDungeonRepository();
});

class DungeonNotifier extends Notifier<DungeonState> {
  DungeonRepository get _repository => ref.read(dungeonRepositoryProvider);

  @override
  DungeonState build() => DungeonState.initial();

  Future<void> loadDungeons() async {
    state = state.copyWith(status: DungeonStatus.loading, clearError: true);
    try {
      final dungeons = await _repository.getDungeons();
      state = state.copyWith(
        status: DungeonStatus.ready,
        dungeons: dungeons,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: DungeonStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: DungeonStatus.error,
        errorMessage: 'Zindan listesi yuklenirken beklenmeyen bir hata olustu.',
      );
    }
  }

  Future<DungeonResult?> enterDungeon({required String dungeonId}) async {
    state = state.copyWith(entering: true, clearError: true, clearLastResult: true);
    try {
      final result = await _repository.enterDungeon(dungeonId: dungeonId);
      state = state.copyWith(lastResult: result, entering: false);
      return result;
    } on AppException catch (e) {
      state = state.copyWith(entering: false, errorMessage: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        entering: false,
        errorMessage: 'Zindan operasyonu sirasinda beklenmeyen bir hata olustu.',
      );
      return null;
    }
  }

  void clearResult() {
    state = state.copyWith(clearLastResult: true);
  }
}

final NotifierProvider<DungeonNotifier, DungeonState> dungeonProvider =
    NotifierProvider<DungeonNotifier, DungeonState>(DungeonNotifier.new);
