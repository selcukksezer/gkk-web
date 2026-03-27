import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/facility_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class FacilitiesRepository {
  Future<List<PlayerFacility>> fetchFacilities();
  Future<bool> unlockFacility({required String facilityType});
  Future<bool> upgradeFacility({required String facilityId});
  Future<bool> startProduction({required String facilityId});
  Future<Map<String, dynamic>?> collectResourcesV2({
    required String facilityId,
    required int seed,
    required int totalCount,
  });
  Future<bool> bribeOfficials({required String facilityType, required int gemAmount});
  Future<bool> syncGlobalSuspicionLevel({required int globalSuspicion});
}

class SupabaseFacilitiesRepository implements FacilitiesRepository {
  @override
  Future<List<PlayerFacility>> fetchFacilities() async {
    _ensureReady();

    try {
      final dynamic response = await SupabaseService.client.rpc('get_player_facilities_with_queue');

      if (response is List) {
        return response
            .whereType<Map>()
            .map((row) => PlayerFacility.fromJson(Map<String, dynamic>.from(row)))
            .where((f) => f.isActive)
            .toList();
      }

      if (response is Map) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response);
        final dynamic payload = data['data'];
        if (payload is List) {
          return payload
              .whereType<Map>()
              .map((row) => PlayerFacility.fromJson(Map<String, dynamic>.from(row)))
              .where((f) => f.isActive)
              .toList();
        }
      }

      return <PlayerFacility>[];
    } catch (e) {
      throw AppException('Tesisler yuklenemedi: ${_rpcErrorMessage(e)}', code: 'FACILITIES_FETCH_FAILED');
    }
  }

  @override
  Future<bool> unlockFacility({required String facilityType}) async {
    _ensureReady();

    try {
      await SupabaseService.client.rpc(
        'unlock_facility',
        params: <String, dynamic>{'p_type': facilityType},
      );
      return true;
    } catch (e) {
      throw AppException('Tesis acilamadi: ${_rpcErrorMessage(e)}', code: 'FACILITY_UNLOCK_FAILED');
    }
  }

  @override
  Future<bool> upgradeFacility({required String facilityId}) async {
    _ensureReady();

    try {
      await SupabaseService.client.rpc(
        'upgrade_facility',
        params: <String, dynamic>{'p_facility_id': facilityId},
      );
      return true;
    } catch (e) {
      throw AppException('Yukseltme basarisiz: ${_rpcErrorMessage(e)}', code: 'FACILITY_UPGRADE_FAILED');
    }
  }

  @override
  Future<bool> startProduction({required String facilityId}) async {
    _ensureReady();

    try {
      await SupabaseService.client.rpc(
        'start_facility_production',
        params: <String, dynamic>{'p_facility_id': facilityId},
      );
      return true;
    } catch (e) {
      throw AppException('Uretim baslatilamadi: ${_rpcErrorMessage(e)}', code: 'FACILITY_START_FAILED');
    }
  }

  @override
  Future<Map<String, dynamic>?> collectResourcesV2({
    required String facilityId,
    required int seed,
    required int totalCount,
  }) async {
    _ensureReady();

    try {
      final dynamic response = await SupabaseService.client.rpc(
        'collect_facility_resources_v2',
        params: <String, dynamic>{
          'p_facility_id': facilityId,
          'p_seed': seed,
          'p_total_count': totalCount,
        },
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return null;
    } catch (e) {
      throw AppException('Toplama basarisiz: ${_rpcErrorMessage(e)}', code: 'FACILITY_COLLECT_FAILED');
    }
  }

  @override
  Future<bool> bribeOfficials({required String facilityType, required int gemAmount}) async {
    _ensureReady();

    try {
      await SupabaseService.client.rpc(
        'bribe_officials',
        params: <String, dynamic>{
          'p_facility_type': facilityType,
          'p_amount_gems': gemAmount,
        },
      );
      return true;
    } catch (e) {
      throw AppException('Rusvet verilemedi: ${_rpcErrorMessage(e)}', code: 'FACILITY_BRIBE_FAILED');
    }
  }

  @override
  Future<bool> syncGlobalSuspicionLevel({required int globalSuspicion}) async {
    _ensureReady();

    try {
      await SupabaseService.client.rpc(
        'update_global_suspicion_level',
        params: <String, dynamic>{'p_global_suspicion': globalSuspicion},
      );
      return true;
    } catch (e) {
      throw AppException('Suphe senkronu basarisiz: ${_rpcErrorMessage(e)}', code: 'FACILITY_SUSPICION_SYNC_FAILED');
    }
  }

  String _rpcErrorMessage(Object error) {
    if (error is PostgrestException) {
      final String code = error.code ?? '';
      final String message = error.message.toString();
      final String details = error.details?.toString() ?? '';
      if (details.isNotEmpty) {
        return '$message ($code) - $details';
      }
      if (code.isNotEmpty) {
        return '$message ($code)';
      }
      return message;
    }
    return error.toString();
  }

  void _ensureReady() {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
  }
}
