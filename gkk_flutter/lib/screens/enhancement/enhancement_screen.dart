import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class EnhancementScreen extends ConsumerWidget {
  const EnhancementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Güçlendirme',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.enhancement),
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
                const Text('Güçlendirme', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white10,
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.inventory_2_outlined, color: Colors.white38),
                      SizedBox(width: 10),
                      Text('Eşya seç...', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text('+0', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF5296FF))),
                ),
                const Center(
                  child: Text('Güçlendirme Seviyesi', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                const SizedBox(height: 16),
                const Text('Maliyet: 500 Altın', style: TextStyle(color: Color(0xFFDDB200))),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5296FF)),
                    child: const Text('Güçlendir'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
