import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ── Reputation tier helper ──────────────────────────────────────────────────
({String title, Color color}) _getReputationTier(int rep) {
  if (rep >= 100000) return (title: '👑 Efsane', color: Colors.amber);
  if (rep >= 50000) return (title: '🔱 Usta', color: const Color(0xFF8B5CF6));
  if (rep >= 20000) return (title: '⭐ Kahraman', color: const Color(0xFF3B82F6));
  if (rep >= 5000) return (title: '🥈 Ünlü', color: Colors.blueGrey);
  if (rep >= 1000) return (title: '🌱 Tanınan', color: Colors.greenAccent);
  return (title: '🕵️ Bilinmeyen', color: Colors.white38);
}

({int? target, int remaining}) _getNextMilestone(int rep) {
  const milestones = [1000, 5000, 20000, 50000, 100000];
  for (final m in milestones) {
    if (rep < m) return (target: m, remaining: m - rep);
  }
  return (target: null, remaining: 0);
}

int _getReputationPower(int rep) => (rep * 0.01).round();

String _timeAgo(String? iso) {
  if (iso == null) return '-';
  try {
    final dt = DateTime.parse(iso);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} yıl önce';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} ay önce';
    if (diff.inDays > 0) return '${diff.inDays} gün önce';
    if (diff.inHours > 0) return '${diff.inHours} saat önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes} dk önce';
    return 'az önce';
  } catch (_) { return iso; }
}

