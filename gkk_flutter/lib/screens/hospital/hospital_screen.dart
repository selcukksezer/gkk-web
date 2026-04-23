import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class HospitalScreen extends ConsumerStatefulWidget {
  const HospitalScreen({super.key});

  @override
  ConsumerState<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends ConsumerState<HospitalScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  int _initialSeconds = 0;
  bool _healed = false;
  bool _healing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _updateRemaining(isFirst: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining({bool isFirst = false}) {
    final profile = ref.read(playerProvider).profile;
    final hospitalUntil = profile?.hospitalUntil;
    if (hospitalUntil == null || hospitalUntil.isEmpty) {
      setState(() => _remaining = Duration.zero);
      return;
    }
    final releaseTime = DateTime.tryParse(hospitalUntil);
    if (releaseTime == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }
    final now = DateTime.now();
    if (releaseTime.isAfter(now)) {
      final remaining = releaseTime.difference(now);
      setState(() {
        _remaining = remaining;
        if (isFirst) _initialSeconds = remaining.inSeconds;
      });
    } else {
      setState(() => _remaining = Duration.zero);
      // Natural expiry — refresh player
      ref.read(playerProvider.notifier).loadProfile();
    }
  }

  bool get _inHospital {
    final profile = ref.read(playerProvider).profile;
    final hospitalUntil = profile?.hospitalUntil;
    if (hospitalUntil == null || hospitalUntil.isEmpty) return false;
    final releaseTime = DateTime.tryParse(hospitalUntil);
    if (releaseTime == null) return false;
    return releaseTime.isAfter(DateTime.now());
  }

  Future<void> _healWithGems() async {
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return;

    final remainingSecs = _remaining.inSeconds;
    final gemCost = (remainingSecs / 60).ceil() * 3;

    if (profile.gems < gemCost) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Yetersiz Elmas'),
          content: Text('Bu işlem için $gemCost 💎 gerekiyor. Mevcut: ${profile.gems} 💎'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go(AppRoutes.shop);
              },
              child: const Text('Dükkana Git'),
            ),
          ],
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Taburcu Ol'),
        content: Text('$gemCost 💎 harcayarak hemen taburcu olmak istiyor musunuz?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _healing = true);
    try {
      await SupabaseService.client.rpc('heal_with_gems');
      await ref.read(playerProvider.notifier).loadProfile();
      setState(() {
        _healed = true;
        _healing = false;
        _remaining = Duration.zero;
      });
      _timer?.cancel();
    } catch (e) {
      setState(() => _healing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    // Ensure widget rebuilds when player profile changes
    ref.watch(playerProvider);

    // Listen for profile updates so the timer/remaining value refreshes
    // immediately when the player profile is loaded or changed.
    ref.listen<PlayerState>(playerProvider, (previous, next) {
      if (!mounted) return;
      _updateRemaining(isFirst: true);
    });
    final profile = ref.read(playerProvider).profile;
    final inHospital = _inHospital && !_healed;

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: '🏥 Hastane',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.hospital),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: profile == null ? _buildLoading() : (inHospital ? _buildInHospital(profile) : _buildHealthy()),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: Colors.black26,
      ),
      child: const Center(
        child: SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
      ),
    );
  }
  Widget _buildHealthy() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: Colors.black26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('👍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            '🏥 Hastane',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sağlıksınız — hastanede değilsiniz',
            style: TextStyle(color: Colors.white70, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Ana Sayfaya Dön'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInHospital(dynamic profile) {
    final String? hospitalUntil = profile?.hospitalUntil;
    final releaseTime = hospitalUntil != null ? DateTime.tryParse(hospitalUntil) : null;
    final remainingSecs = _remaining.inSeconds;
    final gemCost = (remainingSecs / 60).ceil() * 3;
    final energy = profile?.energy as int? ?? 0;
    final maxEnergy = profile?.maxEnergy as int? ?? 100;
    final gems = profile?.gems as int? ?? 0;

    String releaseFormatted = '—';
    if (releaseTime != null) {
      releaseFormatted =
          '${releaseTime.year.toString().padLeft(4, '0')}-${releaseTime.month.toString().padLeft(2, '0')}-${releaseTime.day.toString().padLeft(2, '0')} '
          '${releaseTime.hour.toString().padLeft(2, '0')}:${releaseTime.minute.toString().padLeft(2, '0')}:${releaseTime.second.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        color: Colors.black26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              Text('🏥', style: TextStyle(fontSize: 32)),
              SizedBox(width: 10),
              Text(
                'Hastanede',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Neden:', 'Zindan başarısızlığı'),
          const SizedBox(height: 6),
          _infoRow('Taburcu Tarihi:', releaseFormatted),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _formatCountdown(_remaining),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _initialSeconds > 0
                ? max(0.0, min(1.0, 1.0 - (_remaining.inSeconds / _initialSeconds)))
                : 0.0,
            backgroundColor: Colors.white12,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          Text(
            '⚡ Enerji: $energy/$maxEnergy',
            style: const TextStyle(color: Color(0xFF00D7D7), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _healing ? null : _healWithGems,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9B30FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _healing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('💎 $gemCost Gem ile Taburcu Ol', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Mevcut: $gems 💎',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
