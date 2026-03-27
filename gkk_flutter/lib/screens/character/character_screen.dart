import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({super.key});

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
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
        title: 'Character',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.character),
      body: switch (playerState.status) {
        PlayerStatus.initial || PlayerStatus.loading => const Center(child: CircularProgressIndicator()),
        PlayerStatus.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(playerState.errorMessage ?? 'Karakter bilgisi yuklenemedi.'),
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
                _HeroCard(profile: profile),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Temel Ozellikler',
                  children: <Widget>[
                    _StatRow(label: 'Sinif', value: (profile?.characterClass?.name ?? 'warrior').toUpperCase()),
                    _StatRow(label: 'Seviye', value: '${profile?.level ?? 1}'),
                    _StatRow(label: 'XP', value: '${profile?.xp ?? 0}'),
                    _StatRow(label: 'Guc', value: '${profile?.power ?? 0}'),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Savas Istatistikleri',
                  children: <Widget>[
                    _StatRow(label: 'Saldiri', value: '${profile?.attack ?? 0}'),
                    _StatRow(label: 'Savunma', value: '${profile?.defense ?? 0}'),
                    _StatRow(label: 'Can', value: '${profile?.health ?? 0}/${profile?.maxHealth ?? 0}'),
                    _StatRow(label: 'Enerji', value: '${profile?.energy ?? 0}/${profile?.maxEnergy ?? 0}'),
                    _StatRow(label: 'Sans', value: '${profile?.luck ?? 0}'),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'PVP Performansi',
                  children: <Widget>[
                    _StatRow(label: 'Rating', value: '${profile?.pvpRating ?? 0}'),
                    _StatRow(label: 'Galibiyet', value: '${profile?.pvpWins ?? 0}'),
                    _StatRow(label: 'Maglubiyet', value: '${profile?.pvpLosses ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile});

  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final String displayName = profile == null
        ? 'Oyuncu'
        : ((profile.displayName ?? profile.username).toString().trim().isEmpty
            ? profile.username as String
            : (profile.displayName ?? profile.username) as String);

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
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: <Color>[Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
            ),
            alignment: Alignment.center,
            child: Text(
              '${profile?.level ?? 1}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  'Reputation: ${profile?.reputation ?? 0}  |  Guild: ${profile?.guildName ?? '-'}',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

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
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
