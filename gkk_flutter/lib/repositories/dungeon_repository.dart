import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/dungeon_model.dart';

abstract class DungeonRepository {
  Future<List<DungeonData>> getDungeons();
  Future<DungeonResult> enterDungeon({required String dungeonId});
}

class SupabaseDungeonRepository implements DungeonRepository {
  @override
  Future<List<DungeonData>> getDungeons() async {
    _ensureReady();

    try {
      final dynamic response = await SupabaseService.client.rpc('get_dungeons');
      final List<DungeonData> parsed = _extractDungeonList(response);
      if (parsed.isNotEmpty) return parsed;
      // Fallback: some DBs may not have the RPC deployed; select directly from table.
      final dynamic selectResp = await SupabaseService.client.from('dungeons').select('*').order('dungeon_order', ascending: true);
      final List<DungeonData> direct = _extractDungeonList(selectResp);
      if (direct.isNotEmpty) return direct;
      return parsed; // empty list
    } catch (_) {
      // Try direct select as a resilient fallback
      try {
        final dynamic selectResp = await SupabaseService.client.from('dungeons').select('*').order('dungeon_order', ascending: true);
        final List<DungeonData> direct = _extractDungeonList(selectResp);
        return direct;
      } catch (_) {
        throw AppException('Zindan listesi yuklenemedi.', code: 'DUNGEON_FETCH_FAILED');
      }
    }
  }

  @override
  Future<DungeonResult> enterDungeon({required String dungeonId}) async {
    _ensureReady();
    try {
      final String? currentUserId = SupabaseService.client.auth.currentUser?.id;
      // First try: call newer RPC signature that takes player id + dungeon id
      final dynamic response = await SupabaseService.client.rpc(
        'enter_dungeon',
        params: <String, dynamic>{'p_player_id': currentUserId, 'p_dungeon_id': dungeonId},
      );

      if (response is Map) {
        return DungeonResult.fromJson(Map<String, dynamic>.from(response));
      }

      throw AppException('Zindan cevabi alinamadi.', code: 'DUNGEON_ENTER_EMPTY');
    } on AppException {
      rethrow;
    } catch (_) {
      // Fallback: try older RPC signature (only dungeon id) for backward compatibility
      try {
        final dynamic response2 = await SupabaseService.client.rpc(
          'enter_dungeon',
          params: <String, dynamic>{'p_dungeon_id': dungeonId},
        );

        if (response2 is Map) {
          return DungeonResult.fromJson(Map<String, dynamic>.from(response2));
        }

        throw AppException('Zindan cevabi alinamadi.', code: 'DUNGEON_ENTER_EMPTY');
      } on AppException {
        rethrow;
      } catch (_) {
        throw AppException('Zindana giris basarisiz.', code: 'DUNGEON_ENTER_FAILED');
      }
    }
  }

  void _ensureReady() {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
  }

  List<DungeonData> _extractDungeonList(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((row) => DungeonData.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }

    if (payload is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(payload);
      final dynamic direct = map['items'] ?? map['data'];
      if (direct is List) {
        return direct
            .whereType<Map>()
            .map((row) => DungeonData.fromJson(Map<String, dynamic>.from(row)))
            .toList();
      }
    }

    return <DungeonData>[];
  }
}
