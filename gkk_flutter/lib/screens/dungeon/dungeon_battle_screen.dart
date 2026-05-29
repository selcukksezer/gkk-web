import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../core/services/supabase_service.dart';
import 'dungeon_victory_effects.dart';

class DungeonBattleScreen extends ConsumerStatefulWidget {
  const DungeonBattleScreen({super.key});

  @override
  ConsumerState<DungeonBattleScreen> createState() => _DungeonBattleScreenState();
}

class _DungeonBattleScreenState extends ConsumerState<DungeonBattleScreen>
  {
  String _phase = 'idle';
  String _dungeonId = '';
  String _dungeonName = 'Zindan';
  int _countdown = 3;
  Map<String, dynamic>? _result;
  bool _claiming = false;
  Timer? _countdownTimer;
  bool _paramsLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_paramsLoaded) {
      _paramsLoaded = true;
      final params = GoRouterState.of(context).uri.queryParameters;
      setState(() {
        _dungeonId = params['dungeon_id'] ?? '';
        _dungeonName = params['dungeon_name'] ?? 'Zindan';
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _phase = 'counting';
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        _startBattle();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _startBattle() async {
    setState(() => _phase = 'fighting');
    try {
      final raw = await SupabaseService.client
          .rpc('attack_dungeon', params: {'p_dungeon_id': _dungeonId});
      if (!mounted) return;
      if (raw is Map) {
        final result = {
          'success': raw['success'] ?? false,
          'gold': raw['gold'] ?? 0,
          'xp': raw['xp'] ?? 0,
          'items': List<String>.from(raw['items'] ?? []),
          'hospitalized': raw['hospitalized'] ?? false,
          'hospital_duration': raw['hospital_duration'] ?? 0,
        };
        setState(() {
          _result = result;
          _phase = (result['success'] as bool) ? 'success' : 'failure';
        });
      } else {
        setState(() {
          _result = null;
          _phase = 'failure';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      setState(() => _phase = 'idle');
    }
  }

  Future<void> _claimRewards() async {
    setState(() => _claiming = true);
    try {
      await SupabaseService.client
          .rpc('collect_dungeon_rewards', params: {'p_dungeon_id': _dungeonId});
    } catch (_) {
      // server already applied rewards
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('🏆 Ödüller alındı!')));
    context.go(AppRoutes.dungeon);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 dk';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m dk';
    return '$h sa $m dk';
  }

  String _inferRarity(String itemId) {
    final lower = itemId.toLowerCase();
    if (lower.endsWith('_mythic')) return 'mythic';
    if (lower.endsWith('_legendary')) return 'legendary';
    if (lower.endsWith('_epic')) return 'epic';
    if (lower.endsWith('_rare')) return 'rare';
    if (lower.endsWith('_uncommon')) return 'uncommon';
    return 'common';
  }

  String _formatItemName(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
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
    logoutHandler() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logoutHandler),
      appBar: GameTopBar(title: '🏰 $_dungeonName', onLogout: logoutHandler),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.dungeon),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10131D), Color(0xFF171E2C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildPhaseContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case 'idle':
        return _buildIdlePhase();
      case 'counting':
        return _buildCountingPhase();
      case 'fighting':
        return _buildFightingPhase();
      case 'success':
        return _buildSuccessPhase();
      case 'failure':
        return _buildFailurePhase();
      default:
        return _buildIdlePhase();
    }
  }

  Widget _buildIdlePhase() {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('🏰 $_dungeonName',
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Zindana saldırmak için butona bas.',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startCountdown,
              icon: const Text('⚔️'),
              label: const Text('Saldır'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.dungeon),
              child: const Text('← Geri Dön', style: TextStyle(color: Colors.white54)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCountingPhase() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _countdown.toString(),
              key: ValueKey(_countdown),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Hazırlan...', style: TextStyle(color: Colors.white54, fontSize: 16)),
        ]),
      ),
    );
  }

  Widget _buildFightingPhase() {
    return const SizedBox(
      height: 300,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('⚔️', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('Savaş devam ediyor…', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 8),
          CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ]),
      ),
    );
  }

  Widget _buildSuccessPhase() {
    if (_result == null) return const SizedBox.shrink();
    final items = (_result!['items'] as List<String>);
    final inventoryFull = _result!['inventory_full'] == true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (inventoryFull) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Envanter dolu! Bazı eşyalar alınamadı.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 4),
        ));
      }
    });

    final badges = <Widget>[
      VictoryBadge(
        icon: '💰',
        label: 'ALTIN',
        value: '${_result!["gold"]}',
        color: const Color(0xFFDDB200),
      ),
      const SizedBox(width: kBadgeGapBetween),
      VictoryBadge(
        icon: '✨',
        label: 'XP',
        value: '+${_result!["xp"]}',
        color: const Color(0xFF22C55E),
      ),
      if (items.isNotEmpty) ...[
        const SizedBox(width: kBadgeGapBetween),
        VictoryBadge(
          icon: '🎒',
          label: 'EŞYA',
          value: '${items.length}',
          color: const Color(0xFF3B82F6),
          sub: items.length == 1 ? _formatItemName(items.first) : null,
        ),
      ],
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VictoryCard(
        animation: const AlwaysStoppedAnimation<double>(1.0),
        badges: badges,
      ),
      const SizedBox(height: 16),
      if (!_claiming)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _claimRewards,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDDB200),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text('ÖDÜLLERİ AL',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        )
      else
        const Center(child: CircularProgressIndicator(color: Color(0xFFDDB200))),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: _claiming ? null : () => context.go(AppRoutes.dungeon),
          child: const Text('← Zindanlara Dön', style: TextStyle(color: Colors.white54)),
        ),
      ),
    ]);
  }

  Widget _buildFailurePhase() {
    final hospitalized = _result?['hospitalized'] == true;
    final duration = _formatDuration((_result?['hospital_duration'] as int?) ?? 0);
    final notices = hospitalized
        ? <String>[
            'Hastaneye düştün',
            'Tedavi süresi: $duration',
          ]
        : <String>[
            'Yenildin',
            'Bu sefer şanssızdın, tekrar dene.',
          ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DefeatCard(
        animation: const AlwaysStoppedAnimation<double>(1.0),
        notices: notices,
      ),
      const SizedBox(height: 14),
      if (hospitalized)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.hospital),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF991B1B),
              foregroundColor: Colors.white,
            ),
            child: const Text('🏥 Hastane'),
          ),
        ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => context.go(AppRoutes.dungeon),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
          ),
          child: const Text('← Geri Dön'),
        ),
      ),
    ]);
  }
}
