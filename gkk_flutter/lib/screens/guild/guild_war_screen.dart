import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class GuildWarScreen extends ConsumerWidget {
  const GuildWarScreen({super.key});

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
        title: 'Lonca Savaşı',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.guildWar),
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
                const Text('Lonca Savaşı', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                const Text('Savaş Durumu: Bekleniyor', style: TextStyle(color: Colors.amber)),
                const SizedBox(height: 10),
                const Text('Rakip Lonca: —', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Text('Skor: ', style: TextStyle(color: Colors.white54)),
                    const Text('0', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700)),
                    const Text(' vs ', style: TextStyle(color: Colors.white38)),
                    const Text('0', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Savaşa Katıl'),
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
