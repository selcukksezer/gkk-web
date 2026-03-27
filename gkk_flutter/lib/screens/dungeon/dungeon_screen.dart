import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../models/dungeon_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dungeon_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

enum _DungeonMode {
  solo,
  group,
}

class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({super.key});

  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen> {
  String _query = '';
  _DungeonMode _mode = _DungeonMode.solo;
  String? _entryPhase;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(dungeonProvider.notifier).loadDungeons();
    });
  }

  Future<void> _enterDungeon(DungeonData dungeon) async {
    final player = ref.read(playerProvider).profile;
    if (player == null) {
      _showSnack('Oyuncu bilgisi yuklenemedi.');
      return;
    }

    final bool inHospital = (player.hospitalUntil ?? '').isNotEmpty;
    if (inHospital) {
      _showSnack('Hastanedeyken zindana giris yapilamaz.');
      return;
    }

    if (player.level < dungeon.requiredLevel) {
      _showSnack('Seviye yetersiz.');
      return;
    }

    if (player.energy < dungeon.energyCost) {
      _showSnack('Enerji yetersiz.');
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${dungeon.name} Operasyonu'),
        content: Text('${dungeon.energyCost} enerji harcanacak. Operasyon baslatilsin mi?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Baslat'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _entryPhase = 'Giris tuneli aciliyor...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() {
      _entryPhase = 'Savas simulasyonu baslatiliyor...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final result = await ref.read(dungeonProvider.notifier).enterDungeon(dungeonId: dungeon.dungeonId);
    if (mounted) {
      setState(() {
        _entryPhase = null;
      });
    }

    if (result == null) {
      final error = ref.read(dungeonProvider).errorMessage;
      _showSnack(_readableDungeonError(error));
      return;
    }

    if ((result.error ?? '').isNotEmpty) {
      final String mapped = _mapDungeonBusinessError(result.error!);
      if (mapped.contains('Hastanedeyken') && mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => _HospitalResultDialog(
            durationText: _formatHospitalDuration(
              result.hospitalUntil,
              fallbackSeconds: result.hospitalDurationSeconds,
            ),
            onGoHospital: () => context.go(AppRoutes.hospital),
          ),
        );
      } else {
        _showSnack(mapped);
      }
      return;
    }

    await ref.read(playerProvider.notifier).loadProfile();

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.success ? 'Operasyon Basarili' : 'Operasyon Sonucu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (result.success) ...<Widget>[
              Text(result.isCritical ? 'KRITIK ZAFER!' : 'Zindan temizlendi.'),
              const SizedBox(height: 6),
              Text('Altin: +${result.goldEarned}'),
              Text('XP: +${result.xpEarned}'),
              if (result.items.isNotEmpty) Text('Loot: ${result.items.take(3).join(', ')}'),
            ],
            if (result.hospitalized) const Text('Karakter hastaneye dustu.'),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );

    if (result.hospitalized && mounted) {
      showDialog<void>(
        context: context,
        builder: (context) => _HospitalResultDialog(
          durationText: _formatHospitalDuration(
            result.hospitalUntil,
            fallbackSeconds: result.hospitalDurationSeconds,
          ),
          onGoHospital: () => context.go(AppRoutes.hospital),
        ),
      );
    }
  }

  String _readableDungeonError(String? rawError) {
    final String normalized = (rawError ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'rpc error') {
      return 'Operasyon su anda tamamlanamadi. Kisa sure sonra tekrar dene.';
    }

    if (normalized.contains('failed to fetch') || normalized.contains('network')) {
      return 'Baglanti kurulamadi. Internetini kontrol edip tekrar dene.';
    }

    if (normalized.contains('timeout') || normalized.contains('zaman')) {
      return 'Istek zaman asimina ugradi. Birkac saniye sonra tekrar dene.';
    }

    return _mapDungeonBusinessError(rawError);
  }

  String _mapDungeonBusinessError(String? rawError) {
    final String error = (rawError ?? '').toLowerCase();
    if (error.contains('in_hospital')) return 'Hastanedeyken zindana giris yapilamaz.';
    if (error.contains('in_prison')) return 'Hapisteyken zindana giris yapilamaz.';
    if (error.contains('insufficient_energy')) return 'Enerjin yetersiz.';
    return (rawError ?? 'Operasyon su anda tamamlanamadi.').trim();
  }

  String _formatHospitalDuration(String? hospitalUntil, {int? fallbackSeconds}) {
    if (fallbackSeconds != null && fallbackSeconds > 0) {
      final int hours = fallbackSeconds ~/ 3600;
      final int mins = (fallbackSeconds % 3600) ~/ 60;
      if (hours <= 0) return '$mins dk';
      return '$hours sa $mins dk';
    }

    if (hospitalUntil == null || hospitalUntil.isEmpty) return 'Bilinmiyor';
    final DateTime? until = DateTime.tryParse(hospitalUntil)?.toLocal();
    if (until == null) return 'Bilinmiyor';
    final Duration diff = until.difference(DateTime.now());
    if (diff.isNegative) return '0 dk';
    final int hours = diff.inHours;
    final int mins = diff.inMinutes % 60;
    if (hours <= 0) return '$mins dk';
    return '$hours sa $mins dk';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final dungeonState = ref.watch(dungeonProvider);
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;

    final bool inHospital = (profile?.hospitalUntil ?? '').isNotEmpty;

    final List<DungeonData> modeFiltered = _mode == _DungeonMode.group
      ? dungeonState.dungeons
        .where((d) => d.maxPlayers > 1 || d.difficulty.toLowerCase().contains('dungeon'))
        .toList()
      : dungeonState.dungeons;

    final List<DungeonData> filtered = modeFiltered
      .where((d) =>
        d.name.toLowerCase().contains(_query.toLowerCase()) ||
        d.description.toLowerCase().contains(_query.toLowerCase()))
      .toList();

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Dungeon',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.dungeon),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF070B14), Color(0xFF0F172A), Color(0xFF111827)],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: () => ref.read(dungeonProvider.notifier).loadDungeons(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                _HeaderCard(
                  energy: profile?.energy ?? 0,
                  level: profile?.level ?? 1,
                  inHospital: inHospital,
                  totalDungeons: filtered.length,
                ),
                const SizedBox(height: 10),
                _ModeBar(
                  mode: _mode,
                  onChange: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Zindan ara...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                if (inHospital) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                      color: Colors.red.withValues(alpha: 0.12),
                    ),
                    child: const Text(
                      'Hastanedesin, zindana giris kilitli.',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (dungeonState.status == DungeonStatus.loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (dungeonState.status == DungeonStatus.error)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(dungeonState.errorMessage ?? 'Zindan listesi yuklenemedi.'),
                  )
                else if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Zindan bulunamadi.'),
                  )
                else
                  ...filtered.map((d) {
                    final bool canEnter =
                        !inHospital &&
                        (profile?.level ?? 0) >= d.requiredLevel &&
                        (profile?.energy ?? 0) >= d.energyCost;

                    final int successPct = _estimateSuccessPercent(
                      playerPower: profile?.power ?? 0,
                      playerLuck: profile?.luck ?? 0,
                      playerLevel: profile?.level ?? 1,
                      dungeon: d,
                    );

                    return _DungeonCard(
                      dungeon: d,
                      canEnter: canEnter,
                      entering: dungeonState.entering,
                      successPercent: successPct,
                      onEnter: () => _enterDungeon(d),
                      onLoot: () {
                        showDialog<void>(
                          context: context,
                          builder: (context) => _LootDialog(dungeon: d),
                        );
                      },
                    );
                  }),
              ],
            ),
          ),
          if (_entryPhase != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55)),
                child: Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                      color: const Color(0xE6111826),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 14),
                        const Text('Savas Akisi', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          _entryPhase!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _estimateSuccessPercent({
    required int playerPower,
    required int playerLuck,
    required int playerLevel,
    required DungeonData dungeon,
  }) {
    final int requirement = dungeon.powerRequirement ?? (dungeon.requiredLevel * 500);
    if (requirement <= 0) return 95;

    final double basePower = playerPower > 0 ? playerPower.toDouble() : (playerLevel * 500).toDouble();
    final double ratio = basePower / requirement;

    double score;
    if (ratio >= 1.5) {
      score = 0.95;
    } else if (ratio >= 1.0) {
      score = 0.7 + (ratio - 1.0) * 0.5;
    } else if (ratio >= 0.5) {
      score = 0.25 + (ratio - 0.5) * 0.9;
    } else {
      score = 0.08 + ratio * 0.34;
    }

    score += (playerLuck * 0.001);
    if (score < 0.05) score = 0.05;
    if (score > 0.95) score = 0.95;
    return (score * 100).round();
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.energy,
    required this.level,
    required this.inHospital,
    required this.totalDungeons,
  });

  final int energy;
  final int level;
  final bool inHospital;
  final int totalDungeons;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        color: Colors.black26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('ZINDAN OPERASYON MERKEZI', style: TextStyle(letterSpacing: 1.2, fontSize: 11)),
          const SizedBox(height: 4),
          Text('Toplam Bolge: $totalDungeons', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _chip('Enerji', '$energy'),
              _chip('Seviye', '$level'),
              _chip('Durum', inHospital ? 'Hastanede' : 'Hazir'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({
    required this.mode,
    required this.onChange,
  });

  final _DungeonMode mode;
  final ValueChanged<_DungeonMode> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.tonal(
            onPressed: () => onChange(_DungeonMode.solo),
            style: FilledButton.styleFrom(
              backgroundColor: mode == _DungeonMode.solo ? const Color(0xFFF97316) : null,
              foregroundColor: mode == _DungeonMode.solo ? Colors.black : null,
            ),
            child: const Text('Solo Operasyon'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonal(
            onPressed: () => onChange(_DungeonMode.group),
            style: FilledButton.styleFrom(
              backgroundColor: mode == _DungeonMode.group ? const Color(0xFF2DD4BF) : null,
              foregroundColor: mode == _DungeonMode.group ? Colors.black : null,
            ),
            child: const Text('Grup Baskini'),
          ),
        ),
      ],
    );
  }
}