String _fmtCompact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

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

    void logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: '👤 Profil', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.profile),
      body: switch (playerState.status) {
        PlayerStatus.initial || PlayerStatus.loading => const Center(child: CircularProgressIndicator()),
        PlayerStatus.error => Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(playerState.errorMessage ?? 'Profil yüklenemedi.', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => ref.read(playerProvider.notifier).loadProfile(), child: const Text('Tekrar Dene')),
            ]),
          )),
        PlayerStatus.ready => _buildBody(context, profile),
      },
    );
  }

  Widget _buildBody(BuildContext context, dynamic profile) {
    final level = (profile?.level ?? 1) as int;
    final xp = (profile?.xp ?? 0) as int;
    final xpForNext = (1000 * (level as num).pow(1.5)).round();
    final gold = (profile?.gold ?? 0) as int;
    final gems = (profile?.gems ?? 0) as int;
    final energy = (profile?.energy ?? 0) as int;
    final maxEnergy = (profile?.maxEnergy ?? 100) as int;
    final pvpWins = (profile?.pvpWins ?? 0) as int;
    final pvpLosses = (profile?.pvpLosses ?? 0) as int;
    final pvpRating = (profile?.pvpRating ?? 0) as int;
    final tolerance = (profile?.tolerance ?? 0) as int;
    final reputation = (profile?.reputation ?? 0) as int;
    final intelligence = (profile?.intelligence ?? 0) as int;

    // Computed stats (mirrors web formula)
    final attack = 5 + level * 2;
    final defense = 3 + level;
    final hp = 100 + level * 10;
    final luck = 5 + (level * 0.5).floor();
    final power = (attack + defense + hp + luck + reputation * 0.01).round();

    final winRate = pvpWins + pvpLosses > 0 ? ((pvpWins / (pvpWins + pvpLosses)) * 100).round() : 0;
    final xpPct = xpForNext > 0 ? (xp / xpForNext).clamp(0.0, 1.0) : 0.0;

    final repTier = _getReputationTier(reputation as int);
    final nextMilestone = _getNextMilestone(reputation);
    final repPower = _getReputationPower(reputation);

    final charClass = profile?.characterClass?.name ?? '';
    final classLabel = charClass == 'warrior' ? '🗡️ Savaşçı' : charClass == 'alchemist' ? '⚗️ Simyacı' : charClass == 'shadow' ? '🌑 Gölge' : '❓ Seçilmedi';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF090D14), Color(0xFF101722), Color(0xFF090D14)]),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Header
          _card(
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF9333EA)])),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((profile?.displayName ?? profile?.username ?? 'Oyuncu').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Seviye $level  •  ${profile?.title ?? repTier.title}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(profile?.guildName ?? 'Lonca yok', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 10),

          // Temel bilgiler
          _card(
            title: '📋 Temel Bilgiler',
            child: Column(children: [
              _infoRow('İsim', (profile?.displayName ?? profile?.username ?? '—').toString()),
              _infoRow('Seviye', '$level'),
              _infoRow('Sınıf', classLabel),
              _infoRow('Lonca', profile?.guildName ?? 'Yok'),
              _infoRow('Unvan', repTier.title),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Deneyim', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('${_fmtCompact(xp)} / ${_fmtCompact(xpForNext)}', style: const TextStyle(fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: xpPct, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)), minHeight: 6, borderRadius: BorderRadius.circular(3)),
            ]),
          ),
          const SizedBox(height: 10),

          // İstatistikler
          _card(
            title: '📊 İstatistikler',
            child: Wrap(
              children: [
                _statCell('Güç', _fmtCompact(power)),
                _statCell('Dayanıklılık', '$defense'),
                _statCell('Çeviklik', '$attack'),
                _statCell('Zeka', '$intelligence'),
                _statCell('Şans', '$luck'),
                _statCell('HP', '$hp'),
                _statCell('Enerji', '$energy/$maxEnergy'),
                _statCell('Güç (Sev.)', _fmtCompact(level * 15)),
                _statCell('Güç (Rep.)', '+${_fmtCompact(repPower)}'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Servet
          _card(
            title: '💰 Servet',
            child: Wrap(
              children: [
                _statCell('🪙 Altın', _fmtCompact(gold), valueColor: const Color(0xFFFBBF24)),
                _statCell('💎 Gem', _fmtCompact(gems), valueColor: const Color(0xFF8B5CF6)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // PvP
          _card(
            title: '⚔️ PvP İstatistikleri',
            child: Wrap(
              children: [
                _statCell('Rating', '$pvpRating'),
                _statCell('Galibiyet', '$pvpWins'),
                _statCell('Mağlubiyet', '$pvpLosses'),
                _statCell('Kazanma Oranı', '%$winRate'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // İtibar
          _card(
            title: '⭐ İtibar',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(repTier.title, style: TextStyle(fontWeight: FontWeight.bold, color: repTier.color, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Puan: ${_fmtCompact(reputation)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text('Power katkısı: +${_fmtCompact(repPower)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              if (nextMilestone.target != null) ...[
                const SizedBox(height: 4),
                Text('Sonraki unvan: ${_fmtCompact(nextMilestone.target!)} (kalan ${_fmtCompact(nextMilestone.remaining)})', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: nextMilestone.target! > 0 ? (reputation / nextMilestone.target!).clamp(0.0, 1.0) : 0,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(repTier.color),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ] else
                const Text('Maksimum unvandasın', style: TextStyle(color: Colors.amber, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 10),

          // Aktivite
          _card(
            title: '📅 Aktivite',
            child: Column(children: [
              _infoRow('Kayıt', _timeAgo(profile?.createdAt?.toString())),
              _infoRow('Son Giriş', _timeAgo(profile?.lastLogin?.toString())),
              _infoRow('Tolerans', '%$tolerance'),
            ]),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _card({String? title, required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
      color: const Color(0xAA111827),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) ...[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 10),
      ],
      child,
    ]),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    ]),
  );

  Widget _statCell(String label, String value, {Color? valueColor}) => SizedBox(
    width: 100,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor ?? Colors.white)),
      ]),
    ),
  );
}

extension NumPow on num {
  num pow(num exp) {
    double result = 1.0;
    double base = toDouble();
    double exponent = exp.toDouble();
    // integer part
    int intPart = exponent.floor();
    for (int i = 0; i < intPart; i++) { result *= base; }
    // fractional part approximation
    double frac = exponent - intPart;
    if (frac > 0) { result *= (1 + frac * (base - 1)); }
    return result;
  }
}
