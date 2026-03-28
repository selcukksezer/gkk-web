import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _LeaderboardEntry {
  _LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.value,
    required this.level,
    this.guild,
  });
  final int rank;
  final String username;
  final int value;
  final int level;
  final String? guild;
}

const List<Map<String, String>> _categories = <Map<String, String>>[
  <String, String>{'key': 'gold', 'label': 'Servet', 'icon': '💰'},
  <String, String>{'key': 'pvp_rating', 'label': 'PvP', 'icon': '⚔️'},
  <String, String>{'key': 'level', 'label': 'Görev', 'icon': '📜'},
  <String, String>{'key': 'power', 'label': 'Güç', 'icon': '💪'},
  <String, String>{'key': 'guild_power', 'label': 'Lonca', 'icon': '🏰'},
];

List<_LeaderboardEntry> _defaultEntries() => <_LeaderboardEntry>[
      _LeaderboardEntry(rank: 1, username: 'GölgeKral', value: 9999999, level: 99, guild: 'Gölge Ordosu'),
      _LeaderboardEntry(rank: 2, username: 'DemirKılıç', value: 8500000, level: 95, guild: 'Demir Kalkan'),
      _LeaderboardEntry(rank: 3, username: 'AltınEjder', value: 7200000, level: 90, guild: 'Altın Ejderha'),
      _LeaderboardEntry(rank: 4, username: 'KuzeyRüzgar', value: 6100000, level: 85),
      _LeaderboardEntry(rank: 5, username: 'KaranlıkAteş', value: 5500000, level: 82, guild: 'Karanlık Ateş'),
      _LeaderboardEntry(rank: 6, username: 'YıldızAvcı', value: 4900000, level: 78),
      _LeaderboardEntry(rank: 7, username: 'BuzSavaşçı', value: 4200000, level: 74, guild: 'Kuzey Rüzgarı'),
      _LeaderboardEntry(rank: 8, username: 'CemreMihr', value: 3700000, level: 70),
      _LeaderboardEntry(rank: 9, username: 'ŞahinGözü', value: 3100000, level: 66, guild: 'Demir Kalkan'),
      _LeaderboardEntry(rank: 10, username: 'Karanlıkçı', value: 2800000, level: 62),
      _LeaderboardEntry(rank: 11, username: 'AtılganKurt', value: 2500000, level: 59, guild: 'Gölge Ordosu'),
      _LeaderboardEntry(rank: 12, username: 'DağKartalı', value: 2200000, level: 55),
      _LeaderboardEntry(rank: 13, username: 'SertKaya', value: 2000000, level: 52, guild: 'Altın Ejderha'),
      _LeaderboardEntry(rank: 14, username: 'HızlıKılıç', value: 1800000, level: 50),
      _LeaderboardEntry(rank: 15, username: 'GeceAvcısı', value: 1650000, level: 48, guild: 'Karanlık Ateş'),
      _LeaderboardEntry(rank: 16, username: 'UçanOk', value: 1500000, level: 45),
      _LeaderboardEntry(rank: 17, username: 'DemirYumruk', value: 1350000, level: 43, guild: 'Demir Kalkan'),
      _LeaderboardEntry(rank: 18, username: 'KızılŞimşek', value: 1200000, level: 41),
      _LeaderboardEntry(rank: 19, username: 'Bozkurt', value: 1100000, level: 39, guild: 'Kuzey Rüzgarı'),
      _LeaderboardEntry(rank: 20, username: 'SiyahGölge', value: 1000000, level: 37),
      _LeaderboardEntry(rank: 21, username: 'GümüşKılıç', value: 900000, level: 35, guild: 'Gölge Ordosu'),
      _LeaderboardEntry(rank: 22, username: 'OtekinFırıldak', value: 800000, level: 33),
      _LeaderboardEntry(rank: 23, username: 'Kasırga', value: 700000, level: 31, guild: 'Altın Ejderha'),
      _LeaderboardEntry(rank: 24, username: 'ÇelikBilek', value: 600000, level: 29),
      _LeaderboardEntry(rank: 25, username: 'UğurluKılıç', value: 500000, level: 27, guild: 'Karanlık Ateş'),
      _LeaderboardEntry(rank: 26, username: 'SonsuzSavaşçı', value: 420000, level: 25),
      _LeaderboardEntry(rank: 27, username: 'KaraFırtına', value: 350000, level: 23, guild: 'Demir Kalkan'),
      _LeaderboardEntry(rank: 28, username: 'Yıldırım', value: 280000, level: 21),
      _LeaderboardEntry(rank: 29, username: 'SahilKoruyucu', value: 210000, level: 19, guild: 'Kuzey Rüzgarı'),
      _LeaderboardEntry(rank: 30, username: 'BaşlangıçKahramanı', value: 150000, level: 17),
    ];

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _compact(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return '$v';
}

