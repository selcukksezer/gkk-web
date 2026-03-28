import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class GuildWarScreen extends ConsumerStatefulWidget {
  const GuildWarScreen({super.key});

  @override
  ConsumerState<GuildWarScreen> createState() => _GuildWarScreenState();
}

class _GuildWarScreenState extends ConsumerState<GuildWarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _season;
  List<Map<String, dynamic>> _tournaments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _territories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _rankings = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  static const List<Map<String, dynamic>> _fallbackTournaments = <Map<String, dynamic>>[
    {'id': 'fallback_tournament_1', 'name': 'Haftalık Arena', 'status': 'active', 'guildCount': 8, 'prizePool': '50,000 Altın'},
    {'id': 'fallback_tournament_2', 'name': 'Sezon Finali', 'status': 'upcoming', 'guildCount': 0, 'prizePool': '250,000 Altın + Efsanevi Eşya'},
  ];

  static const List<Map<String, dynamic>> _fallbackTerritories = <Map<String, dynamic>>[
    {'id': 'fallback_territory_1', 'name': 'Demir Kalesi', 'owner_guild': '—', 'defense_power': 1200, 'reward': '5,000 Altın/gün'},
    {'id': 'fallback_territory_2', 'name': 'Altın Ovası', 'owner_guild': '—', 'defense_power': 800, 'reward': '3,000 Altın/gün'},
    {'id': 'fallback_territory_3', 'name': 'Ejderha Tepesi', 'owner_guild': '—', 'defense_power': 2500, 'reward': 'Efsanevi Eşya Şansı'},
    {'id': 'fallback_territory_4', 'name': 'Karanlık Liman', 'owner_guild': '—', 'defense_power': 600, 'reward': '2,000 Altın/gün'},
  ];

  static const List<Map<String, dynamic>> _fallbackRankings = <Map<String, dynamic>>[
    {'rank': 1, 'guild_name': 'Gölge Ordosu', 'points': 15000, 'wins': 42, 'losses': 8},
    {'rank': 2, 'guild_name': 'Demir Kalkan', 'points': 13200, 'wins': 38, 'losses': 12},
    {'rank': 3, 'guild_name': 'Ejder Klanı', 'points': 11500, 'wins': 31, 'losses': 19},
    {'rank': 4, 'guild_name': 'Işık Savunucuları', 'points': 9800, 'wins': 27, 'losses': 23},
    {'rank': 5, 'guild_name': 'Karanlık Avcılar', 'points': 7600, 'wins': 22, 'losses': 28},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final errors = <String>[];
      final results = await Future.wait(<Future<dynamic>>[
        SupabaseService.client.rpc('get_guild_war_season').catchError((Object e) {
          errors.add('Sezon: $e');
          return null;
        }),
        SupabaseService.client.rpc('get_guild_war_tournaments').catchError((Object e) {
          errors.add('Turnuvalar: $e');
          return null;
        }),
        SupabaseService.client.rpc('get_guild_war_territories').catchError((Object e) {
          errors.add('Bölgeler: $e');
          return null;
        }),
        SupabaseService.client.rpc('get_guild_war_rankings').catchError((Object e) {
          errors.add('Sıralama: $e');
          return null;
        }),
      ]);

      final season = results[0];
      final tournaments = results[1];
      final territories = results[2];
      final rankings = results[3];

      setState(() {
        _season = (season is Map<String, dynamic>) ? season : null;
        _tournaments = _toList(tournaments) ?? _fallbackTournaments;
        _territories = _toList(territories) ?? _fallbackTerritories;
        _rankings = _toList(rankings) ?? _fallbackRankings;
        _loading = false;
        _error = errors.isNotEmpty ? errors.join('; ') : null;
      });
    } catch (e) {
      setState(() {
        _tournaments = _fallbackTournaments;
        _territories = _fallbackTerritories;
        _rankings = _fallbackRankings;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>>? _toList(dynamic data) {
    if (data == null) return null;
    if (data is List && data.isNotEmpty) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }

  Future<void> _joinTournament(dynamic tournamentId) async {
    if (tournamentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turnuva bilgisi bulunamadı.')),
        );
      }
      return;
    }
    try {
      await SupabaseService.client.rpc('join_guild_war', params: {'p_tournament_id': tournamentId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turnuvaya katıldınız!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _attackTerritory(dynamic territoryId) async {
    if (territoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bölge bilgisi bulunamadı.')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saldırı Onayı'),
        content: const Text('Bu bölgeye saldırmak istediğinize emin misiniz?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Saldır'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.client.rpc('attack_guild_war_territory', params: {'p_territory_id': territoryId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldırı başlatıldı!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
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
        title: '🏴 Lonca Savaşı',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.guildWar),
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
            if (_season != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Sezon ${_season!['season'] ?? '?'} · Hafta ${_season!['week'] ?? '?'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Bazı veriler yüklenemedi. Yedek veriler gösteriliyor.',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                indicatorColor: const Color(0xFF5A32DC),
                dividerColor: Colors.transparent,
                tabs: const <Tab>[
                  Tab(text: '🏆 Turnuvalar'),
                  Tab(text: '🗺️ Bölgeler'),
                  Tab(text: '📊 Sıralama'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _buildTournaments(),
                        _buildTerritories(),
                        _buildRankings(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournaments() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _tournaments.length,
      itemBuilder: (context, index) {
        final t = _tournaments[index];
        final status = t['status'] as String? ?? '';
        final isActive = status == 'active';
        final statusColor = isActive
            ? Colors.greenAccent
            : (status == 'upcoming' ? Colors.blueAccent : Colors.white38);
        final statusLabel = isActive ? 'Aktif' : (status == 'upcoming' ? 'Yaklaşan' : 'Tamamlandı');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            color: Colors.black26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(t['name'] as String? ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: statusColor.withValues(alpha: 0.15),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('👥 ${t['guildCount'] ?? 0} Lonca', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text('🏆 ${t['prizePool'] ?? '—'}', style: const TextStyle(color: Colors.amber, fontSize: 12)),
              if (isActive) ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _joinTournament(t['id']),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5A32DC)),
                    child: const Text('Katıl'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTerritories() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _territories.length,
      itemBuilder: (context, index) {
        final t = _territories[index];
        final owner = t['owner_guild'] as String? ?? '—';
        final defPower = t['defense_power'];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            color: Colors.black26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(t['name'] as String? ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              Text('🏰 Sahip: $owner', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text('⚔️ Savunma Gücü: $defPower', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              const SizedBox(height: 4),
              Text('💰 Ödül: ${t['reward'] ?? '—'}', style: const TextStyle(color: Colors.amber, fontSize: 12)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _attackTerritory(t['id']),
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('Saldır'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankings() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rankings.length,
      itemBuilder: (context, index) {
        final r = _rankings[index];
        final rank = r['rank'] as int? ?? (index + 1);
        final isTop3 = rank <= 3;
        final medalColor = rank == 1
            ? Colors.amber
            : (rank == 2 ? Colors.blueGrey[300]! : Colors.brown[300]!);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isTop3 ? medalColor.withValues(alpha: 0.4) : Colors.white12),
            color: Colors.black26,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 36,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isTop3 ? medalColor : Colors.white38,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  r['guild_name'] as String? ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${r['points'] ?? 0} puan',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  Text(
                    '${r['wins'] ?? 0}G / ${r['losses'] ?? 0}K',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
