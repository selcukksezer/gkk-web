import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../models/facility_model.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';
import '../repositories/facilities_repository.dart';

enum FacilitiesStatus {
  initial,
  loading,
  ready,
  error,
}

class FacilitiesState {
  const FacilitiesState({
    required this.status,
    required this.facilities,
    this.errorMessage,
  });

  final FacilitiesStatus status;
  final List<PlayerFacility> facilities;
  final String? errorMessage;

  factory FacilitiesState.initial() => const FacilitiesState(
        status: FacilitiesStatus.initial,
        facilities: <PlayerFacility>[],
      );

  FacilitiesState copyWith({
    FacilitiesStatus? status,
    List<PlayerFacility>? facilities,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FacilitiesState(
      status: status ?? this.status,
      facilities: facilities ?? this.facilities,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final Provider<FacilitiesRepository> facilitiesRepositoryProvider =
    Provider<FacilitiesRepository>((Ref ref) {
  return SupabaseFacilitiesRepository();
});

class FacilitiesNotifier extends Notifier<FacilitiesState> {
  FacilitiesRepository get _repository => ref.read(facilitiesRepositoryProvider);

  @override
  FacilitiesState build() => FacilitiesState.initial();

  Future<void> loadFacilities() async {
    state = state.copyWith(status: FacilitiesStatus.loading, clearError: true);

    try {
      final List<PlayerFacility> facilities = await _repository.fetchFacilities();
      state = state.copyWith(status: FacilitiesStatus.ready, facilities: facilities);
    } on AppException catch (e) {
      state = state.copyWith(status: FacilitiesStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(status: FacilitiesStatus.error, errorMessage: 'Tesisler yuklenemedi');
    }
  }

  Future<bool> unlockFacility({required String facilityType}) async {
    try {
      final bool ok = await _repository.unlockFacility(facilityType: facilityType);
      if (ok) {
        await loadFacilities();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Tesis acilamadi');
      return false;
    }
  }

  Future<bool> bribeOfficials({required String facilityType, required int gemAmount}) async {
    try {
      final int currentSuspicion = ref.read(playerProvider).profile?.globalSuspicionLevel ?? 0;
      if (currentSuspicion <= 0) {
        state = state.copyWith(errorMessage: 'Genel suphe 0 iken rusvet verilemez');
        return false;
      }

      final bool ok = await _repository.bribeOfficials(
        facilityType: facilityType,
        gemAmount: gemAmount,
      );
      if (ok) {
        await loadFacilities();
        await _syncGlobalSuspicionToServer();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Rusvet verilemedi');
      return false;
    }
  }

  Future<bool> upgradeFacility({required String facilityId}) async {
    try {
      final bool ok = await _repository.upgradeFacility(facilityId: facilityId);
      if (ok) {
        await loadFacilities();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Yukseltme basarisiz');
      return false;
    }
  }

  Future<bool> startProduction({required String facilityId}) async {
    try {
      final bool ok = await _repository.startProduction(facilityId: facilityId);
      if (ok) {
        await loadFacilities();
        await _syncGlobalSuspicionToServer();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Uretim baslatilamadi');
      return false;
    }
  }

  Future<Map<String, dynamic>?> collectResourcesV2({
    required String facilityId,
    required int seed,
    required int totalCount,
  }) async {
    try {
      final InventoryNotifier inventory = ref.read(inventoryProvider.notifier);
      await inventory.loadInventory(silent: true);

      final InventoryAddCheck capacityCheck = inventory.canAddItem(itemId: 'resource_placeholder', quantity: totalCount);
      if (!capacityCheck.canAdd) {
        state = state.copyWith(errorMessage: capacityCheck.reason ?? 'Envanter dolu! Kapasite yetersiz.');
        return null;
      }

      final Map<String, int> inventoryBefore = <String, int>{};
      for (final item in ref.read(inventoryProvider).items) {
        inventoryBefore[item.itemId] = inventory.getItemQuantity(item.itemId);
      }

      Map<String, dynamic>? result;
      int requestCount = totalCount;
      AppException? lastCapacityError;

      while (requestCount > 0) {
        try {
          result = await _repository.collectResourcesV2(
            facilityId: facilityId,
            seed: seed,
            totalCount: requestCount,
          );
          break;
        } on AppException catch (e) {
          final String lower = e.message.toLowerCase();
          final bool isInventoryFull = lower.contains('envanter dolu') || lower.contains('inventory full');
          if (!isInventoryFull) {
            rethrow;
          }

          lastCapacityError = e;
          if (requestCount <= 1) {
            state = state.copyWith(errorMessage: e.message);
            return null;
          }

          final int next = requestCount > 10 ? requestCount - (requestCount ~/ 4) : requestCount - 1;
          requestCount = next < 1 ? 1 : next;
        }
      }

      if (result == null) {
        state = state.copyWith(errorMessage: lastCapacityError?.message ?? 'Toplama basarisiz');
        return null;
      }

      await loadFacilities();
      await _syncGlobalSuspicionToServer();

      await inventory.loadInventory(silent: true);

      final bool admissionOccurred = result['admission_occurred'] == true;
      final dynamic rawGenerated = result['items_generated'];

      if (!admissionOccurred && rawGenerated is List) {
        final Map<String, int> generatedAgg = <String, int>{};
        for (final dynamic entry in rawGenerated) {
          if (entry is Map) {
            final Map<dynamic, dynamic> row = entry;
            final String itemId =
                (row['item_id'] ?? row['itemId'] ?? row['id'] ?? '').toString();
            if (itemId.isEmpty) continue;
            final int qty = (row['quantity'] as num?)?.toInt() ?? 1;
            generatedAgg[itemId] = (generatedAgg[itemId] ?? 0) + qty;
          }
        }

        final Map<String, int> afterCounts = <String, int>{};
        for (final item in ref.read(inventoryProvider).items) {
          afterCounts[item.itemId] = inventory.getItemQuantity(item.itemId);
        }

        for (final MapEntry<String, int> generated in generatedAgg.entries) {
          final int before = inventoryBefore[generated.key] ?? 0;
          final int after = afterCounts[generated.key] ?? 0;
          final int delta = generated.value - (after - before);
          if (delta > 0) {
            await inventory.addItemToServer(itemId: generated.key, quantity: delta);
          }
        }

        await inventory.loadInventory(silent: true);
      }

      return result;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Toplama basarisiz');
      return null;
    }
  }

  Future<void> _syncGlobalSuspicionToServer() async {
    final int rawRisk = _calculateGlobalSuspicionRisk();
    await _repository.syncGlobalSuspicionLevel(globalSuspicion: rawRisk);
    await ref.read(playerProvider.notifier).loadProfile();
  }

  int _calculateGlobalSuspicionRisk() {
    final String? lastBribeAt = ref.read(playerProvider).profile?.lastBribeAt;
    final int bribeTs = DateTime.tryParse(lastBribeAt ?? '')?.millisecondsSinceEpoch ?? 0;

    int activeCount = 0;
    int levelSum = 0;

    for (final PlayerFacility facility in state.facilities) {
      final int? startedTs = DateTime.tryParse(facility.productionStartedAt ?? '')?.millisecondsSinceEpoch;
      if (startedTs != null && startedTs >= bribeTs) {
        activeCount++;
        levelSum += facility.level;
      }
    }

    final int risk = (activeCount * 5) + (levelSum ~/ 2);
    if (risk < 0) return 0;
    if (risk > 100) return 100;
    return risk;
  }
}

final NotifierProvider<FacilitiesNotifier, FacilitiesState> facilitiesProvider =
    NotifierProvider<FacilitiesNotifier, FacilitiesState>(FacilitiesNotifier.new);
