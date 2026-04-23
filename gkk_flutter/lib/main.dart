import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/services/supabase_service.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: GkkMobileApp()));
}

class GkkMobileApp extends StatefulWidget {
  const GkkMobileApp({super.key});

  @override
  State<GkkMobileApp> createState() => _GkkMobileAppState();
}

class _GkkMobileAppState extends State<GkkMobileApp> {
  late final GoRouter _router;
  late final _RouterRefreshNotifier _routerRefreshNotifier;

  @override
  void initState() {
    super.initState();
    final Stream<dynamic> authRefreshStream = SupabaseService.isInitialized
        ? SupabaseService.client.auth.onAuthStateChange
        : const Stream<dynamic>.empty();
    _routerRefreshNotifier = _RouterRefreshNotifier(authRefreshStream);
    _router = createAppRouter(
      refreshListenable: _routerRefreshNotifier,
    );
  }

  @override
  void dispose() {
    _routerRefreshNotifier.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GKK Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
