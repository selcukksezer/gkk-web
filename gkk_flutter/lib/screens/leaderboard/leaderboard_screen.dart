import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

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
        title: 'Sıralama',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.leaderboard),
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
                const Text('Sıralama', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    for (final String tab in <String>['Seviye', 'Güç', 'Servet', 'Lonca'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(tab), onPressed: () {}, backgroundColor: Colors.white10),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...<Map<String, dynamic>>[
                  {'rank': 1, 'name': 'KahraSword', 'value': 'Lv. 99'},
                  {'rank': 2, 'name': 'DarkMage', 'value': 'Lv. 87'},
                  {'rank': 3, 'name': 'LightArcher', 'value': 'Lv. 82'},
                ].map((row) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.white12,
                        child: Text('${row['rank']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      title: Text(row['name'] as String),
                      trailing: Text(row['value'] as String, style: const TextStyle(color: Colors.amber)),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
