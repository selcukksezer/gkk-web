import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class _Building {
  _Building({
    required this.id,
    required this.type,
    required this.name,
    required this.icon,
    required this.level,
    required this.maxLevel,
    required this.isBuilt,
    required this.resourceType,
    required this.resourceIcon,
    required this.capacity,
    required this.productionRate,
    required this.upgradeCostGold,
    required this.buildCostGold,
    required this.collectedAmount,
    this.lastCollectedAt,
  });
  final String id;
  final String type;
  final String name;
  final String icon;
  int level;
  final int maxLevel;
  bool isBuilt;
  final String resourceType;
  final String resourceIcon;
  final int capacity;
  final int productionRate;
  final int upgradeCostGold;
  final int buildCostGold;
  int collectedAmount;
  DateTime? lastCollectedAt;
}

List<_Building> _defaultBuildings() => <_Building>[
      _Building(id: 'mine', type: 'mine', name: 'Maden Ocağı', icon: '⛏️', level: 1, maxLevel: 10, isBuilt: true,
          resourceType: 'res_mining_common', resourceIcon: '⛏️', capacity: 100, productionRate: 10,
          upgradeCostGold: 5000, buildCostGold: 0, collectedAmount: 0, lastCollectedAt: DateTime.now().subtract(const Duration(hours: 2))),
      _Building(id: 'lumber', type: 'lumber', name: 'Kereste Ocağı', icon: '🪵', level: 1, maxLevel: 10, isBuilt: true,
          resourceType: 'res_lumber_common', resourceIcon: '🪵', capacity: 100, productionRate: 8,
          upgradeCostGold: 4000, buildCostGold: 0, collectedAmount: 0, lastCollectedAt: DateTime.now().subtract(const Duration(hours: 1))),
      _Building(id: 'alchemy', type: 'alchemy', name: 'Simya Laboratuvarı', icon: '⚗️', level: 0, maxLevel: 10, isBuilt: false,
          resourceType: 'res_herb_common', resourceIcon: '🌿', capacity: 80, productionRate: 5,
          upgradeCostGold: 6000, buildCostGold: 3000, collectedAmount: 0),
      _Building(id: 'blacksmith', type: 'blacksmith', name: 'Demirci Dükkanı', icon: '⚒️', level: 0, maxLevel: 10, isBuilt: false,
          resourceType: 'iron_ingot', resourceIcon: '🔩', capacity: 60, productionRate: 3,
          upgradeCostGold: 8000, buildCostGold: 5000, collectedAmount: 0),
      _Building(id: 'leatherwork', type: 'leatherwork', name: 'Deri İşlevi', icon: '🦌', level: 0, maxLevel: 10, isBuilt: false,
          resourceType: 'res_ranch_common', resourceIcon: '🐄', capacity: 80, productionRate: 6,
          upgradeCostGold: 5000, buildCostGold: 2500, collectedAmount: 0),
    ];

