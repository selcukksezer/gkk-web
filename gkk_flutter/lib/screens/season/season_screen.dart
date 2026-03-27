import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class SeasonScreen extends ConsumerWidget {
  const SeasonScreen({super.key});

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
        title: 'Mevsim',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.season),
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
                const Text('Mevsim', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Sezon 1 — Karanlık Kış', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 14),
                const Text('Sezon Geçişi İlerlemesi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(value: 0.25, minHeight: 10, backgroundColor: Colors.white12),
                ),
                const Text('Seviye 5 / 20', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 14),
                const Text('Tier Ödülleri', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final Map<String, String> tier in <Map<String, String>>[
                  {'tier': '5', 'reward': '500 Altın'},
                  {'tier': '10', 'reward': 'Nadir Silah Sandığı'},
                  {'tier': '20', 'reward': 'Efsanevi Kostüm'},
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.card_giftcard_outlined, color: Colors.amber),
                    title: Text('Seviye ${tier['tier']}'),
                    trailing: Text(tier['reward']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
                    child: const Text('Geçişi Aç (Premium)', style: TextStyle(color: Colors.black)),
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
