import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class PrisonScreen extends ConsumerWidget {
  const PrisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProvider).profile;

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Hapishane',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.prison),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Center(
          child: Container(
            width: 420,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              color: Colors.black26,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Hapishane', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                const Icon(Icons.gavel_rounded, size: 48, color: Colors.white38),
                const SizedBox(height: 10),
                const Text('Durum: Serbest', style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  profile != null ? 'Cezaevinde değilsin.' : 'Bilgi yükleniyor...',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Kefalet: 200 Altın'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
