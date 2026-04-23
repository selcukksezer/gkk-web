import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class _PvpMatch {
  const _PvpMatch({
    required this.id,
    required this.attackerId,
    required this.defenderId,
    required this.winnerId,
    required this.goldStolen,
    required this.repChangeWinner,
    required this.repChangeLoser,
    required this.isCritical,
    required this.createdAt,
    this.attackerUsername,
    this.defenderUsername,
  });

  final String id;
  final String attackerId;
  final String? defenderId;
  final String? winnerId;
  final int goldStolen;
  final int repChangeWinner;
  final int repChangeLoser;
  final bool isCritical;
  final String createdAt;
  final String? attackerUsername;
  final String? defenderUsername;

  factory _PvpMatch.fromJson(Map<String, dynamic> j) => _PvpMatch(
        id: j['id'] as String? ?? '',
        attackerId: j['attacker_id'] as String? ?? '',
        defenderId: j['defender_id'] as String?,
        winnerId: j['winner_id'] as String?,
        goldStolen: (j['gold_stolen'] as num?)?.toInt() ?? 0,
        repChangeWinner: (j['rep_change_winner'] as num?)?.toInt() ?? 0,
        repChangeLoser: (j['rep_change_loser'] as num?)?.toInt() ?? 0,
        isCritical: j['is_critical_success'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
        attackerUsername: (j['attacker'] as Map?)?['username'] as String?,
        defenderUsername: (j['defender'] as Map?)?['username'] as String?,
      );
}

class PvpHistoryScreen extends ConsumerStatefulWidget {
  const PvpHistoryScreen({super.key});

  @override
  ConsumerState<PvpHistoryScreen> createState() => _PvpHistoryScreenState();
}

class _PvpHistoryScreenState extends ConsumerState<PvpHistoryScreen> {
  List<_PvpMatch> _matches = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'win', 'loss'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = ref.read(playerProvider).profile;
    final authId = profile?.authId;
    if (authId == null) { if (mounted) setState(() => _isLoading = false); return; }

    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.client
          .from('pvp_matches')
          .select('*, attacker:attacker_id(username), defender:defender_id(username)')
          .or('attacker_id.eq.$authId,defender_id.eq.$authId')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _matches = (data as List).map((e) => _PvpMatch.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Az önce';
      if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
      if (diff.inDays < 1) return '${diff.inHours}sa önce';
      return '${diff.inDays}g önce';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final authId = ref.watch(playerProvider).profile?.authId ?? '';

    List<_PvpMatch> filtered = _matches;
    if (_filter == 'win') filtered = _matches.where((m) => m.winnerId == authId).toList();
    if (_filter == 'loss') filtered = _matches.where((m) => m.winnerId != authId).toList();

    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: '⚔️ PvP Maç Geçmişi', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.pvpHistory),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Column(
          children: [
            // Filter tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  for (final f in [('all', 'Tümü'), ('win', 'Kazandım'), ('loss', 'Kaybettim')])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f.$1),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _filter == f.$1 ? const Color(0xFFFBBF24).withValues(alpha: 0.2) : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _filter == f.$1 ? const Color(0xFFFBBF24) : Colors.transparent),
                          ),
                          child: Text(f.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _filter == f.$1 ? const Color(0xFFFBBF24) : Colors.white54)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⚔️', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              const Text('Henüz hiç PvP maçınız bulunmuyor.', style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 12),
                              TextButton(onPressed: _load, child: const Text('Yenile')),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final m = filtered[i];
                              final isAttacker = m.attackerId == authId;
                              final isWinner = m.winnerId == authId;
                              final opponentName = isAttacker ? (m.defenderUsername ?? 'Bilinmeyen') : (m.attackerUsername ?? 'Bilinmeyen');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border(
                                    left: BorderSide(
                                      color: isWinner ? Colors.green : Colors.red,
                                      width: 4,
                                    ),
                                  ),
                                  color: isWinner ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                                children: [
                                                  TextSpan(text: isAttacker ? 'Saldırdınız: ' : 'Savundunuz: '),
                                                  TextSpan(
                                                    text: opponentName,
                                                    style: TextStyle(color: isAttacker ? Colors.redAccent : const Color(0xFFFBBF24)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Sonuç: ${isWinner ? 'Kazandınız' : 'Kaybettiniz'}${m.isCritical ? ' · 💥 Ezici Zafer' : ''}',
                                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                                            ),
                                            Text(
                                              _timeAgo(m.createdAt),
                                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${isWinner ? '+' : '-'}${m.goldStolen} Gold',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isWinner ? const Color(0xFFFBBF24) : Colors.white38,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${isWinner ? '+' : '-'}${isWinner ? m.repChangeWinner : m.repChangeLoser} Rep',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isWinner ? Colors.blue : Colors.white38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