class _DungeonCard extends StatelessWidget {
  const _DungeonCard({
    required this.dungeon,
    required this.canEnter,
    required this.entering,
    required this.successPercent,
    required this.onEnter,
    required this.onLoot,
  });

  final DungeonData dungeon;
  final bool canEnter;
  final bool entering;
  final int successPercent;
  final VoidCallback onEnter;
  final VoidCallback onLoot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: const Color(0xAA111827),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  dungeon.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              _difficultyBadge(dungeon.difficulty),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dungeon.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _meta('Seviye', '${dungeon.requiredLevel}'),
              _meta('Enerji', '${dungeon.energyCost}'),
              _meta('Altin', '${dungeon.minGold}-${dungeon.maxGold}'),
              _meta('Basari', '%$successPercent'),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: successPercent / 100,
              backgroundColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: onLoot,
                child: const Text('Loot'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: (!canEnter || entering) ? null : onEnter,
                  child: Text(canEnter ? 'Operasyonu Baslat' : 'Kosullar Uygun Degil'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white10,
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _difficultyBadge(String difficulty) {
    final lower = difficulty.toLowerCase();
    Color color = const Color(0xFF22C55E);
    String label = 'Kolay';
    if (lower == 'medium') {
      color = const Color(0xFFF59E0B);
      label = 'Orta';
    } else if (lower == 'hard') {
      color = const Color(0xFFEF4444);
      label = 'Zor';
    } else if (lower.contains('dungeon')) {
      color = const Color(0xFF6366F1);
      label = 'Boss';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _LootDialog extends StatelessWidget {
  const _LootDialog({required this.dungeon});

  final DungeonData dungeon;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${dungeon.name} • Loot Tablosu'),
      content: SizedBox(
        width: 360,
        child: dungeon.lootTable.isEmpty
            ? const Text('Bu zindan icin loot bilgisi bulunamadi.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Muhtemel Oduller', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...dungeon.lootTable.take(8).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: <Widget>[
                              const Text('• '),
                              Expanded(child: Text(item.replaceAll('_', ' '))),
                              _rarityChip(_inferRarity(item)),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }

  Widget _rarityChip(_LootRarity rarity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: rarity.color.withValues(alpha: 0.45)),
        color: rarity.color.withValues(alpha: 0.16),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(fontSize: 10, color: rarity.color, fontWeight: FontWeight.w700),
      ),
    );
  }

  _LootRarity _inferRarity(String token) {
    final String lower = token.toLowerCase();
    if (lower.endsWith('_mythic')) return _LootRarity('Mythic', const Color(0xFFF43F5E));
    if (lower.endsWith('_legendary')) return _LootRarity('Legendary', const Color(0xFFFBBF24));
    if (lower.endsWith('_epic')) return _LootRarity('Epic', const Color(0xFFF472B6));
    if (lower.endsWith('_rare')) return _LootRarity('Rare', const Color(0xFF38BDF8));
    if (lower.endsWith('_uncommon')) return _LootRarity('Uncommon', const Color(0xFF22C55E));
    return _LootRarity('Common', const Color(0xFF94A3B8));
  }
}

class _HospitalResultDialog extends StatelessWidget {
  const _HospitalResultDialog({
    required this.durationText,
    required this.onGoHospital,
  });

  final String durationText;
  final VoidCallback onGoHospital;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hastaneye Sevk Edildin'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Operasyon basarisiz oldu. Karakter agir yarali.'),
          const SizedBox(height: 10),
          Text('Tahmini Tedavi Suresi: $durationText', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onGoHospital();
          },
          child: const Text('Hastaneye Git'),
        ),
      ],
    );
  }
}

class _LootRarity {
  const _LootRarity(this.label, this.color);

  final String label;
  final Color color;
}
