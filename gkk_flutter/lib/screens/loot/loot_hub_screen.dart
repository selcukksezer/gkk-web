import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class _LootBoxView {
  const _LootBoxView({
    required this.id,
    required this.name,
    required this.description,
    required this.currencyType,
    required this.price,
    required this.dropCount,
    required this.jackpotRate,
    required this.rewardMultiplier,
    required this.artAsset,
  });

  final String id;
  final String name;
  final String description;
  final String currencyType;
  final int price;
  final int dropCount;
  final double jackpotRate;
  final double rewardMultiplier;
  final String artAsset;

  factory _LootBoxView.fromMap(Map<String, dynamic> map) {
    return _LootBoxView(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Kasa',
      description: map['description']?.toString() ?? '',
      currencyType: map['currency_type']?.toString() ?? 'gold',
      price: _toInt(map['price']),
      dropCount: _toInt(map['drop_count']),
      jackpotRate: _toDouble(map['jackpot_rate']),
      rewardMultiplier: _toDouble(map['reward_multiplier'], fallback: 1.0),
      artAsset: map['art_asset']?.toString() ?? '',
    );
  }
}

class _LootDropView {
  const _LootDropView({
    required this.itemId,
    required this.itemName,
    required this.icon,
    required this.rarity,
    required this.dropRate,
    required this.minQuantity,
    required this.maxQuantity,
  });

  final String itemId;
  final String itemName;
  final String icon;
  final String rarity;
  final double dropRate;
  final int minQuantity;
  final int maxQuantity;

  factory _LootDropView.fromMap(Map<String, dynamic> map) {
    return _LootDropView(
      itemId: map['item_id']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? 'Item',
      icon: map['icon']?.toString() ?? '',
      rarity: map['rarity']?.toString() ?? 'common',
      dropRate: _toDouble(map['drop_rate']),
      minQuantity: _toInt(map['min_quantity'], fallback: 1),
      maxQuantity: _toInt(map['max_quantity'], fallback: 1),
    );
  }
}

class _WheelView {
  const _WheelView({
    required this.id,
    required this.name,
    required this.description,
    required this.currencyType,
    required this.price,
    required this.dailyLimit,
    required this.rewardCount,
    required this.jackpotRate,
  });

  final String id;
  final String name;
  final String description;
  final String currencyType;
  final int price;
  final int? dailyLimit;
  final int rewardCount;
  final double jackpotRate;

  factory _WheelView.fromMap(Map<String, dynamic> map) {
    return _WheelView(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Cark',
      description: map['description']?.toString() ?? '',
      currencyType: map['currency_type']?.toString() ?? 'gold',
      price: _toInt(map['price']),
      dailyLimit: map['daily_limit'] == null ? null : _toInt(map['daily_limit']),
      rewardCount: _toInt(map['reward_count']),
      jackpotRate: _toDouble(map['jackpot_rate']),
    );
  }
}

class _WheelRewardView {
  const _WheelRewardView({
    required this.rewardType,
    required this.itemId,
    required this.itemName,
    required this.icon,
    required this.rarity,
    required this.minAmount,
    required this.maxAmount,
    required this.dropRate,
    required this.isJackpot,
    required this.label,
  });

  final String rewardType;
  final String? itemId;
  final String itemName;
  final String icon;
  final String rarity;
  final int minAmount;
  final int maxAmount;
  final double dropRate;
  final bool isJackpot;
  final String label;

