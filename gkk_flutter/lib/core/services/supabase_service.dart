import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;

  static bool get isConfigured {
    return AppConstants.supabaseUrl.startsWith('https://') &&
        !AppConstants.supabaseUrl.contains('YOUR_PROJECT') &&
        AppConstants.supabaseAnonKey.isNotEmpty &&
        !AppConstants.supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');
  }

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) {
      return;
    }

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );

    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not initialized. Configure AppConstants and call initialize().',
      );
    }
    return Supabase.instance.client;
  }
}