String _formatValue(int value, String category) {
  switch (category) {
    case 'gold':
      return '🪙 ${_compact(value)}';
    case 'level':
      return 'Lv.$value';
    case 'pvp_rating':
      return '${_compact(value)} puan';
    case 'guild_power':
      return '${_compact(value)} güç';
    default:
      return '${_compact(value)} güç';
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<_LeaderboardEntry> _entries = <_LeaderboardEntry>[];
  List<_LeaderboardEntry> _filtered = <_LeaderboardEntry>[];
  bool _loading = true;
  int _categoryIndex = 0;
  bool _weekly = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _currentCategory => _categories[_categoryIndex]['key']!;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dynamic result = await SupabaseService.client.rpc(
        'get_leaderboard',
        params: <String, dynamic>{'p_category': _currentCategory, 'p_limit': 30},
      );
      if (result is List && result.isNotEmpty) {
        final List<_LeaderboardEntry> entries = (result as List<dynamic>).map((dynamic e) {
          final Map<String, dynamic> m = e as Map<String, dynamic>;
          return _LeaderboardEntry(
            rank: (m['rank'] as int?) ?? 0,
            username: (m['username'] as String?) ?? '',
            value: (m['value'] as int?) ?? 0,
            level: (m['level'] as int?) ?? 0,
            guild: m['guild'] as String?,
          );
        }).toList();
        setState(() {
          _entries = entries;
          _applyFilter();
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // fall through
    }
    setState(() {
      _entries = _defaultEntries();
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    final String q = _searchCtrl.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<_LeaderboardEntry>.from(_entries);
      } else {
        _filtered = _entries.where((_LeaderboardEntry e) {
          return e.username.toLowerCase().contains(q) || (e.guild?.toLowerCase().contains(q) ?? false);
        }).toList();
      }
    });
  }

  void _selectCategory(int idx) {
    if (_categoryIndex == idx) return;
    setState(() => _categoryIndex = idx);
    _load();
  }

  // ─── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildPodium() {
    final List<_LeaderboardEntry> top3 = _filtered.take(3).toList();
    if (top3.length < 3) return const SizedBox.shrink();

    const Color gold = Color(0xFFFBBF24);
    const Color silver = Color(0xFF9CA3AF);
    const Color bronze = Color(0xFFB45309);

    Widget _podiumSlot(_LeaderboardEntry e, String medal, Color color, double height) {
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(e.username, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(medal, style: const TextStyle(fontSize: 22)),
            Text(_formatValue(e.value, _currentCategory), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            Container(
              height: height,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              alignment: Alignment.center,
              child: Text('${e.rank}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _podiumSlot(top3[1], '🥈', silver, 80),
            const SizedBox(width: 4),
            _podiumSlot(top3[0], '🥇', gold, 110),
            const SizedBox(width: 4),
            _podiumSlot(top3[2], '🥉', bronze, 65),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTile(_LeaderboardEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text('#${e.rank}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(e.username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                if (e.guild != null)
                  Text('🏰 ${e.guild}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text(_formatValue(e.value, _currentCategory), style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPlayerBanner() {
    final String username = ref.watch(playerProvider).profile?.username ?? 'Sen';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
        border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          const Text('👤', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const Text('Senin Sıralaman', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(_formatValue(85000, _currentCategory), style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w700)),
              const Text('#42', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Sıralama',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.leaderboard),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Column(
          children: <Widget>[
            // Category tabs
            SizedBox(
              height: 44,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (BuildContext ctx, int i) {
                        final bool selected = _categoryIndex == i;
                        return GestureDetector(
                          onTap: () => _selectCategory(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: selected ? const Color(0xFF60A5FA) : Colors.white10,
                              border: Border.all(color: selected ? const Color(0xFF60A5FA) : Colors.white12),
                            ),
                            child: Text(
                              '${_categories[i]['icon']} ${_categories[i]['label']}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.black : Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _load,
                      tooltip: 'Yenile',
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            // Timeframe + search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: <Widget>[
                  _TimeframeBtn(label: 'Tüm Zamanlar', selected: !_weekly, onTap: () => setState(() => _weekly = false)),
                  const SizedBox(width: 6),
                  _TimeframeBtn(label: 'Haftalık', selected: _weekly, onTap: () => setState(() => _weekly = true)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Oyuncu veya lonca ara...',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, size: 16),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: <Widget>[
                        if (_searchCtrl.text.isEmpty) _buildPodium(),
                        if (_searchCtrl.text.isEmpty)
                          ..._filtered.skip(3).map(_buildEntryTile)
                        else
                          ..._filtered.map(_buildEntryTile),
                        _buildPlayerBanner(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeframeBtn extends StatelessWidget {
  const _TimeframeBtn({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? const Color(0xFF4ADE80) : Colors.white10,
          border: Border.all(color: selected ? const Color(0xFF4ADE80) : Colors.white12),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.black : Colors.white)),
      ),
    );
  }
}