  factory _WheelRewardView.fromMap(Map<String, dynamic> map) {
    return _WheelRewardView(
      rewardType: map['reward_type']?.toString() ?? 'item',
      itemId: map['item_id']?.toString(),
      itemName: map['item_name']?.toString() ?? 'Odul',
      icon: map['icon']?.toString() ?? '',
      rarity: map['rarity']?.toString() ?? 'common',
      minAmount: _toInt(map['amount_min'], fallback: 1),
      maxAmount: _toInt(map['amount_max'], fallback: 1),
      dropRate: _toDouble(map['drop_rate']),
      isJackpot: map['is_jackpot'] == true,
      label: map['reward_label']?.toString() ?? '',
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

List<Map<String, dynamic>> _rowsFromRpc(dynamic payload) {
  final dynamic rows = payload is Map<String, dynamic>
      ? (payload['data'] ?? const <dynamic>[])
      : payload;

  if (rows is! List) return <Map<String, dynamic>>[];

  return rows
      .whereType<Map>()
      .map((Map row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

String _compactNum(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
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

IconData _currencyIcon(String currency) {
  return currency == 'gems' ? Icons.diamond : Icons.paid;
}

Color _currencyColor(String currency) {
  return currency == 'gems' ? const Color(0xFF22D3EE) : const Color(0xFFFBBF24);
}

class LootHubScreen extends ConsumerStatefulWidget {
  const LootHubScreen({super.key});

  @override
  ConsumerState<LootHubScreen> createState() => _LootHubScreenState();
}

class _LootHubScreenState extends ConsumerState<LootHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _error;

  List<_LootBoxView> _boxes = <_LootBoxView>[];
  List<_WheelView> _wheels = <_WheelView>[];

  final Map<String, List<_LootDropView>> _boxDrops = <String, List<_LootDropView>>{};
  final Map<String, List<_WheelRewardView>> _wheelRewards =
      <String, List<_WheelRewardView>>{};

  final Set<String> _loadingDropIds = <String>{};
  final Set<String> _loadingWheelIds = <String>{};

  String? _openingBoxId;
  String? _spinningWheelId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<dynamic> responses = await Future.wait<dynamic>(<Future<dynamic>>[
        SupabaseService.client.rpc('get_loot_boxes_with_stats'),
        SupabaseService.client.rpc('get_spin_wheels_with_stats'),
      ]);

      final List<_LootBoxView> boxes = _rowsFromRpc(responses[0])
          .map(_LootBoxView.fromMap)
          .where((b) => b.id.isNotEmpty)
          .toList(growable: false);

      final List<_WheelView> wheels = _rowsFromRpc(responses[1])
          .map(_WheelView.fromMap)
          .where((w) => w.id.isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _boxes = boxes;
        _wheels = wheels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadBoxDrops(String boxId) async {
    if (boxId.isEmpty || _loadingDropIds.contains(boxId) || _boxDrops.containsKey(boxId)) {
      return;
    }

    setState(() => _loadingDropIds.add(boxId));
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_loot_box_drops',
        params: <String, dynamic>{'p_box_id': boxId},
      );

      final List<_LootDropView> rows = _rowsFromRpc(raw)
          .map(_LootDropView.fromMap)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _boxDrops[boxId] = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _boxDrops[boxId] = <_LootDropView>[];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingDropIds.remove(boxId));
      }
    }
  }

  Future<void> _loadWheelRewards(String wheelId) async {
    if (wheelId.isEmpty || _loadingWheelIds.contains(wheelId) || _wheelRewards.containsKey(wheelId)) {
      return;
    }

    setState(() => _loadingWheelIds.add(wheelId));
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_spin_wheel_rewards',
        params: <String, dynamic>{'p_wheel_id': wheelId},
      );

      final List<_WheelRewardView> rows = _rowsFromRpc(raw)
          .map(_WheelRewardView.fromMap)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _wheelRewards[wheelId] = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _wheelRewards[wheelId] = <_WheelRewardView>[];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingWheelIds.remove(wheelId));
      }
    }
  }

  Future<void> _openBox(_LootBoxView box) async {
    if (_openingBoxId != null) return;

    setState(() => _openingBoxId = box.id);
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'open_loot_box',
        params: <String, dynamic>{'p_box_id': box.id},
      );

      final Map<String, dynamic> data = raw is Map
          ? Map<String, dynamic>.from(raw as Map)
          : <String, dynamic>{'success': false, 'message': 'Gecersiz yanit'};

      final bool success = data['success'] == true;
      final String message = data['message']?.toString() ?? '';

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.isEmpty ? 'Kasa acma basarisiz.' : message)),
        );
      } else {
        await Future.wait<void>(<Future<void>>[
          ref.read(playerProvider.notifier).loadProfile(),
          ref.read(inventoryProvider.notifier).loadInventory(silent: true),
        ]);
        _showRewardDialog(data, title: 'Kasa Acildi');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kasa acilirken hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _openingBoxId = null);
    }
  }

  Future<void> _spinWheel(_WheelView wheel) async {
    if (_spinningWheelId != null) return;

    setState(() => _spinningWheelId = wheel.id);
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'spin_wheel',
        params: <String, dynamic>{'p_wheel_id': wheel.id},
      );

      final Map<String, dynamic> data = raw is Map
          ? Map<String, dynamic>.from(raw as Map)
          : <String, dynamic>{'success': false, 'message': 'Gecersiz yanit'};

      final bool success = data['success'] == true;
      final String message = data['message']?.toString() ?? '';

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.isEmpty ? 'Cark cevirme basarisiz.' : message)),
        );
      } else {
        await Future.wait<void>(<Future<void>>[
          ref.read(playerProvider.notifier).loadProfile(),
          ref.read(inventoryProvider.notifier).loadInventory(silent: true),
        ]);
        _showRewardDialog(data, title: 'Cark Sonucu');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cark cevirilirken hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _spinningWheelId = null);
    }
  }

  void _showRewardDialog(Map<String, dynamic> payload, {required String title}) {
    final Map<String, dynamic> reward = payload['reward'] is Map
        ? Map<String, dynamic>.from(payload['reward'] as Map)
        : <String, dynamic>{};

    final String type = reward['type']?.toString() ?? 'item';
    final String name = reward['name']?.toString() ?? 'Odul';
    final String icon = reward['icon']?.toString() ?? '';
    final int qty = _toInt(reward['quantity'], fallback: _toInt(reward['amount'], fallback: 1));

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1320),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: type == 'item'
                    ? ItemIconView(
                        iconValue: icon,
                        itemId: reward['item_id']?.toString(),
                        itemType: ItemType.material,
                        size: 58,
                        expand: true,
                        fallback: '◻',
                      )
                    : Icon(
                        type == 'gems' ? Icons.diamond : Icons.paid,
                        color: type == 'gems'
                            ? const Color(0xFF22D3EE)
                            : const Color(0xFFFBBF24),
                        size: 36,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Miktar: $qty',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Kasa & Cark',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.shop),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF070B14), Color(0xFF030509)],
          ),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _balanceStat('Gold', _compactNum(profile?.gold ?? 0), Icons.paid, const Color(0xFFFBBF24)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _balanceStat('Elmas', _compactNum(profile?.gems ?? 0), Icons.diamond, const Color(0xFF22D3EE)),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFFB800),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const <Tab>[
                  Tab(text: 'Kasa Acma'),
                  Tab(text: 'Cark Cevirme'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            'Yukleme hatasi:\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: <Widget>[
                            _buildBoxesTab(),
                            _buildWheelsTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxesTab() {
    if (_boxes.isEmpty) {
      return const Center(
        child: Text('Supabase tarafinda aktif kasa bulunamadi.', style: TextStyle(color: Colors.white70)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        itemCount: _boxes.length,
        itemBuilder: (_, int index) {
          final _LootBoxView box = _boxes[index];
          final bool opening = _openingBoxId == box.id;
          final List<_LootDropView> drops = _boxDrops[box.id] ?? <_LootDropView>[];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            box.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            box.description,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _currencyColor(box.currencyType).withValues(alpha: 0.12),
                        border: Border.all(
                          color: _currencyColor(box.currencyType).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(_currencyIcon(box.currencyType),
                              size: 14, color: _currencyColor(box.currencyType)),
                          const SizedBox(width: 4),
                          Text(
                            _compactNum(box.price),
                            style: TextStyle(
                              color: _currencyColor(box.currencyType),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _miniInfo('Drop', '${box.dropCount} item'),
                    const SizedBox(width: 8),
                    _miniInfo('Nadir', '%${box.jackpotRate.toStringAsFixed(2)}'),
                    const SizedBox(width: 8),
                    _miniInfo('Carpan', 'x${box.rewardMultiplier.toStringAsFixed(2)}'),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: opening ? null : () => _openBox(box),
                      icon: opening
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open, size: 16),
                      label: Text(opening ? 'Aciliyor...' : 'Kasa Ac'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Text(
                      'Drop Preview',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _loadBoxDrops(box.id),
                      child: Text(
                        _loadingDropIds.contains(box.id)
                            ? 'Yukleniyor...'
                            : drops.isEmpty
                                ? 'Goster'
                                : 'Yenile',
                      ),
                    ),
                  ],
                ),
                if (drops.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: drops.take(10).map((d) {
                      final Color rarity = _rarityColor(d.rarity);
                      return Container(
                        width: 160,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: rarity.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: rarity.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: ItemIconView(
                                iconValue: d.icon,
                                itemId: d.itemId,
                                size: 24,
                                expand: true,
                                fallback: '◻',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    d.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '%${d.dropRate.toStringAsFixed(3)}  x${d.minQuantity}-${d.maxQuantity}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(growable: false),
                  )
                else if (_loadingDropIds.contains(box.id))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWheelsTab() {
    if (_wheels.isEmpty) {
      return const Center(
        child: Text('Supabase tarafinda aktif cark bulunamadi.', style: TextStyle(color: Colors.white70)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        itemCount: _wheels.length,
        itemBuilder: (_, int index) {
          final _WheelView wheel = _wheels[index];
          final bool spinning = _spinningWheelId == wheel.id;
          final List<_WheelRewardView> rewards = _wheelRewards[wheel.id] ??
              <_WheelRewardView>[];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            wheel.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            wheel.description,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _currencyColor(wheel.currencyType).withValues(alpha: 0.12),
                        border: Border.all(
                          color: _currencyColor(wheel.currencyType).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(_currencyIcon(wheel.currencyType),
                              size: 14, color: _currencyColor(wheel.currencyType)),
                          const SizedBox(width: 4),
                          Text(
                            _compactNum(wheel.price),
                            style: TextStyle(
                              color: _currencyColor(wheel.currencyType),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _miniInfo('Odul', '${wheel.rewardCount} dilim'),
                    const SizedBox(width: 8),
                    _miniInfo('Nadir', '%${wheel.jackpotRate.toStringAsFixed(2)}'),
                    const SizedBox(width: 8),
                    _miniInfo(
                      'Gunluk',
                      wheel.dailyLimit == null ? 'Sinirsiz' : '${wheel.dailyLimit}',
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: spinning ? null : () => _spinWheel(wheel),
                      icon: spinning
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.casino, size: 16),
                      label: Text(spinning ? 'Donuyor...' : 'Cark Cevir'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Text(
                      'Wheel Rewards',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _loadWheelRewards(wheel.id),
                      child: Text(
                        _loadingWheelIds.contains(wheel.id)
                            ? 'Yukleniyor...'
                            : rewards.isEmpty
                                ? 'Goster'
                                : 'Yenile',
                      ),
                    ),
                  ],
                ),
                if (rewards.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: rewards.take(12).map((r) {
                      final Color rarity = _rarityColor(r.rarity);
                      return Container(
                        width: 168,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: rarity.withValues(alpha: r.isJackpot ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: rarity.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: r.rewardType == 'item'
                                  ? ItemIconView(
                                      iconValue: r.icon,
                                      itemId: r.itemId,
                                      size: 24,
                                      expand: true,
                                      fallback: '◻',
                                    )
                                  : Icon(
                                      r.rewardType == 'gems' ? Icons.diamond : Icons.paid,
                                      color: r.rewardType == 'gems'
                                          ? const Color(0xFF22D3EE)
                                          : const Color(0xFFFBBF24),
                                      size: 20,
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    r.label.isNotEmpty ? r.label : r.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '%${r.dropRate.toStringAsFixed(3)}  x${r.minAmount}-${r.maxAmount}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(growable: false),
                  )
                else if (_loadingWheelIds.contains(wheel.id))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: RichText(
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
