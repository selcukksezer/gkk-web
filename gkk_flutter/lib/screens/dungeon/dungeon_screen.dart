import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/utils/power_formula.dart';
import '../../models/dungeon_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dungeon_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ─── Zone definitions ─────────────────────────────────────────────────────────

class _Zone {
  const _Zone({
    required this.number,
    required this.name,
    required this.color,
    required this.icon,
    required this.min,
    required this.max,
  });
  final int number;
  final String name;
  final Color color;
  final IconData icon;
  final int min;
  final int max;
}

const List<_Zone> _kZones = <_Zone>[
  _Zone(number: 1, name: 'Silva Obscura',     color: Color(0xFF4ADE80), icon: Icons.park,                   min: 1,  max: 10),
  _Zone(number: 2, name: 'Caverna Profunda',  color: Color(0xFF94A3B8), icon: Icons.terrain,                min: 11, max: 20),
  _Zone(number: 3, name: 'Desertum Ignis',    color: Color(0xFFF97316), icon: Icons.local_fire_department,  min: 21, max: 30),
  _Zone(number: 4, name: 'Mons Tempestatis',  color: Color(0xFF60A5FA), icon: Icons.thunderstorm,           min: 31, max: 40),
  _Zone(number: 5, name: 'Infernum Subterra', color: Color(0xFFEF4444), icon: Icons.whatshot,               min: 41, max: 50),
  _Zone(number: 6, name: 'Caelum Fractum',    color: Color(0xFFA78BFA), icon: Icons.cloud_queue,            min: 51, max: 60),
  _Zone(number: 7, name: 'Mythica Pericula',  color: Color(0xFFFBBF24), icon: Icons.auto_awesome,           min: 61, max: 65),
];

// ─── DungeonScreen ────────────────────────────────────────────────────────────

