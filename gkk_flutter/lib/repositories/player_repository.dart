import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/player_model.dart';

abstract class PlayerRepository {
  Future<PlayerProfile> loadCurrentPlayer();
}

class SupabasePlayerRepository implements PlayerRepository {
  @override
  Future<PlayerProfile> loadCurrentPlayer() async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      throw AppException('Aktif kullanici bulunamadi.', code: 'AUTH_REQUIRED');
    }

    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('auth_id', currentUser.id)
          .single();

      final json = Map<String, dynamic>.from(response as Map);
      return PlayerProfile.fromJson(json);
    } catch (_) {
      throw AppException('Oyuncu profili yuklenemedi.', code: 'PLAYER_LOAD_FAILED');
    }
  }
}
