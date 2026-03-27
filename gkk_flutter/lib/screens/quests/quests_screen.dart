import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

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
        title: 'Görevler',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.quests),
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
                const Text('Görevler', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    for (final String tab in <String>['Günlük', 'Haftalık', 'Ana', 'Yan'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(tab), onPressed: () {}, backgroundColor: Colors.white10),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _QuestItem(name: '10 Düşman Öldür', progress: 0.4, reward: '200 XP'),
                const SizedBox(height: 8),
                _QuestItem(name: 'Markette Alışveriş Yap', progress: 0.0, reward: '50 Altın'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestItem extends StatelessWidget {
  const _QuestItem({required this.name, required this.progress, required this.reward});
  final String name;
  final double progress;
  final String reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white12),
          ),
          const SizedBox(height: 4),
          Text('Ödül: $reward', style: const TextStyle(color: Colors.amber, fontSize: 11)),
        ],
      ),
    );
  }
}
