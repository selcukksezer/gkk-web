import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';

class CharacterSelectScreen extends ConsumerWidget {
  const CharacterSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karakter Seç'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                const Text('Karakter Seç', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Oyuna başlamak için bir sınıf seç.', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: <Map<String, dynamic>>[
                    {'name': 'Savaşçı', 'icon': Icons.shield_outlined, 'desc': 'Yüksek savunma ve güç.'},
                    {'name': 'Büyücü', 'icon': Icons.auto_fix_high_outlined, 'desc': 'Güçlü sihir saldırıları.'},
                    {'name': 'Okçu', 'icon': Icons.gps_fixed_outlined, 'desc': 'Uzak mesafe uzmanı.'},
                    {'name': 'Rahip', 'icon': Icons.healing_outlined, 'desc': 'İyileştirme ve destek.'},
                  ].map((cls) {
                    return GestureDetector(
                      onTap: () => context.go(AppRoutes.home),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                          color: Colors.white10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(cls['icon'] as IconData, size: 32, color: Colors.white70),
                            const SizedBox(height: 6),
                            Text(cls['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(cls['desc'] as String, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            const Text('Seç', style: TextStyle(color: Color(0xFF5296FF), fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