String _formatCost(int v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)},000';
  return '$v';
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class BuildingScreen extends ConsumerStatefulWidget {
  const BuildingScreen({super.key});

  @override
  ConsumerState<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends ConsumerState<BuildingScreen> {
  List<_Building> _buildings = <_Building>[];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dynamic result = await SupabaseService.client.rpc('get_buildings');
      if (result is List && result.isNotEmpty) {
        setState(() {
          _buildings = _defaultBuildings();
          _loading = false;
        });
        _tick();
        return;
      }
    } catch (_) {
      // fall through
    }
    setState(() {
      _buildings = _defaultBuildings();
      _loading = false;
    });
    _tick();
  }

  void _tick() {
    final DateTime now = DateTime.now();
    setState(() {
      for (final _Building b in _buildings) {
        if (b.isBuilt && b.lastCollectedAt != null) {
          final double hoursElapsed = now.difference(b.lastCollectedAt!).inMilliseconds / 3600000.0;
          final int produced = (b.productionRate * b.level * hoursElapsed).floor().clamp(0, b.capacity);
          b.collectedAmount = produced;
        }
      }
    });
  }

  Future<void> _collect(_Building b) async {
    try {
      await SupabaseService.client.rpc('collect_building_resources', params: <String, dynamic>{'p_building_type': b.type});
    } catch (_) {
      // ignore rpc error
    }
    final int amount = b.collectedAmount;
    setState(() {
      b.collectedAmount = 0;
      b.lastCollectedAt = DateTime.now();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$amount ${b.resourceType} toplandı!')));
    }
  }

  Future<void> _upgrade(_Building b) async {
    try {
      await SupabaseService.client.rpc('upgrade_building', params: <String, dynamic>{'p_building_type': b.type});
    } catch (_) {
      // ignore
    }
    setState(() => b.level++);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bina Lv.${b.level} yükseltildi!')));
    }
  }

  Future<void> _build(_Building b) async {
    try {
      await SupabaseService.client.rpc('build_building', params: <String, dynamic>{'p_building_type': b.type});
    } catch (_) {
      // ignore
    }
    setState(() {
      b.isBuilt = true;
      b.level = 1;
      b.lastCollectedAt = DateTime.now();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bina inşa edildi!')));
    }
  }

  // ─── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final int builtCount = _buildings.where((_Building b) => b.isBuilt).length;
    final int totalCapacity = _buildings.where((_Building b) => b.isBuilt).fold(0, (int sum, _Building b) => sum + b.capacity);
    final int totalRate = _buildings.where((_Building b) => b.isBuilt).fold(0, (int sum, _Building b) => sum + b.productionRate * b.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF111827),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _statCol('🏗️ İnşa', '$builtCount/${_buildings.length}'),
          _statCol('📦 Kapasite', '$totalCapacity'),
          _statCol('⚡ Üretim', '$totalRate/sa'),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value) => Column(
        children: <Widget>[
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF60A5FA))),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );

  Widget _buildBuildingCard(_Building b) {
    if (!b.isBuilt) return _buildUnbuiltCard(b);
    final double fillRatio = b.capacity > 0 ? (b.collectedAmount / b.capacity).clamp(0.0, 1.0) : 0;
    final bool full = b.collectedAmount >= b.capacity;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF111827),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(b.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                            border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.4)),
                          ),
                          child: const Text('Aktif', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    Text('Lv.${b.level}/${b.maxLevel}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text('${b.resourceIcon} ${b.collectedAmount}/${b.capacity}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text('${(fillRatio * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillRatio,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(full ? const Color(0xFFEF4444) : const Color(0xFF4ADE80)),
            ),
          ),
          if (full) ...<Widget>[
            const SizedBox(height: 6),
            const Text('⚠️ Kapasite dolu — kaynakları toplayın!', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: b.collectedAmount == 0 ? null : () => _collect(b),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF4ADE80)),
                    foregroundColor: const Color(0xFF4ADE80),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Topla', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: b.level >= b.maxLevel ? null : () => _upgrade(b),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF60A5FA)),
                    foregroundColor: const Color(0xFF60A5FA),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    b.level >= b.maxLevel ? 'Max Seviye' : '⬆️ Yükselt (🪙 ${_formatCost(b.upgradeCostGold)})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnbuiltCard(_Building b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Text(b.icon, style: const TextStyle(fontSize: 28, color: Colors.white38)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white54)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white12,
                      ),
                      child: const Text('İnşa edilmedi', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${b.resourceIcon} Üretim: ${b.productionRate}/sa  📦 Kapasite: ${b.capacity}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _build(b),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBBF24).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFFFBBF24),
              side: const BorderSide(color: Color(0xFFFBBF24)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: Text('🏗️ İnşa Et\n(🪙 ${_formatCost(b.buildCostGold)})', textAlign: TextAlign.center),
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
        title: 'Binalar',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.building),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const Text('Binalar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Kaynak üretim tesislerinizi yönetin', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  ..._buildings.map(_buildBuildingCard),
                ],
              ),
      ),
    );
  }
}