class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({super.key});

  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen>
    with SingleTickerProviderStateMixin {
  String _query = '';
  int _selectedZone = 0;
  String? _entryPhase;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kZones.length + 1, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedZone = _tabController.index == 0
              ? 0
              : _kZones[_tabController.index - 1].number;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(dungeonProvider.notifier).loadDungeons();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime? _parseRestrictionUntil(String? raw) {
    if (raw == null) return null;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final DateTime? parsed = DateTime.tryParse(trimmed) ??
        DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
    if (parsed == null) return null;

    if (parsed.isUtc) return parsed.toLocal();

    final bool hasTimezone = RegExp(
      r'(Z|[+\-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(trimmed);

    if (!hasTimezone) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      ).toLocal();
    }

    return parsed.toLocal();
  }

  bool _isRestricted(String? untilRaw) {
    final DateTime? until = _parseRestrictionUntil(untilRaw);
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  int _zoneFor(DungeonData d) {
    final RegExpMatch? match = RegExp(r'dng_0*(\d+)').firstMatch(d.dungeonId);
    if (match == null) return 0;
    final int num = int.tryParse(match.group(1)!) ?? 0;
    for (final _Zone z in _kZones) {
      if (num >= z.min && num <= z.max) return z.number;
    }
    return 0;
  }

  _Zone? _zoneDataFor(int number) {
    if (number == 0) return null;
    try {
      return _kZones.firstWhere((_Zone z) => z.number == number);
    } catch (_) {
      return null;
    }
  }

  Future<void> _enterDungeon(DungeonData dungeon) async {
    final player = ref.read(playerProvider).profile;
    if (player == null) {
      _showSnack('Oyuncu bilgisi yuklenemedi.');
      return;
    }
    if (_isRestricted(player.hospitalUntil)) {
      _showSnack('Hastanedeyken zindana giris yapilamaz.');
      return;
    }
    if (_isRestricted(player.prisonUntil)) {
      _showSnack('Hapisteyken zindana giris yapilamaz.');
      return;
    }
    if (player.energy < dungeon.energyCost) {
      _showSnack('Enerji yetersiz.');
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmEntryDialog(dungeon: dungeon),
    );
    if (confirm != true) return;

    setState(() => _entryPhase = 'Giris tuneli aciliyor...');
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() => _entryPhase = 'Savas simulasyonu baslatiliyor...');
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final DungeonResult? result = await ref
        .read(dungeonProvider.notifier)
        .enterDungeon(dungeonId: dungeon.dungeonId);

    if (mounted) setState(() => _entryPhase = null);

    if (result == null) {
      _showSnack(_readableDungeonError(ref.read(dungeonProvider).errorMessage));
      return;
    }

    if ((result.error ?? '').isNotEmpty) {
      final String mapped = _mapDungeonBusinessError(result.error!);
      if (mapped.contains('Hastanedeyken') && mounted) {
        await ref.read(playerProvider.notifier).loadProfile();
        if (!mounted) return;
        final String? profileHospitalUntil = ref.read(playerProvider).profile?.hospitalUntil;
        showDialog<void>(
          context: context,
          builder: (context) => _HospitalResultDialog(
            durationText: _formatHospitalDuration(
              result.hospitalUntil ?? profileHospitalUntil,
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
      builder: (context) => _ResultDialog(result: result, dungeon: dungeon),
    );

    if (result.hospitalized && mounted) {
      final String? profileHospitalUntil = ref.read(playerProvider).profile?.hospitalUntil;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => _HospitalResultDialog(
            durationText: _formatHospitalDuration(
              result.hospitalUntil ?? profileHospitalUntil,
              fallbackSeconds: result.hospitalDurationSeconds,
            ),
            onGoHospital: () => context.go(AppRoutes.hospital),
          ),
        );
      }
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
    if (error.contains('dungeon_not_found')) return 'Zindan bulunamadi. Listeyi yenileyip tekrar dene.';
    if (error.contains('player_not_found')) return 'Oyuncu kaydi bulunamadi. Oturumu yenileyip tekrar dene.';
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
    final DateTime? until = _parseRestrictionUntil(hospitalUntil);
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
    final playerState  = ref.watch(playerProvider);
    final inventoryState = ref.watch(inventoryProvider);
    final profile = playerState.profile;

    final bool inHospital  = _isRestricted(profile?.hospitalUntil);
    final bool inPrison    = _isRestricted(profile?.prisonUntil);
    final bool isRestricted = inHospital || inPrison;

    final PowerBreakdown? powerBreakdown = profile != null
        ? calculateTotalPower(
            player: profile,
            equippedItems: inventoryState.equippedItems.values,
          )
        : null;
    final int playerTotalPower = powerBreakdown?.totalPower ?? 0;

    final List<DungeonData> zoneFiltered = _selectedZone == 0
        ? dungeonState.dungeons
        : dungeonState.dungeons
            .where((DungeonData d) => _zoneFor(d) == _selectedZone)
            .toList();

    final List<DungeonData> filtered = zoneFiltered
        .where((DungeonData d) =>
            _query.isEmpty ||
            d.name.toLowerCase().contains(_query.toLowerCase()) ||
            d.description.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    final _Zone? currentZone = _zoneDataFor(_selectedZone);

    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Zindan',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.dungeon),
      body: Stack(
        children: <Widget>[
          // Atmospheric zone-tinted background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    const Color(0xFF080B12),
                    currentZone != null
                        ? Color.fromRGBO(
                            currentZone.color.red,
                            currentZone.color.green,
                            currentZone.color.blue,
                            0.04,
                          )
                        : const Color(0xFF0C1020),
                    const Color(0xFF080B12),
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: <Widget>[
              // Player status strip
              _PlayerStatusStrip(
                power: playerTotalPower,
                energy: profile?.energy ?? 0,
                level: profile?.level ?? 1,
                inHospital: inHospital,
                inPrison: inPrison,
              ),

              // Zone tabs
              _ZoneTabBar(
                controller: _tabController,
                dungeons: dungeonState.dungeons,
                zoneFor: _zoneFor,
              ),

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (String v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 13, color: Color(0xFFD0D8F0)),
                    decoration: InputDecoration(
                      hintText: 'Zindan ara...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF4A5880)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF4A5880)),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: const Color(0xFF0E1525),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1E2D50)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3A5090)),
                      ),
                    ),
                  ),
                ),
              ),

              // Zone banner
              if (currentZone != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: _ZoneBanner(zone: currentZone, dungeonCount: filtered.length),
                ),

              // Restriction warning
              if (isRestricted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: _RestrictionBanner(inHospital: inHospital),
                ),

              const SizedBox(height: 8),

              // Dungeon list
              Expanded(
                child: dungeonState.status == DungeonStatus.loading
                    ? const _LoadingShimmer()
                    : dungeonState.status == DungeonStatus.error
                        ? _ErrorState(
                            message: dungeonState.errorMessage,
                            onRetry: () => ref.read(dungeonProvider.notifier).loadDungeons(),
                          )
                        : filtered.isEmpty
                            ? const _EmptyState()
                            : RefreshIndicator(
                                onRefresh: () => ref.read(dungeonProvider.notifier).loadDungeons(),
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                                  itemCount: filtered.length,
                                  itemBuilder: (BuildContext ctx, int i) {
                                    final DungeonData d = filtered[i];
                                    final int zoneNum  = _zoneFor(d);
                                    final _Zone? zData = _zoneDataFor(zoneNum);
                                    final bool canEnter = !isRestricted &&
                                        profile != null &&
                                        profile.energy >= d.energyCost;
                                    final int req = d.powerRequirement ?? (d.requiredLevel * 500);
                                    final int successPct;
                                    String? debugText;
                                    if (profile != null && powerBreakdown != null) {
                                      successPct = (calculateDungeonSuccessRate(
                                            playerTotalPower: playerTotalPower,
                                            dungeonPowerRequirement: req,
                                            playerLuck: profile.luck ?? 0,
                                            reputation: profile.reputation ?? 0,
                                            characterClass: profile.characterClass,
                                          ) *
                                          100)
                                          .round();
                                      debugText = kDebugMode
                                          ? 'pwr:$playerTotalPower eq:${powerBreakdown.equipmentPower} req:$req'
                                          : null;
                                    } else {
                                      successPct = 5;
                                      debugText = kDebugMode ? 'no profile' : null;
                                    }

                                    return _DungeonCard(
                                      dungeon: d,
                                      zone: zData,
                                      canEnter: canEnter,
                                      inHospital: inHospital,
                                      inPrison: inPrison,
                                      entering: dungeonState.entering,
                                      successPercent: successPct,
                                      playerPower: playerTotalPower,
                                      powerRequirement: req,
                                      debugText: debugText,
                                      onEnter: () => _enterDungeon(d),
                                      onLoot: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => _LootDialog(dungeon: d, zone: zData),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),

          // Entry phase overlay
          if (_entryPhase != null) _EntryOverlay(phase: _entryPhase!),
        ],
      ),
    );
  }
}

// ─── Player Status Strip ──────────────────────────────────────────────────────

class _PlayerStatusStrip extends StatelessWidget {
  const _PlayerStatusStrip({
    required this.power,
    required this.energy,
    required this.level,
    required this.inHospital,
    required this.inPrison,
  });

  final int power;
  final int energy;
  final int level;
  final bool inHospital;
  final bool inPrison;

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0D1525),
        border: Border.all(color: const Color(0xFF1E2D50)),
      ),
      child: Row(
        children: <Widget>[
          _stat(Icons.bolt,             '$energy',   const Color(0xFF60A5FA), 'ENERJ'),
          const SizedBox(width: 14),
          _stat(Icons.shield_outlined,  '$level',    const Color(0xFF4ADE80), 'SEVYE'),
          const SizedBox(width: 14),
          _stat(Icons.local_fire_department, _fmt(power), const Color(0xFFF5C842), 'GÜÇ'),
          const Spacer(),
          _statusBadge(),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, Color color, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        Text(label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF4A5880), letterSpacing: 0.5)),
      ],
    );
  }

  Widget _statusBadge() {
    if (!inHospital && !inPrison) {
      return _badge(Icons.check_circle_outline, 'Hazır', const Color(0xFF22C55E));
    }
    return _badge(
      inHospital ? Icons.local_hospital : Icons.lock,
      inHospital ? 'Hastane' : 'Hapis',
      inHospital ? const Color(0xFFEF4444) : const Color(0xFFF97316),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── Zone Tab Bar ─────────────────────────────────────────────────────────────

class _ZoneTabBar extends StatelessWidget {
  const _ZoneTabBar({
    required this.controller,
    required this.dungeons,
    required this.zoneFor,
  });

  final TabController controller;
  final List<DungeonData> dungeons;
  final int Function(DungeonData) zoneFor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF1A2540),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        labelColor: const Color(0xFFF0F4FF),
        unselectedLabelColor: const Color(0xFF4A5880),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        tabs: <Widget>[
          const Tab(text: 'Tümü'),
          ..._kZones.map((_Zone z) {
            final int count = dungeons.where((DungeonData d) => zoneFor(d) == z.number).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(z.icon, size: 12, color: z.color),
                  const SizedBox(width: 4),
                  Text('B${z.number}'),
                  if (count > 0) ...<Widget>[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: z.color.withOpacity(0.2),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(fontSize: 9, color: z.color, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Zone Banner ─────────────────────────────────────────────────────────────

class _ZoneBanner extends StatelessWidget {
  const _ZoneBanner({required this.zone, required this.dungeonCount});
  final _Zone zone;
  final int dungeonCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: zone.color.withOpacity(0.07),
        border: Border.all(color: zone.color.withOpacity(0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(zone.icon, size: 18, color: zone.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(zone.name,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: zone.color)),
                Text(
                  'Bölge ${zone.number}  •  $dungeonCount zindan  •  #${zone.min}–${zone.max}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5060A0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Restriction Banner ──────────────────────────────────────────────────────

class _RestrictionBanner extends StatelessWidget {
  const _RestrictionBanner({required this.inHospital});
  final bool inHospital;

  @override
  Widget build(BuildContext context) {
    final Color c = inHospital ? const Color(0xFFEF4444) : const Color(0xFFF97316);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: c.withOpacity(0.08),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(inHospital ? Icons.local_hospital : Icons.lock, size: 15, color: c),
          const SizedBox(width: 8),
          Text(
            inHospital
                ? 'Hastanedeyken zindana giris yapilamaz.'
                : 'Hapisteyken zindana giris yapilamaz.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}

// ─── Dungeon Card ─────────────────────────────────────────────────────────────

class _DungeonCard extends StatelessWidget {
  const _DungeonCard({
    required this.dungeon,
    required this.zone,
    required this.canEnter,
    required this.inHospital,
    required this.inPrison,
    required this.entering,
    required this.successPercent,
    required this.playerPower,
    required this.powerRequirement,
    this.debugText,
    required this.onEnter,
    required this.onLoot,
  });

  final DungeonData dungeon;
  final _Zone? zone;
  final bool canEnter;
  final bool inHospital;
  final bool inPrison;
  final bool entering;
  final int successPercent;
  final int playerPower;
  final int powerRequirement;
  final String? debugText;
  final VoidCallback onEnter;
  final VoidCallback onLoot;

  bool get _isBoss => dungeon.difficulty.toLowerCase().contains('dungeon');

  Color get _threatColor {
    if (_isBoss) return const Color(0xFF6366F1);
    if (successPercent >= 80) return const Color(0xFF22C55E);
    if (successPercent >= 55) return const Color(0xFFF59E0B);
    if (successPercent >= 30) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String get _threatLabel {
    if (_isBoss) return 'BOSS';
    if (successPercent >= 80) return 'KOLAY';
    if (successPercent >= 55) return 'ORTA';
    if (successPercent >= 30) return 'ZOR';
    return 'ÖLÜMCÜL';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = zone?.color ?? const Color(0xFF5B8FFF);
    final Color threat = _threatColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0D1525),
        border: Border.all(color: const Color(0xFF1A2540)),
        boxShadow: _isBoss
            ? <BoxShadow>[
                BoxShadow(
                  color: threat.withOpacity(0.12),
                  blurRadius: 18,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Left zone accent bar
              Container(width: 4, color: accent),

              // Card body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Header row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Zone + threat badges
                                Row(
                                  children: <Widget>[
                                    if (zone != null) ...<Widget>[
                                      Icon(zone!.icon, size: 11,
                                          color: zone!.color.withOpacity(0.75)),
                                      const SizedBox(width: 4),
                                      Text(
                                        zone!.name.split(' ')[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: zone!.color.withOpacity(0.75),
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: threat.withOpacity(0.15),
                                        border: Border.all(
                                            color: threat.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        _threatLabel,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: threat,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  dungeon.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFE8EDF8),
                                    height: 1.2,
                                  ),
                                ),
                                if (dungeon.description.isNotEmpty)
                                  Text(
                                    dungeon.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF4A5880),
                                      height: 1.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Success ring
                          _SuccessRing(percent: successPercent, color: threat),
                        ],
                      ),

                      if (kDebugMode && debugText != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(debugText!,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF3A5080))),
                      ],

                      const SizedBox(height: 10),

                      // Stats chips
                      _StatsRow(
                        energyCost: dungeon.energyCost,
                        minGold: dungeon.minGold,
                        maxGold: dungeon.maxGold,
                        powerReq: powerRequirement,
                      ),

                      // Power comparison bar
                      if (powerRequirement > 0) ...<Widget>[
                        const SizedBox(height: 10),
                        _PowerBar(
                          playerPower: playerPower,
                          required: powerRequirement,
                          threat: threat,
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Action buttons
                      Row(
                        children: <Widget>[
                          _LootButton(accent: accent, onTap: onLoot),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _EnterButton(
                              canEnter: canEnter,
                              entering: entering,
                              inHospital: inHospital,
                              inPrison: inPrison,
                              color: threat,
                              onEnter: onEnter,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Success Ring ─────────────────────────────────────────────────────────────

class _SuccessRingPainter extends CustomPainter {
  const _SuccessRingPainter({required this.percent, required this.color});
  final double percent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 3;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    if (percent > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * (percent / 100),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SuccessRingPainter old) =>
      old.percent != percent || old.color != color;
}

class _SuccessRing extends StatelessWidget {
  const _SuccessRing({required this.percent, required this.color});
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size(52, 52),
            painter: _SuccessRingPainter(
              percent: percent.toDouble(),
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$percent',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              const Text('%',
                  style: TextStyle(fontSize: 8, color: Color(0xFF4A5880), height: 1)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.energyCost,
    required this.minGold,
    required this.maxGold,
    required this.powerReq,
  });
  final int energyCost;
  final int minGold;
  final int maxGold;
  final int powerReq;

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        _chip(Icons.bolt, '${energyCost}E', const Color(0xFF60A5FA)),
        _chip(Icons.monetization_on_outlined,
            '${_fmt(minGold)}-${_fmt(maxGold)}G', const Color(0xFFF5C842)),
        if (powerReq > 0)
          _chip(Icons.security, _fmt(powerReq), const Color(0xFF94A3B8)),
      ],
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─── Power Bar ────────────────────────────────────────────────────────────────

class _PowerBar extends StatelessWidget {
  const _PowerBar({
    required this.playerPower,
    required this.required,
    required this.threat,
  });
  final int playerPower;
  final int required;
  final Color threat;

  @override
  Widget build(BuildContext context) {
    final double ratio =
        required > 0 ? (playerPower / required).clamp(0.0, 2.0) : 1.0;
    final double displayRatio = (ratio / 2).clamp(0.0, 1.0);
    final bool ok = ratio >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('GÜÇ KARŞILAŞTIRMA',
                style: TextStyle(
                    fontSize: 9, color: Color(0xFF3A5080), letterSpacing: 0.5)),
            const Spacer(),
            Text(
              ok ? 'YETERL' : 'YETERSZ',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: displayRatio,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(
                ok ? const Color(0xFF22C55E) : threat),
          ),
        ),
      ],
    );
  }
}

// ─── Loot Button ──────────────────────────────────────────────────────────────

class _LootButton extends StatelessWidget {
  const _LootButton({required this.accent, required this.onTap});
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: accent.withOpacity(0.1),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inventory_2_outlined, size: 14, color: accent),
            const SizedBox(width: 5),
            Text('Loot',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
          ],
        ),
      ),
    );
  }
}

// ─── Enter Button ─────────────────────────────────────────────────────────────

class _EnterButton extends StatelessWidget {
  const _EnterButton({
    required this.canEnter,
    required this.entering,
    required this.inHospital,
    required this.inPrison,
    required this.color,
    required this.onEnter,
  });
  final bool canEnter;
  final bool entering;
  final bool inHospital;
  final bool inPrison;
  final Color color;
  final VoidCallback onEnter;

  String get _label {
    if (entering) return 'Girilyor...';
    if (inHospital) return 'Hastane Kilidi';
    if (inPrison) return 'Hapis Kilidi';
    if (!canEnter) return 'Enerji Yetersiz';
    return 'Zindana Gir';
  }

  @override
  Widget build(BuildContext context) {
    final bool active = canEnter && !entering;
    return GestureDetector(
      onTap: active ? onEnter : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? color.withOpacity(0.88) : const Color(0xFF111A2A),
          border: Border.all(
              color: active ? color : const Color(0xFF1E2D50)),
        ),
        child: Center(
          child: entering
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      active ? Icons.play_arrow_rounded : Icons.lock_outline,
                      size: 15,
                      color: active ? Colors.black : const Color(0xFF3A5080),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.black : const Color(0xFF3A5080),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Loading Shimmer ──────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      itemCount: 5,
      itemBuilder: (_, int i) => Container(
        height: 160,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0D1525),
          border: Border.all(color: const Color(0xFF1A2540)),
        ),
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 44, color: Color(0xFF3A5080)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Zindan listesi yuklenemedi.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF4A5880)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_off, size: 44, color: Color(0xFF2A3A60)),
          SizedBox(height: 10),
          Text('Zindan bulunamadı.',
              style: TextStyle(color: Color(0xFF3A5080))),
        ],
      ),
    );
  }
}

// ─── Entry Overlay ────────────────────────────────────────────────────────────

class _EntryOverlay extends StatelessWidget {
  const _EntryOverlay({required this.phase});
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.72)),
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF0D1525),
              border: Border.all(color: const Color(0xFF253154)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFF5C842)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SAVAŞ AKIŞI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A5880),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phase,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6878A8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Confirm Entry Dialog ─────────────────────────────────────────────────────

class _ConfirmEntryDialog extends StatelessWidget {
  const _ConfirmEntryDialog({required this.dungeon});
  final DungeonData dungeon;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D1525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E2D50)),
      ),
      title: Text(
        dungeon.name,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFE8EDF8)),
      ),
      content: Text(
        '${dungeon.energyCost} enerji harcanacak.\nOperasyonu başlatmak istiyor musun?',
        style: const TextStyle(color: Color(0xFF6070A0)),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ptal', style: TextStyle(color: Color(0xFF4A5880))),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF5C842),
            foregroundColor: Colors.black,
          ),
          child: const Text('Gir', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

// ─── Result Dialog ────────────────────────────────────────────────────────────

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.result, required this.dungeon});
  final DungeonResult result;
  final DungeonData dungeon;

  @override
  Widget build(BuildContext context) {
    final bool ok = result.success;
    final bool crit = result.isCritical;
    final Color accent = ok
        ? (crit ? const Color(0xFFF5C842) : const Color(0xFF22C55E))
        : const Color(0xFFEF4444);

    return AlertDialog(
      backgroundColor: const Color(0xFF0D1525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withOpacity(0.3)),
      ),
      title: Row(
        children: <Widget>[
          Icon(
            ok ? (crit ? Icons.star_rounded : Icons.check_circle_outline) : Icons.cancel_outlined,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              crit ? 'KRTK ZAFER!' : (ok ? 'Zindan Temizlendi' : 'Başarısız'),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: accent),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(dungeon.name,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A5880))),
          const SizedBox(height: 10),
          if (result.goldEarned > 0)
            _row(Icons.monetization_on_outlined,
                '+${result.goldEarned} Altın', const Color(0xFFF5C842)),
          if (result.xpEarned > 0)
            _row(Icons.arrow_upward_rounded,
                '+${result.xpEarned} XP', const Color(0xFF60A5FA)),
          if (result.items.isNotEmpty)
            _row(Icons.inventory_2_outlined,
                result.items.take(3).join(', '), const Color(0xFFA78BFA)),
          if (result.hospitalized)
            _row(Icons.local_hospital,
                'Hastaneye düştün', const Color(0xFFEF4444)),
        ],
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
              backgroundColor: accent, foregroundColor: Colors.black),
          child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Hospital Result Dialog ───────────────────────────────────────────────────

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
      backgroundColor: const Color(0xFF0D1525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x55EF4444)),
      ),
      title: const Row(
        children: <Widget>[
          Icon(Icons.local_hospital, size: 20, color: Color(0xFFEF4444)),
          SizedBox(width: 8),
          Text('Hastaneye Düştün',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEF4444))),
        ],
      ),
      content: Text(
        'yileşme süresi: $durationText',
        style: const TextStyle(color: Color(0xFF6070A0)),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              const Text('Kapat', style: TextStyle(color: Color(0xFF4A5880))),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onGoHospital();
          },
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white),
          child: const Text('Hastaneye Git',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Loot Dialog ──────────────────────────────────────────────────────────────

class _LootRarity {
  const _LootRarity(this.label, this.color);
  final String label;
  final Color color;
}

class _LootDialog extends StatelessWidget {
  const _LootDialog({required this.dungeon, this.zone});
  final DungeonData dungeon;
  final _Zone? zone;

  String _fmtGold(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return '$value';
  }

  _LootRarity _inferRarity(String token) {
    final String lower = token.toLowerCase();
    if (lower.contains('mythic'))    return const _LootRarity('Mythic',    Color(0xFFF43F5E));
    if (lower.contains('legendary')) return const _LootRarity('Legendary', Color(0xFFFBBF24));
    if (lower.contains('epic'))      return const _LootRarity('Epic',      Color(0xFFA78BFA));
    if (lower.contains('rare'))      return const _LootRarity('Rare',      Color(0xFF60A5FA));
    if (lower.contains('uncommon'))  return const _LootRarity('Uncommon',  Color(0xFF22C55E));
    return const _LootRarity('Common', Color(0xFF6B7A99));
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = zone?.color ?? const Color(0xFF5B8FFF);
    return AlertDialog(
      backgroundColor: const Color(0xFF0D1525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withOpacity(0.3)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(dungeon.name,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE8EDF8))),
          Text('Loot Tablosu',
              style: TextStyle(fontSize: 11, color: accent.withOpacity(0.8))),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFF5C842).withOpacity(0.10),
                border: Border.all(color: const Color(0xFFF5C842).withOpacity(0.30)),
              ),
              child: Text(
                'Altin Araligi: ${_fmtGold(dungeon.minGold)} - ${_fmtGold(dungeon.maxGold)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFF5C842),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            dungeon.lootTable.isEmpty
                ? const Text('Bu zindan için loot bilgisi bulunamadı.',
                    style: TextStyle(color: Color(0xFF4A5880)))
                : Column(
                mainAxisSize: MainAxisSize.min,
                children: dungeon.lootTable.take(8).map((String item) {
                  final _LootRarity rarity = _inferRarity(item);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 3,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          color: rarity.color.withOpacity(0.7),
                        ),
                        Expanded(
                          child: Text(
                            item.replaceAll('_', ' '),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFCCD4F0)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: rarity.color.withOpacity(0.12),
                            border: Border.all(
                                color: rarity.color.withOpacity(0.35)),
                          ),
                          child: Text(rarity.label,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: rarity.color,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
              backgroundColor: accent, foregroundColor: Colors.black),
          child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}