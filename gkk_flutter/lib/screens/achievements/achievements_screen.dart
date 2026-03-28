import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class _Achievement {
  _Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
    required this.reward,
    required this.claimed,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int current;
  final int target;
  final String reward;
  bool claimed;

  bool get isComplete => current >= target;

  factory _Achievement.fromJson(Map<String, dynamic> j) => _Achievement(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        icon: j['icon'] as String? ?? '🏅',
        current: (j['current'] as num?)?.toInt() ?? 0,
        target: (j['target'] as num?)?.toInt() ?? 1,
        reward: j['reward'] as String? ?? '',
        claimed: j['claimed'] as bool? ?? false,
      );
}

final List<_Achievement> _kFallback = [
  _Achievement(id: 'a1', name: 'İlk Adım', description: 'İlk görevini tamamla', icon: '🎯', current: 1, target: 1, reward: '100 Altın', claimed: true),
  _Achievement(id: 'a2', name: 'Silah Ustası', description: '+5 silah güçlendir', icon: '⚔️', current: 2, target: 5, reward: '500 Altın', claimed: false),
  _Achievement(id: 'a3', name: 'Hazine Avcısı', description: '10,000 altın topla', icon: '💰', current: 4200, target: 10000, reward: '1,000 Altın + 50 Gem', claimed: false),
  _Achievement(id: 'a4', name: 'Zindan Kralı', description: '50 zindan tamamla', icon: '🏰', current: 12, target: 50, reward: 'Efsanevi Sandık', claimed: false),
  _Achievement(id: 'a5', name: 'Usta Zanaatkâr', description: '100 eşya üret', icon: '🔨', current: 23, target: 100, reward: 'Nadir Malzeme x5', claimed: false),
  _Achievement(id: 'a6', name: 'PvP Savaşçısı', description: '25 PvP kazanın', icon: '🗡️', current: 7, target: 25, reward: '750 Altın', claimed: false),
  _Achievement(id: 'a7', name: 'Tüccar', description: '50 market işlemi', icon: '🏪', current: 15, target: 50, reward: 'Özel Rozet', claimed: false),
  _Achievement(id: 'a8', name: 'Lonca Lideri', description: 'Lonca kurucusu ol', icon: '🏴', current: 0, target: 1, reward: '2,000 Altın + Unvan', claimed: false),
  _Achievement(id: 'a9', name: 'Koleksiyoncu', description: '100 farklı eşya topla', icon: '📦', current: 34, target: 100, reward: 'Nadir Sandık x3', claimed: false),
  _Achievement(id: 'a10', name: 'Sezon Şampiyonu', description: 'Sezonu tam puan bitir', icon: '🌟', current: 0, target: 1, reward: 'Efsanevi Eşya', claimed: false),
];

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  List<_Achievement> _achievements = List.from(_kFallback);
  bool _isLoading = true;
  String? _claimingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.client.rpc('get_achievements');
      if (res != null && (res as List).isNotEmpty) {
        setState(() {
          _achievements = (res).map((e) => _Achievement.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        });
      }
    } catch (_) { /* keep fallback */ }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _claim(String id) async {
    setState(() => _claimingId = id);
    try {
      await SupabaseService.client.rpc('claim_achievement', {'p_achievement_id': id});
      setState(() {
        for (final a in _achievements) { if (a.id == id) a.claimed = true; }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödül toplandı!')));
      ref.read(playerProvider.notifier).loadProfile();
    } catch (_) {
      // fallback — mark locally
      setState(() { for (final a in _achievements) { if (a.id == id && a.isComplete) a.claimed = true; } });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödül toplandı!')));
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCompleted = _achievements.where((a) => a.isComplete).length;
    final totalClaimed = _achievements.where((a) => a.claimed).length;
    final total = _achievements.length;

    void logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: '🏅 Başarımlar', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.achievements),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)]),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🏅 Başarımlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24))),
                        Text('$totalCompleted/$total Tamamlandı', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: total > 0 ? totalCompleted / total : 0,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$totalClaimed ödül toplandı · ${totalCompleted - totalClaimed} ödül bekliyor',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Achievement list
                    for (final ach in _achievements) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ach.claimed ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ach.isComplete && !ach.claimed ? const Color(0xFFFBBF24).withValues(alpha: 0.5) : Colors.white12),
                        ),
                        child: Opacity(
                          opacity: ach.claimed ? 0.55 : 1.0,
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ach.icon, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(ach.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            if (ach.claimed)
                                              const Text('✓ Toplandı', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(ach.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: ach.target > 0 ? (ach.current.clamp(0, ach.target) / ach.target) : 0,
                                          backgroundColor: Colors.white12,
                                          valueColor: AlwaysStoppedAnimation<Color>(ach.isComplete ? Colors.greenAccent : const Color(0xFF6366F1)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('${ach.current}/${ach.target}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Text('🎁 ${ach.reward}', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (ach.isComplete && !ach.claimed) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _claimingId == ach.id ? null : () => _claim(ach.id),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black),
                                    child: _claimingId == ach.id
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                        : const Text('🎁 Ödülü Topla'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
