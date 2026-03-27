import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Profile',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.profile),
      body: switch (playerState.status) {
        PlayerStatus.initial || PlayerStatus.loading => const Center(child: CircularProgressIndicator()),
        PlayerStatus.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(playerState.errorMessage ?? 'Profil yuklenemedi.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.read(playerProvider.notifier).loadProfile(),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          ),
        PlayerStatus.ready => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF090D14), Color(0xFF101722), Color(0xFF090D14)],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                _ProfileHeader(profile: profile),
                const SizedBox(height: 10),
                _InfoCard(
                  title: 'Hesap',
                  rows: <(String, String)>[
                    ('Username', profile?.username ?? '-'),
                    ('Email', profile?.email ?? '-'),
                    ('Display Name', (profile?.displayName ?? '-').toString()),
                    ('Kayit Tarihi', (profile?.createdAt ?? '-').toString()),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  title: 'Ekonomi',
                  rows: <(String, String)>[
                    ('Altin', '${profile?.gold ?? 0}'),
                    ('Gem', '${profile?.gems ?? 0}'),
                    ('PVP Rating', '${profile?.pvpRating ?? 0}'),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  title: 'Durum',
                  rows: <(String, String)>[
                    ('Hastane', (profile?.hospitalUntil ?? '-').toString()),
                    ('Hapishane', (profile?.prisonUntil ?? '-').toString()),
                    ('Bagimlilik', '${profile?.addictionLevel ?? 0}'),
                    ('Tolerans', '${profile?.tolerance ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        color: const Color(0xAA111827),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: <Color>[Color(0xFF0EA5E9), Color(0xFF9333EA)]),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (profile?.displayName ?? profile?.username ?? 'Oyuncu').toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Lv.${profile?.level ?? 1}  •  ${profile?.title ?? 'No Title'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: const Color(0xAA111827),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(row.$1, style: const TextStyle(color: Colors.white70))),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
