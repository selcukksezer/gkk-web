import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

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
        title: 'Başarımlar',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.achievements),
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
                const Text(
                  'Başarımlar',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                ...<Map<String, dynamic>>[
                  {'icon': Icons.sports_kabaddi_rounded, 'title': 'Savaş', 'desc': 'Savaş görevlerini tamamlayarak rozet kazan.'},
                  {'icon': Icons.explore_outlined, 'title': 'Keşif', 'desc': 'Yeni bölgeler keşfederek deneyim topla.'},
                  {'icon': Icons.groups_outlined, 'title': 'Lonca', 'desc': 'Lonca etkinliklerine katılarak ilerleme kaydet.'},
                  {'icon': Icons.handyman_outlined, 'title': 'Üretim', 'desc': 'Eşya üret ve el sanatlarında ustalaş.'},
                ].map((cat) => ListTile(
                      leading: Icon(cat['icon'] as IconData, color: Colors.amber),
                      title: Text(cat['title'] as String),
                      subtitle: Text(cat['desc'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: const Icon(Icons.lock_outline, color: Colors.white38),
                      contentPadding: EdgeInsets.zero,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
