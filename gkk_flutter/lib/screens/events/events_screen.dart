import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _activeEvents = [];
  List<Map<String, dynamic>> _upcomingEvents = [];
  List<Map<String, dynamic>> _pastEvents = [];
  bool _loading = true;
  String? _error;

  static const List<Map<String, dynamic>> _fallbackActive = [
    {
      'id': 'e1',
      'name': 'Kış Festivali',
      'description': 'Kışın ortasında festival coşkusu!',
      'status': 'active',
      'progress': 7,
      'max_progress': 20,
      'participated': true,
      'rewards': ['Kış Zırhı (Nadir)', '5,000 Altın'],
    },
    {
      'id': 'e2',
      'name': 'Çifte XP Haftası',
      'description': 'Bu hafta tüm XP kazanımları iki katı!',
      'status': 'active',
      'participated': false,
      'rewards': ['2x XP Bonusu'],
    },
  ];

  static const List<Map<String, dynamic>> _fallbackUpcoming = [
    {
      'id': 'e3',
      'name': 'Lonca Turnuvası',
      'description': 'Loncalar arası büyük kapışma yaklaşıyor.',
      'status': 'upcoming',
      'rewards': ['Lonca Rozeti', '20,000 Altın'],
    },
    {
      'id': 'e4',
      'name': 'Hazine Avı',
      'description': 'Gizli hazineleri bul, büyük ödüller kazan.',
      'status': 'upcoming',
      'rewards': ['Nadir Ekipman', '10,000 Altın'],
    },
  ];

  static const List<Map<String, dynamic>> _fallbackPast = [
    {
      'id': 'e5',
      'name': 'Sonbahar Hasadı',
      'description': 'Sonbaharın bereketini topla.',
      'status': 'completed',
      'rewards': ['Hasat Kostümü', '3,000 Altın'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = SupabaseService.client;
      List<Map<String, dynamic>> active = [];
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      try {
        final ar = await client.rpc('get_active_events');
        active = List<Map<String, dynamic>>.from(ar as List);
      } catch (_) {
        active = List<Map<String, dynamic>>.from(_fallbackActive);
      }

      try {
        final ur = await client.rpc('get_upcoming_events');
        upcoming = List<Map<String, dynamic>>.from(ur as List);
      } catch (_) {
        upcoming = List<Map<String, dynamic>>.from(_fallbackUpcoming);
      }

      try {
        final pr = await client.rpc('get_event_history');
        past = List<Map<String, dynamic>>.from(pr as List);
      } catch (_) {
        past = List<Map<String, dynamic>>.from(_fallbackPast);
      }

      if (active.isEmpty) active = List<Map<String, dynamic>>.from(_fallbackActive);
      if (upcoming.isEmpty) upcoming = List<Map<String, dynamic>>.from(_fallbackUpcoming);
      if (past.isEmpty) past = List<Map<String, dynamic>>.from(_fallbackPast);

      if (mounted) {
        setState(() {
          _activeEvents = active;
          _upcomingEvents = upcoming;
          _pastEvents = past;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
          _activeEvents = List<Map<String, dynamic>>.from(_fallbackActive);
          _upcomingEvents = List<Map<String, dynamic>>.from(_fallbackUpcoming);
          _pastEvents = List<Map<String, dynamic>>.from(_fallbackPast);
        });
      }
    }
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  Future<void> _participateInEvent(String eventId) async {
    try {
      await SupabaseService.client.rpc('participate_in_event', params: {'p_event_id': eventId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinliğe katıldınız!')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _claimReward(String eventId) async {
    try {
      await SupabaseService.client.rpc('claim_event_reward', params: {'p_event_id': eventId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ödül toplandı!')),
        );
        _load();
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
      drawer: GameDrawer(onLogout: _doLogout),
      appBar: GameTopBar(title: 'Etkinlikler', onLogout: _doLogout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.events),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '🔥 Aktif'),
                Tab(text: '📅 Yaklaşan'),
                Tab(text: '📜 Geçmiş'),
              ],
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white54,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEventList(_activeEvents, isActive: true),
                        _buildEventList(_upcomingEvents, isUpcoming: true),
                        _buildEventList(_pastEvents, isPast: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(
    List<Map<String, dynamic>> events, {
    bool isActive = false,
    bool isUpcoming = false,
    bool isPast = false,
  }) {
    if (events.isEmpty) {
      return const Center(
        child: Text('Etkinlik bulunamadı.', style: TextStyle(color: Colors.white54)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final event = events[index];
          return _EventCard(
            event: event,
            isActive: isActive,
            isPast: isPast,
            onParticipate: isActive ? () => _participateInEvent(event['id']?.toString() ?? '') : null,
            onClaim: isActive ? () => _claimReward(event['id']?.toString() ?? '') : null,
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isActive,
    required this.isPast,
    this.onParticipate,
    this.onClaim,
  });

  final Map<String, dynamic> event;
  final bool isActive;
  final bool isPast;
  final VoidCallback? onParticipate;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final name = event['name']?.toString() ?? '';
    final desc = event['description']?.toString() ?? '';
    final rewards = event['rewards'] is List
        ? List<String>.from(event['rewards'] as List)
        : <String>[];
    final participated = event['participated'] == true;
    final progress = _asInt(event['progress']);
    final maxProgress = _asInt(event['max_progress']);
    final hasProgress = maxProgress > 0;
    final progressComplete = hasProgress && progress >= maxProgress;

    final borderColor = isPast
        ? Colors.white12
        : isActive
            ? Colors.amber.withValues(alpha: 0.4)
            : Colors.blueAccent.withValues(alpha: 0.3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: isPast ? 0.03 : 0.05),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isPast ? Colors.white54 : Colors.white)),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                  child: const Text('Aktif',
                      style: TextStyle(
                          fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
          if (hasProgress) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('İlerleme', style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text('$progress / $maxProgress',
                    style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: maxProgress > 0 ? (progress / maxProgress).clamp(0.0, 1.0) : 0.0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                  progressComplete ? Colors.greenAccent : Colors.amber),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          if (rewards.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: rewards
                  .map((r) => Chip(
                        label: Text(r, style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.amber.withValues(alpha: 0.15),
                        side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          if (isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (!participated)
                  FilledButton(
                    onPressed: onParticipate,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Katıl'),
                  )
                else
                  OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      foregroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Katıldınız'),
                  ),
                if (progressComplete && participated) ...[
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: onClaim,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Ödülü Topla'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
