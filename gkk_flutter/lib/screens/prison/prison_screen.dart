import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class PrisonScreen extends ConsumerStatefulWidget {
  const PrisonScreen({super.key});

  @override
  ConsumerState<PrisonScreen> createState() => _PrisonScreenState();
}

class _PrisonScreenState extends ConsumerState<PrisonScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  int _initialSeconds = 0;
  bool _freed = false;
  bool _paying = false;

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
    final prisonUntil = profile?.prisonUntil;
    if (prisonUntil == null || prisonUntil.isEmpty) {
      setState(() => _remaining = Duration.zero);
      return;
    }
    final releaseTime = DateTime.tryParse(prisonUntil);
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
      ref.read(playerProvider.notifier).loadProfile();
    }
  }

  bool get _inPrison {
    final profile = ref.read(playerProvider).profile;
    final prisonUntil = profile?.prisonUntil;
    if (prisonUntil == null || prisonUntil.isEmpty) return false;
    final releaseTime = DateTime.tryParse(prisonUntil);
    if (releaseTime == null) return false;
    return releaseTime.isAfter(DateTime.now());
  }

  Future<void> _payBail() async {
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return;

    final bailCost = max(1, (_remaining.inSeconds / 60).ceil());
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kefalet Öde'),
        content: Text('$bailCost 💎 harcayarak serbest kalmak istiyor musunuz?'),
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

    setState(() => _paying = true);
    try {
      await SupabaseService.client.rpc('release_from_prison', params: {'p_use_bail': true});
      await ref.read(playerProvider.notifier).loadProfile();
      setState(() {
        _freed = true;
        _paying = false;
        _remaining = Duration.zero;
      });
      _timer?.cancel();
    } catch (e) {
      setState(() => _paying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  String _formatCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerProvider);
    final profile = ref.read(playerProvider).profile;
    final inPrison = _inPrison && !_freed;

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: '⛓️ Cezaevi',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.prison),
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
              child: inPrison ? _buildInPrison(profile) : _buildFree(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFree() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: Colors.black26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Text('👍', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            'Cezaevi',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            '✅ Şu anda özgürsünüz!',
            style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Text(
            'Gölge Ekonomi\'de hukuk ve düzen sağlanıyor. Yasalara uyduğunuz sürece özgürsünüz!',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInPrison(dynamic profile) {
    final prisonReason = profile?.prisonReason as String?;
    final gems = profile?.gems as int? ?? 0;
    final remainingSecs = _remaining.inSeconds;
    final bailCost = max(1, (remainingSecs / 60).ceil());
    final canAfford = gems >= bailCost;
    final progress = _initialSeconds > 0
        ? 1.0 - (remainingSecs / _initialSeconds)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        color: Colors.black26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              Text('👮', style: TextStyle(fontSize: 32)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⛓️ HAPİSHANEDESİNİZ!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.redAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '📄 Gerekçe: ${prisonReason ?? 'Bilinmiyor'}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          const Text(
            'Yasalara aykırı davranışlar nedeniyle hapishanedesiniz. Kefalet ödeyerek erken çıkabilir veya sürenizi tamamlayabilirsiniz.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _formatCountdown(_remaining),
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.orangeAccent, letterSpacing: 3),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: max(0.0, min(1.0, progress)),
            backgroundColor: Colors.white12,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
          Text(
            '💎 Mevcut: $gems Elmas',
            style: const TextStyle(color: Color(0xFFC34BFF), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (canAfford && !_paying) ? _payBail : null,
              style: FilledButton.styleFrom(
                backgroundColor: canAfford ? Colors.orangeAccent : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _paying
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      '💰 Kefalet Öde ($bailCost Elmas)',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
            ),
          ),
          if (!canAfford) ...<Widget>[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Yeterli elmasınız yok! ($gems / $bailCost)',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
