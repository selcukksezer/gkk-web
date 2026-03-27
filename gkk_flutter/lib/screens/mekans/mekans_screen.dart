import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class MekansScreen extends ConsumerWidget {
  const MekansScreen({super.key});

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
        title: 'Mekanlar',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.mekans),
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
                const Text('Mekanlar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Mekan ara...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
                const SizedBox(height: 12),
                ...<Map<String, String>>[
                  {'name': 'Altın Kupa Tavernası', 'type': 'Taverna', 'players': '12 oyuncu'},
                  {'name': 'Demir Kalkan Dükkanı', 'type': 'Dükkan', 'players': '5 oyuncu'},
                  {'name': 'Kızıl Arena', 'type': 'Arena', 'players': '28 oyuncu'},
                ].map((m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_city_outlined, color: Colors.white54),
                      title: Text(m['name']!),
                      subtitle: Text('${m['type']} · ${m['players']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      onTap: () => context.go('${AppRoutes.mekans}/sample-id'),
                    )),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => context.go(AppRoutes.mekanCreate),
                    child: const Text('Mekan Oluştur'),
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
