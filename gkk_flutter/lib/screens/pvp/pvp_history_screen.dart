import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class PvpHistoryScreen extends ConsumerWidget {
  const PvpHistoryScreen({super.key});

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
        title: 'PvP Geçmişi',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.pvpHistory),
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
                const Text('PvP Geçmişi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                ...<Map<String, dynamic>>[
                  {'result': 'Zafer', 'opponent': 'DarkMage', 'delta': '+15', 'win': true},
                  {'result': 'Yenilgi', 'opponent': 'KahraSword', 'delta': '-12', 'win': false},
                ].map((match) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        match['win'] as bool ? Icons.emoji_events_outlined : Icons.close_rounded,
                        color: match['win'] as bool ? Colors.greenAccent : Colors.redAccent,
                      ),
                      title: Text('vs ${match['opponent']}'),
                      subtitle: Text(match['result'] as String, style: TextStyle(color: match['win'] as bool ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                      trailing: Text(match['delta'] as String, style: TextStyle(color: match['win'] as bool ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w700)),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
