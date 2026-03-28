import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../core/services/supabase_service.dart';

class SeasonScreen extends ConsumerStatefulWidget {
  const SeasonScreen({super.key});

  @override
  ConsumerState<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends ConsumerState<SeasonScreen> {
  bool _loading = true;
  int _subTab = 0;
  Map<String, dynamic> _seasonData = {
    'season_name': 'Gölge Sezonu',
    'season_number': 1,
    'ends_at': null,
    'battle_pass_level': 1,
    'battle_pass_xp': 0,
    'battle_pass_xp_required': 1000,
    'is_premium': false,
    'daily_quests_completed': 0,
    'weekly_quests_completed': 0,
  };
  List<Map<String, dynamic>> _rewards = [];
  Set<String> _claimingRewards = {};

  static const Map<int, String> _freeRewards = {
    1: '🪙 200 Altın',
    2: '⚡ +10 Enerji',
    3: '📦 Küçük Sandık',
    4: '🪙 500 Altın',
    5: '🌿 Şifalı Bitki x10',
    6: '📦 Orta Sandık',
    7: '🪙 1.000 Altın',
    8: '⚡ +20 Enerji',
    9: '📦 Büyük Sandık',
    10: '🏆 Sezon Rozeti',
  };

  static const Map<int, String> _premiumRewards = {
    1: '💎 5 Gem + 🪙 500 Altın',
    2: '🔮 Nadir Sandık',
    3: '💎 10 Gem + ⚡ +30 Enerji',
    4: '🎭 Özel Kostüm Parçası',
    5: '💎 15 Gem + 📦 Destansı Sandık',
    6: '🗡️ Nadir Silah Sandığı',
    7: '💎 20 Gem + 🪙 5.000 Altın',
    8: '✨ Efsanevi Sandık',
    9: '💎 30 Gem + 🎭 Özel Çerçeve',
    10: '🌟 Efsanevi Kostüm + 💎 50 Gem',
  };

  static const int _seasonTiers = 10;

  static final List<Map<String, dynamic>> _leaderboard = [
    {'rank': 1, 'username': 'KaanWarrior', 'season_xp': 48500, 'tier': 10, 'is_premium': true},
    {'rank': 2, 'username': 'ElfHunter', 'season_xp': 43200, 'tier': 9, 'is_premium': true},
    {'rank': 3, 'username': 'SilverArrow', 'season_xp': 38100, 'tier': 8, 'is_premium': false},
    {'rank': 4, 'username': 'DarkMage', 'season_xp': 31500, 'tier': 7, 'is_premium': true},
    {'rank': 5, 'username': 'IronFist', 'season_xp': 27800, 'tier': 6, 'is_premium': false},
  ];

  static final List<Map<String, dynamic>> _fallbackChallenges = [
    {
      'id': 'daily_1',
      'type': 'daily',
      'name': 'Zindan Fatihliği',
      'description': 'Bugün 3 zindana gir',
      'current': 1,
      'target': 3,
      'xp_reward': 150,
      'gold_reward': 200,
      'completed': false,
      'claimed': false,
    },
    {
      'id': 'daily_2',
      'type': 'daily',
      'name': 'Tüccar Ruhu',
      'description': 'Pazarda 5 işlem yap',
      'current': 3,
      'target': 5,
      'xp_reward': 100,
      'gold_reward': 150,
      'completed': false,
      'claimed': false,
    },
    {
      'id': 'weekly_1',
      'type': 'weekly',
      'name': 'Haftalık Kahraman',
      'description': 'Bu hafta 20 zindan kazan',
      'current': 12,
      'target': 20,
      'xp_reward': 500,
      'gold_reward': 1000,
      'completed': false,
      'claimed': false,
    },
    {
      'id': 'weekly_2',
      'type': 'weekly',
      'name': 'Zanaat Ustası',
      'description': '10 eşya üret',
      'current': 10,
      'target': 10,
      'xp_reward': 400,
      'gold_reward': 800,
      'completed': true,
      'claimed': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    try {
      final seasonRaw = await SupabaseService.client.rpc('get_season_data');
      if (seasonRaw is Map) {
        setState(() {
          _seasonData = {
            'season_name': seasonRaw['season_name'] ?? _seasonData['season_name'],
            'season_number': seasonRaw['season_number'] ?? _seasonData['season_number'],
            'ends_at': seasonRaw['ends_at'],
            'battle_pass_level':
                seasonRaw['battle_pass_level'] ?? _seasonData['battle_pass_level'],
            'battle_pass_xp': seasonRaw['battle_pass_xp'] ?? _seasonData['battle_pass_xp'],
            'battle_pass_xp_required':
                seasonRaw['battle_pass_xp_required'] ?? _seasonData['battle_pass_xp_required'],
            'is_premium': seasonRaw['is_premium'] ?? _seasonData['is_premium'],
            'daily_quests_completed':
                seasonRaw['daily_quests_completed'] ?? _seasonData['daily_quests_completed'],
            'weekly_quests_completed':
                seasonRaw['weekly_quests_completed'] ?? _seasonData['weekly_quests_completed'],
          };
        });
      }
      final rewardsRaw = await SupabaseService.client.rpc('get_battle_pass_rewards');
      if (rewardsRaw is List) {
        setState(() =>
            _rewards = rewardsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {
      // keep fallback data
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _countdownText() {
    final endsAt = _seasonData['ends_at'];
    if (endsAt == null) return '45 gün kaldı';
    try {
      final endDate = DateTime.parse(endsAt as String);
      final diff = endDate.difference(DateTime.now());
      if (diff.isNegative) return 'Sezon sona erdi';
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      return '$days gün $hours saat';
    } catch (_) {
      return '45 gün kaldı';
    }
  }

  Future<void> _claimReward(int level, bool isPremium) async {
    final key = '${isPremium ? 'prem' : 'free'}_$level';
    if (_claimingRewards.contains(key)) return;
    setState(() => _claimingRewards.add(key));
    try {
      await SupabaseService.client.rpc('claim_battle_pass_reward',
          params: {'p_reward_level': level, 'p_is_premium': isPremium});
      if (!mounted) return;
      final reward = isPremium ? _premiumRewards[level] : _freeRewards[level];
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tier $level ödülü alındı: $reward')));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
    if (!mounted) return;
    setState(() => _claimingRewards.remove(key));
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'uncommon':
        return const Color(0xFF22C55E);
      case 'rare':
        return const Color(0xFF3B82F6);
      case 'epic':
        return const Color(0xFFA855F7);
      case 'legendary':
        return const Color(0xFFF59E0B);
      case 'mythic':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoutHandler = () async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    };

    return Scaffold(
      drawer: GameDrawer(onLogout: logoutHandler),
      appBar: GameTopBar(title: '🌟 Mevsim', onLogout: logoutHandler),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.season),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10131D), Color(0xFF171E2C)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isPremium = (_seasonData['is_premium'] as bool?) ?? false;
    final currentLevel = (_seasonData['battle_pass_level'] as int?) ?? 1;
    final bpXp = (_seasonData['battle_pass_xp'] as num?)?.toDouble() ?? 0;
    final bpXpReq = (_seasonData['battle_pass_xp_required'] as num?)?.toDouble() ?? 1000;
    final progressVal = (bpXpReq > 0 ? bpXp / bpXpReq : 0.0).clamp(0.0, 1.0);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_seasonData['season_name'] as String? ?? '',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Sezon ${_seasonData['season_number']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text('⏰ ${_countdownText()}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
            const Spacer(),
            if (isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                ),
                child: const Text('⭐ Premium',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
              )
            else
              ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bu özellik yakında aktif olacak'))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('⭐ Premium Al'),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Savaş Geçişi',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            Text(
              'Seviye $currentLevel • ${bpXp.toInt()} / ${bpXpReq.toInt()} XP',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progressVal,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text('Günlük: ${_seasonData['daily_quests_completed']} görev',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(width: 12),
            Text('Haftalık: ${_seasonData['weekly_quests_completed']} görev',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        _buildSubTab(0, '🎫 Geçiş'),
        const SizedBox(width: 6),
        _buildSubTab(1, '🎯 Görevler'),
        const SizedBox(width: 6),
        _buildSubTab(2, '🏆 Sıralama'),
      ]),
      const SizedBox(height: 16),
      if (_subTab == 0) _buildPassTab(currentLevel, isPremium),
      if (_subTab == 1) _buildChallengesTab(),
      if (_subTab == 2) _buildLeaderboardTab(),
    ]);
  }

  Widget _buildSubTab(int index, String label) {
    final active = _subTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _subTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? const Color(0xFF3B82F6) : Colors.white.withValues(alpha: 0.08),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassTab(int currentLevel, bool isPremium) {
    return Column(
      children: List.generate(_seasonTiers, (idx) {
        final tier = idx + 1;
        final unlocked = tier <= currentLevel;
        final freeClaimed = _rewards.any(
            (r) => r['level'] == tier && r['is_premium'] == false && r['is_claimed'] == true);
        final premClaimed = _rewards.any(
            (r) => r['level'] == tier && r['is_premium'] == true && r['is_claimed'] == true);
        final freeKey = 'free_$tier';
        final premKey = 'prem_$tier';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: unlocked ? const Color(0xFF3B82F6) : Colors.white12,
                ),
                alignment: Alignment.center,
                child: Text(
                  unlocked ? '✓' : '$tier',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text('Tier $tier', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (!unlocked)
                Text(' (${(tier - currentLevel) * 1000} XP kaldı)',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: freeClaimed
                          ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                          : unlocked
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                              : Colors.white12,
                    ),
                    color: freeClaimed
                        ? const Color(0xFF22C55E).withValues(alpha: 0.05)
                        : unlocked
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.02),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🆓 Ücretsiz',
                        style: TextStyle(color: Colors.white38, fontSize: 9)),
                    const SizedBox(height: 4),
                    Text(_freeRewards[tier] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if (freeClaimed)
                      const Text('✓ Alındı',
                          style: TextStyle(color: Color(0xFF22C55E), fontSize: 10))
                    else if (unlocked)
                      SizedBox(
                        width: double.infinity,
                        child: _claimingRewards.contains(freeKey)
                            ? const Center(
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2)))
                            : ElevatedButton(
                                onPressed: () => _claimReward(tier, false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(fontSize: 10),
                                ),
                                child: const Text('Al'),
                              ),
                      )
                    else
                      const Text('🔒 Kilitli',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: premClaimed
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                          : (unlocked && isPremium)
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                              : Colors.white12,
                    ),
                    color: premClaimed
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.05)
                        : (unlocked && isPremium)
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.02),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('⭐ Premium',
                        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9)),
                    const SizedBox(height: 4),
                    Text(_premiumRewards[tier] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if (premClaimed)
                      const Text('✓ Alındı',
                          style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10))
                    else if (!isPremium)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Bu özellik yakında aktif olacak'))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            foregroundColor: const Color(0xFFF59E0B),
                            padding:
                                const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 10),
                          ),
                          child: const Text('🔒 Premium Al'),
                        ),
                      )
                    else if (unlocked)
                      SizedBox(
                        width: double.infinity,
                        child: _claimingRewards.contains(premKey)
                            ? const Center(
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2)))
                            : ElevatedButton(
                                onPressed: () => _claimReward(tier, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                child: const Text('Al'),
                              ),
                      )
                    else
                      const Text('🔒 Kilitli',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ]),
                ),
              ),
            ]),
          ]),
        );
      }),
    );
  }

  Widget _buildChallengesTab() {
    final daily = _fallbackChallenges.where((c) => c['type'] == 'daily').toList();
    final weekly = _fallbackChallenges.where((c) => c['type'] == 'weekly').toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📅 Günlük Görevler',
          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...daily.map((c) => _buildChallengeCard(c)),
      const SizedBox(height: 12),
      const Text('📆 Haftalık Görevler',
          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...weekly.map((c) => _buildChallengeCard(c)),
    ]);
  }

  Widget _buildChallengeCard(Map<String, dynamic> c) {
    final current = (c['current'] as int?) ?? 0;
    final target = (c['target'] as int?) ?? 1;
    final completed = (c['completed'] as bool?) ?? false;
    final claimed = (c['claimed'] as bool?) ?? false;
    final progress = (target > 0 ? current / target : 0.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(c['name'] as String? ?? '',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          if (claimed)
            const Text('✓ Alındı', style: TextStyle(color: Color(0xFF22C55E), fontSize: 11))
          else if (completed)
            ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('${c['name']} ödülü alındı!'))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Al'),
            ),
        ]),
        const SizedBox(height: 4),
        Text(c['description'] as String? ?? '',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                    completed ? const Color(0xFF22C55E) : const Color(0xFF3B82F6)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$current / $target',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('🪙 ${c['gold_reward']} Altın',
              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10)),
          const SizedBox(width: 8),
          Text('✨ ${c['xp_reward']} XP',
              style: const TextStyle(color: Color(0xFF22C55E), fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _buildLeaderboardTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Bu sezonun en yüksek XP'sine sahip oyuncuları",
          style: TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 8),
      ..._leaderboard.map((entry) {
        final rank = entry['rank'] as int;
        final isPremium = (entry['is_premium'] as bool?) ?? false;
        String medal;
        Color medalColor;
        switch (rank) {
          case 1:
            medal = '🥇';
            medalColor = const Color(0xFFFFD700);
            break;
          case 2:
            medal = '🥈';
            medalColor = const Color(0xFFC0C0C0);
            break;
          case 3:
            medal = '🥉';
            medalColor = const Color(0xFFCD7F32);
            break;
          default:
            medal = '#$rank';
            medalColor = Colors.white54;
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(children: [
            SizedBox(
              width: 36,
              child: Text(medal,
                  style: TextStyle(fontSize: rank <= 3 ? 20 : 14, color: medalColor),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(entry['username'] as String? ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  if (isPremium) ...[
                    const SizedBox(width: 4),
                    const Text('⭐',
                        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                  ],
                ]),
                Text('Tier ${entry['tier']} • ${entry['season_xp']} XP',
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
            ),
            if (rank == 1) const Text('👑', style: TextStyle(fontSize: 20)),
          ]),
        );
      }),
    ]);
  }
}
