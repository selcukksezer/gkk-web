import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class _TournamentMatch {
  const _TournamentMatch({
    required this.id,
    required this.p1,
    required this.p2,
    required this.s1,
    required this.s2,
    required this.winner,
  });

  factory _TournamentMatch.fromJson(Map<String, dynamic> json) {
    return _TournamentMatch(
      id: json['id'] as int? ?? 0,
      p1: json['player1_name'] as String? ?? json['p1'] as String? ?? '?',
      p2: json['player2_name'] as String? ?? json['p2'] as String? ?? '?',
      s1: json['player1_score'] as int? ?? json['s1'] as int? ?? 0,
      s2: json['player2_score'] as int? ?? json['s2'] as int? ?? 0,
      winner: json['winner_name'] as String? ?? json['winner'] as String? ?? '',
    );
  }

  final int id;
  final String p1, p2;
  final int s1, s2;
  final String winner;
}

class _Round {
  const _Round({required this.title, required this.matches});

  factory _Round.fromJson(Map<String, dynamic> json) {
    final matchList = (json['matches'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_TournamentMatch.fromJson)
        .toList();
    return _Round(
      title: json['title'] as String? ?? json['round_name'] as String? ?? '',
      matches: matchList,
    );
  }

  final String title;
  final List<_TournamentMatch> matches;
}

const List<_Round> _kFallbackRounds = [
  _Round(title: 'Çeyrek Final', matches: [
    _TournamentMatch(id: 1, p1: 'KralŞövalye', p2: 'KaranlıkOkçu', s1: 2, s2: 1, winner: 'KralŞövalye'),
    _TournamentMatch(id: 2, p1: 'BüyücüGandalf', p2: 'GölgeSuikastçi', s1: 0, s2: 2, winner: 'GölgeSuikastçi'),
    _TournamentMatch(id: 3, p1: 'KanlıBalta', p2: 'SessizGölge', s1: 2, s2: 0, winner: 'KanlıBalta'),
    _TournamentMatch(id: 4, p1: 'EjderAvcısı', p2: 'AteşBüyücüsü', s1: 1, s2: 2, winner: 'AteşBüyücüsü'),
  ]),
  _Round(title: 'Yarı Final', matches: [
    _TournamentMatch(id: 5, p1: 'KralŞövalye', p2: 'GölgeSuikastçi', s1: 2, s2: 0, winner: 'KralŞövalye'),
    _TournamentMatch(id: 6, p1: 'KanlıBalta', p2: 'AteşBüyücüsü', s1: 1, s2: 2, winner: 'AteşBüyücüsü'),
  ]),
  _Round(title: 'Final', matches: [
    _TournamentMatch(id: 7, p1: 'KralŞövalye', p2: 'AteşBüyücüsü', s1: 3, s2: 2, winner: 'KralŞövalye'),
  ]),
];

class PvpTournamentScreen extends ConsumerStatefulWidget {
  const PvpTournamentScreen({super.key});

  @override
  ConsumerState<PvpTournamentScreen> createState() => _PvpTournamentScreenState();
}

class _PvpTournamentScreenState extends ConsumerState<PvpTournamentScreen> {
  List<_Round> _rounds = _kFallbackRounds.toList();
  String _championName = 'KralŞövalye';
  String _tournamentTitle = 'Sezon Ortası Şampiyonası';
  bool _isLoading = true;
  bool _isRegistrationOpen = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTournament());
  }

  Future<void> _loadTournament() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client.rpc('get_tournament_bracket');

      if (response != null) {
        final Map<String, dynamic> data;
        if (response is Map<String, dynamic>) {
          data = response;
        } else if (response is List && response.isNotEmpty && response[0] is Map<String, dynamic>) {
          data = response[0] as Map<String, dynamic>;
        } else {
          // Unrecognised shape – keep fallback
          setState(() => _isLoading = false);
          return;
        }

        final roundsList = (data['rounds'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(_Round.fromJson)
            .toList();

        if (roundsList.isNotEmpty) {
          _rounds = roundsList;
        }

        _championName = data['champion_name'] as String? ?? _championName;
        _tournamentTitle = data['tournament_name'] as String? ?? _tournamentTitle;
        _isRegistrationOpen = data['registration_open'] as bool? ?? false;
      }
    } catch (_) {
      // RPC not available yet – use fallback data
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _joinTournament() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);
    try {
      await SupabaseService.client.rpc('join_pvp_tournament');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turnuvaya başarıyla katıldınız!')),
        );
        await _loadTournament();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Katılım başarısız: ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => _isJoining = false);
  }

  @override
  Widget build(BuildContext context) {
    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: 'Haftalık Turnuva', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.pvpTournament),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _tournamentTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
            ),
            const SizedBox(height: 16),
            // Bracket
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2533),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final round in _rounds) ...[
                      _BracketColumn(round: round),
                      const SizedBox(width: 12),
                    ],
                    // Champion column
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Şampiyon', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                            boxShadow: [BoxShadow(color: const Color(0xFFFBBF24).withValues(alpha: 0.4), blurRadius: 16)],
                          ),
                          child: Column(
                            children: [
                              const Text('👑', style: TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Text(_championName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Prize pool
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏆 Ödül Havuzu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFBBF24))),
                  const SizedBox(height: 12),
                  for (final item in [('🥇', '1.', '10,000 Altın + Efsanevi Silah'), ('🥈', '2.', '5,000 Altın'), ('🥉', '3.', '2,500 Altın')])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Text(item.$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text('${item.$2} — ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(item.$3, style: const TextStyle(color: Colors.white70))),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _isRegistrationOpen
                  ? ElevatedButton(
                      onPressed: _isJoining ? null : _joinTournament,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isJoining
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Turnuvaya Katıl', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  : ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(disabledBackgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Turnuvaya Katıl (Kayıtlar Kapalı)', style: TextStyle(color: Colors.white38)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketColumn extends StatelessWidget {
  const _BracketColumn({required this.round});
  final _Round round;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(round.title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          for (final m in round.matches) ...[
            _MatchCard(match: m),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});
  final _TournamentMatch match;

  Widget _row(String name, int score, bool isWinner) => Container(
    color: isWinner ? const Color(0xFFFBBF24).withValues(alpha: 0.15) : Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: isWinner ? FontWeight.bold : FontWeight.normal, color: isWinner ? const Color(0xFFFBBF24) : Colors.white54))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
          child: Text('$score', style: const TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1A2030),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          _row(match.p1, match.s1, match.winner == match.p1),
          const Divider(height: 1, color: Colors.white12),
          _row(match.p2, match.s2, match.winner == match.p2),
        ],
      ),
    ),
  );
}
