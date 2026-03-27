import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

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
        title: 'Mağaza',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.shop),
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
                const Text('Mağaza', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final String tab in <String>['Öne Çıkan', 'Paketler', 'Altın', 'Elmas'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(label: Text(tab), onPressed: () {}, backgroundColor: Colors.white10),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: <Map<String, String>>[
                    {'name': 'Başlangıç Paketi', 'price': '99 Elmas'},
                    {'name': 'XP Artışı', 'price': '500 Altın'},
                    {'name': 'Nadir Sandık', 'price': '250 Elmas'},
                    {'name': 'Enerji Dolumu', 'price': '100 Altın'},
                  ].map((item) => Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white10, border: Border.all(color: Colors.white12)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.shopping_bag_outlined, size: 28, color: Colors.white54),
                            const SizedBox(height: 6),
                            Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text(item['price']!, style: const TextStyle(color: Colors.amber, fontSize: 11)),
                          ],
                        ),
                      )).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
