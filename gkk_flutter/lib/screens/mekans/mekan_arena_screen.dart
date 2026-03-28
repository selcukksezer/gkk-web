import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class _ArenaOpponent {
  const _ArenaOpponent({required this.authId, required this.username, required this.level, required this.pvpRating});
  final String authId;
  final String username;
  final int level;
  final int pvpRating;

  factory _ArenaOpponent.fromJson(Map<String, dynamic> j) => _ArenaOpponent(
        authId: j['auth_id'] as String? ?? '',
        username: j['username'] as String? ?? '?',
        level: (j['level'] as num?)?.toInt() ?? 0,
        pvpRating: (j['pvp_rating'] as num?)?.toInt() ?? 0,
      );
}

class _ArenaMatch {
  const _ArenaMatch({required this.id, required this.goldStolen, required this.isCritical, required this.createdAt});
  final String id;
  final int goldStolen;
  final bool isCritical;
  final String createdAt;

  factory _ArenaMatch.fromJson(Map<String, dynamic> j) => _ArenaMatch(
        id: j['id'] as String? ?? '',
        goldStolen: (j['gold_stolen'] as num?)?.toInt() ?? 0,
        isCritical: j['is_critical_success'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
      );
}

class _BattleResult {
  const _BattleResult({required this.won, required this.goldStolen, required this.ratingChange, required this.isCritical});
  final bool won;
  final int goldStolen;
  final int ratingChange;
  final bool isCritical;
}

class MekanArenaScreen extends ConsumerStatefulWidget {
  const MekanArenaScreen({super.key, required this.mekanId});
  final String mekanId;

  @override
  ConsumerState<MekanArenaScreen> createState() => _MekanArenaScreenState();
}

class _MekanArenaScreenState extends ConsumerState<MekanArenaScreen> {
  List<_ArenaOpponent> _opponents = [];
  List<_ArenaMatch> _matches = [];
  bool _loading = true;
  String? _attackingId;
  _BattleResult? _battleResult;

  static const int _energyCost = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = ref.read(playerProvider).profile;
    final myAuthId = profile?.authId ?? '';
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.client
            .from('pvp_matches')
            .select('id, winner_id, gold_stolen, is_critical_success, created_at')
            .eq('mekan_id', widget.mekanId)
            .order('created_at', ascending: false)
            .limit(8),
        SupabaseService.client
            .from('users')
            .select('auth_id, username, level, pvp_rating')
            .neq('auth_id', myAuthId.isEmpty ? 'x' : myAuthId)
            .gte('level', 1)
            .isFilter('hospital_until', null)
            .isFilter('prison_until', null)
            .order('pvp_rating', ascending: false)
            .limit(10),
      ]);
      if (mounted) {
        setState(() {
          _matches = (results[0] as List).map((e) => _ArenaMatch.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          _opponents = (results[1] as List).map((e) => _ArenaOpponent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _attack(String opponentId) async {
    final profile = ref.read(playerProvider).profile;
    final energy = profile?.energy ?? 0;
    if (energy < _energyCost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yetersiz enerji! ($_energyCost gerekli)')));
      return;
    }
    setState(() => _attackingId = opponentId);
    try {
      final data = await SupabaseService.client.rpc('pvp_attack', {
        'p_attacker_id': profile?.authId,
        'p_defender_id': opponentId,
        'p_mekan_id': widget.mekanId,
      }) as Map;

      final result = Map<String, dynamic>.from(data);
      final won = result['winner_id'] == profile?.authId;
      final goldStolen = (result['gold_stolen'] as num?)?.toInt() ?? 0;
      final ratingChange = (result['rating_change_attacker'] as num?)?.toInt() ?? 0;
      final isCritical = result['is_critical_success'] as bool? ?? false;

      if (mounted) {
        setState(() { _battleResult = _BattleResult(won: won, goldStolen: goldStolen, ratingChange: ratingChange, isCritical: isCritical); });
        ref.read(playerProvider.notifier).loadProfile();
        await _load();
      }

      if (won) {
        if (isCritical) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('💥 KRİTİK ZAFER! +$goldStolen altın')));
        else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zafer! +$goldStolen altın, +$ratingChange rating')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yenilgi! $ratingChange rating')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saldırı başarısız — sunucu hatası')));
    } finally {
      if (mounted) setState(() => _attackingId = null);
    }
  }

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inMinutes < 1) return 'az önce';
      if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
      if (diff.inDays < 1) return '${diff.inHours}sa önce';
      return '${diff.inDays}g önce';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final energy = profile?.energy ?? 0;

    void logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: '⚔️ PvP Arena', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.mekans),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)]),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header
                    const Text('⚔️ PvP Arena', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 4),
                    Text('Rakip seç ve saldır. Enerji: $energy / $_energyCost gerekli.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 16),

                    // Battle result banner
                    if (_battleResult != null) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _battleResult!.won ? (_battleResult!.isCritical ? Colors.amber.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.15)) : Colors.red.withValues(alpha: 0.15),
                          border: Border.all(color: _battleResult!.won ? (_battleResult!.isCritical ? Colors.amber : Colors.green) : Colors.red, width: 2),
                        ),
                        child: Column(
                          children: [
                            if (_battleResult!.isCritical && _battleResult!.won) const Text('💥', style: TextStyle(fontSize: 40)),
                            Text(
                              _battleResult!.won ? (_battleResult!.isCritical ? '💥 ŞAHLANMA! EZİCİ ZAFER!' : '🏆 ZAFER!') : '💀 YENİLGİ!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _battleResult!.won ? (_battleResult!.isCritical ? Colors.amber : Colors.greenAccent) : Colors.redAccent),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _battleResult!.won
                                  ? '+${_battleResult!.goldStolen} altın kazandın · Rating: +${_battleResult!.ratingChange}'
                                  : '${_battleResult!.goldStolen} altın kaybettin · Rating: ${_battleResult!.ratingChange}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            TextButton(onPressed: () => setState(() => _battleResult = null), child: const Text('Kapat', style: TextStyle(color: Colors.white38, fontSize: 11))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Quick nav
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => context.go(AppRoutes.pvpHistory), child: const Text('Maç Geçmişi'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(onPressed: () => context.go(AppRoutes.pvpTournament), child: const Text('Turnuva'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(onPressed: () => context.go('${AppRoutes.mekans}/${widget.mekanId}'), child: const Text('Mekana Dön'))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Opponents
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rakipler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24))),
                          const SizedBox(height: 12),
                          if (_opponents.isEmpty)
                            const Text('Şu an saldırılabilecek rakip yok.', style: TextStyle(color: Colors.white54, fontSize: 13))
                          else
                            for (final opp in _opponents) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(opp.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text('Sev. ${opp.level} · Rating ${opp.pvpRating}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: energy < _energyCost || _attackingId != null ? null : () => _attack(opp.authId),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                                      child: _attackingId == opp.authId
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Text('Saldır', style: TextStyle(fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Recent matches
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Son Arena Maçları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 12),
                          if (_matches.isEmpty)
                            const Text('Bu mekanda henüz kayıtlı PvP maçı yok.', style: TextStyle(color: Colors.white54, fontSize: 13))
                          else
                            for (final m in _matches)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('Maç #${m.id.length > 8 ? m.id.substring(0, 8) : m.id}', style: const TextStyle(fontSize: 13))),
                                    Expanded(child: Text('${m.goldStolen} gold · ${m.isCritical ? 'Kritik zafer' : 'Standart'}', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                                    Text(_timeAgo(m.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
