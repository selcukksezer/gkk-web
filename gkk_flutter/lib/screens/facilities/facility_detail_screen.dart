import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../components/layout/game_chrome.dart';
import '../../models/facility_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/facilities_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class FacilityDetailScreen extends ConsumerStatefulWidget {
  const FacilityDetailScreen({
    super.key,
    required this.type,
  });

  final String type;

  @override
  ConsumerState<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends ConsumerState<FacilityDetailScreen> {
  static const int _productionDurationSeconds = 120;

  String _activeTab = 'overview';
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _productionPollTimer;
  String? _productionPollKey;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(facilitiesProvider.notifier).loadFacilities();
      ref.read(playerProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _productionPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facilitiesState = ref.watch(facilitiesProvider);
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;

    final bool inPrison = _isFuture(profile?.prisonUntil);
    final int energy = profile?.energy ?? 0;
    final int gold = profile?.gold ?? 0;

    PlayerFacility? facility;
    for (final row in facilitiesState.facilities) {
      if (row.facilityType == widget.type) {
        facility = row;
        break;
      }
    }

    final _FacilityMeta? meta = _facilityMeta[widget.type];

    final String? productionStartedAt = facility?.productionStartedAt;
    final DateTime? startedAt = productionStartedAt == null || productionStartedAt.isEmpty
        ? null
        : DateTime.tryParse(productionStartedAt);
    final DateTime? targetAt = startedAt?.add(const Duration(seconds: _productionDurationSeconds));
    final bool productionRunning = targetAt != null && _now.isBefore(targetAt);
    final bool productionReady = targetAt != null && !productionRunning;
    final bool hasProductionRecord = productionStartedAt != null && productionStartedAt.isNotEmpty;

    _syncProductionPolling(productionStartedAt, productionRunning);

    final int level = facility?.level ?? 1;

    final _LiveProductionSnapshot liveSnapshot = _buildLiveProductionSnapshot(
      facilityType: widget.type,
      level: level,
      productionStartedAt: productionStartedAt,
      now: _now,
    );

    final bool useLivePreview = hasProductionRecord;
    final int liveCount = useLivePreview
        ? liveSnapshot.totalProduced
        : _sumQueueQuantity(facility?.facilityQueue ?? const <FacilityQueueItem>[]);
    final int collectRequestCount = useLivePreview ? liveSnapshot.baseProduced : liveCount;

    final int upgradeCost = _getUpgradeCost(widget.type, level);
    final bool canUpgrade = !hasProductionRecord && (facility?.level ?? 1) < 10 && gold >= upgradeCost;

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Tesis Konsolu',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.facilities),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF090D14), Color(0xFF101722), Color(0xFF090D14)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            if (facility == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Text('Tesis bulunamadı', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 8),
                      Text('Bu tesis henüz açılmamış'),
                    ],
                  ),
                ),
              )
            else ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(meta?.icon ?? '🏭', style: const TextStyle(fontSize: 34)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Tesis Konsolu',
                                  style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Color(0xFF67E8F9)),
                                ),
                                Text(
                                  meta?.name ?? widget.type,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(meta?.description ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0x3322D3EE),
                              border: Border.all(color: const Color(0x4440E0FF)),
                            ),
                            child: Text('Lv.${facility.level}', style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(child: _tinyStat('Enerji', '$energy')),
                          const SizedBox(width: 6),
                          Expanded(child: _tinyStat('Altın', _formatGold(gold))),
                          const SizedBox(width: 6),
                          Expanded(child: _tinyStat('Durum', hasProductionRecord ? 'Üretimde' : 'Boşta')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _activeTab = 'overview'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _activeTab == 'overview' ? const Color(0x1A22D3EE) : null,
                      ),
                      child: const Text('Genel Bakış'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _activeTab = 'queue'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _activeTab == 'queue' ? const Color(0x1A22D3EE) : null,
                      ),
                      child: const Text('Üretim Kuyruğu'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_activeTab == 'overview') ...<Widget>[
                if (productionRunning)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text('🟢 Üretim Devam Ediyor', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text('⏱️ ${_formatRemaining(targetAt)}'),
                            ],
                          ),
                          if (liveSnapshot.items.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: liveSnapshot.items
                                  .map(
                                    (item) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white12),
                                        color: Colors.black26,
                                      ),
                                      child: Text(
                                        '${_resourceNameByRarity(widget.type, item.rarity)} • ${_rarityLabel(item.rarity)} ×${item.quantity}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: (inPrison || energy < 50)
                        ? null
                        : () async {
                            final bool ok = await ref.read(facilitiesProvider.notifier).startProduction(
                                  facilityId: facility!.id,
                                );
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Üretim başlatıldı!'
                                    : (ref.read(facilitiesProvider).errorMessage ?? 'Üretim başlatılamadı')),
                              ),
                            );
                            if (ok) {
                              ref.read(playerProvider.notifier).loadProfile();
                            }
                          },
                    child: const Text('⚡ Üretimi Başlat'),
                  ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('📦 Üretilebilir Kaynaklar', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (meta?.resources ?? const <String>[]).asMap().entries.map(
                                (entry) {
                                  final int index = entry.key;
                                  final String name = entry.value;
                                  final String rarity = index < _resourceRarities.length
                                      ? _resourceRarities[index]
                                      : 'common';
                                  final Map<String, int> weights = _getRarityWeightsAtLevel(facility!.level);
                                  final int total = weights.values.fold<int>(0, (int sum, int v) => sum + v);
                                  final int unlockLevel = _rarityUnlockLevels[rarity] ?? 1;
                                  final bool isUnlocked = facility.level >= unlockLevel;
                                  final double percent = total > 0 ? ((weights[rarity] ?? 0) / total) * 100 : 0;

                                  return Container(
                                  width: (MediaQuery.of(context).size.width - 56) / 2,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white12),
                                    color: Colors.black26,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(_rarityEmoji(rarity), style: const TextStyle(fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${percent.toStringAsFixed(1)}% ${isUnlocked ? '' : '(kilitli)'}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF67E8F9)),
                                      ),
                                    ],
                                  ),
                                );
                                },
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('✨ Nadirlik Simülatörü (Lv.1-10)', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...List<Widget>.generate(10, (int idx) {
                          final int rarityLevel = idx + 1;
                          final Map<String, int> weights = _getRarityWeightsAtLevel(rarityLevel);
                          final int total = weights.values.fold<int>(0, (int sum, int v) => sum + v);
                          final bool isCurrent = rarityLevel == facility!.level;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent ? const Color(0x6640E0FF) : Colors.white12,
                              ),
                              color: isCurrent ? const Color(0x1A22D3EE) : Colors.black26,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text('Lv.$rarityLevel', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if (isCurrent)
                                      const Text(
                                        'Mevcut Seviye',
                                        style: TextStyle(fontSize: 10, color: Color(0xFFA5F3FC)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _resourceRarities.map((String rarity) {
                                    final double pct = total > 0 ? ((weights[rarity] ?? 0) / total) * 100 : 0;
                                    final int decimals = (rarity == 'common' || rarity == 'uncommon' || rarity == 'rare') ? 0 : 1;

                                    return Container(
                                      width: (MediaQuery.of(context).size.width - 84) / 2,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white12),
                                        color: Colors.black26,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Text(_rarityTitle(rarity), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                              Text(
                                                '${pct.toStringAsFixed(decimals)}%',
                                                style: const TextStyle(fontSize: 10, color: Colors.white70),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: (pct.clamp(0, 100)) / 100,
                                            minHeight: 5,
                                            backgroundColor: const Color(0x33FFFFFF),
                                            color: const Color(0xFF22D3EE),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: const Color(0xCC38240E),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '⬆️ Yükseltme Paneli\nHedef: ${facility.level >= 10 ? 'Maksimum Seviye' : 'Lv.${facility.level + 1}'} • Maliyet: ${_formatGold(upgradeCost)} altın',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: (!canUpgrade || inPrison)
                              ? null
                              : () => _showUpgradeDialog(
                                    facility!.id,
                                    meta?.name ?? widget.type,
                                    facility.level,
                                    upgradeCost,
                                  ),
                          child: const Text('Yükselt'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasProductionRecord)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Önce mevcut üretimi tamamlayın.',
                      style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B)),
                    ),
                  ),
              ],
              if (_activeTab == 'queue') ...<Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          productionRunning
                              ? '🟢 Üretim Sürüyor'
                              : (productionReady ? '🟡 Süre doldu, toplama hazır' : '🔴 Üretim durdu'),
                        ),
                        if (productionRunning) Text('⏱️ ${_formatRemaining(targetAt)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('📦 Depo • Toplam: $liveCount', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (liveCount <= 0 && !productionRunning)
                          const Text('Depo boş. Üretimi başlatın.')
                        else if (liveCount <= 0)
                          const Text('🔨 İşçiler üretime devam ediyor...')
                        else
                          ...(useLivePreview
                                  ? liveSnapshot.items
                                      .map(
                                        (item) => FacilityQueueItem(
                                          id: item.rarity,
                                          quantity: item.quantity,
                                          rarity: item.rarity,
                                          startedAt: '',
                                          completesAt: '',
                                          isCompleted: productionReady,
                                        ),
                                      )
                                      .toList()
                                  : facility.facilityQueue)
                              .map(
                            (item) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                                color: Colors.black26,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      '${_resourceNameByRarity(widget.type, item.rarity)} • ${_rarityLabel(item.rarity)}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('×${item.quantity}'),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (productionReady && liveCount > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              FilledButton(
                                onPressed: inPrison
                                    ? null
                                    : () async {
                                        final int seed = _hashString(productionStartedAt ?? '');
                                        final Map<String, dynamic>? result = await ref
                                            .read(facilitiesProvider.notifier)
                                            .collectResourcesV2(
                                              facilityId: facility!.id,
                                              seed: seed,
                                              totalCount: collectRequestCount > 0 ? collectRequestCount : liveCount,
                                            );
                                        if (!mounted) return;
                                        if (result == null) {
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            SnackBar(content: Text(ref.read(facilitiesProvider).errorMessage ?? 'Toplama başarısız')),
                                          );
                                          return;
                                        }

                                        final bool admitted = result['admission_occurred'] == true;
                                        final int count = (result['count'] as num?)?.toInt() ?? liveCount;

                                        if (admitted) {
                                          final String prisonReason = (result['prison_reason'] ?? 'Bilinmiyor').toString();
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            SnackBar(content: Text('⚠️ Hapse düştünüz! Gerekçe: $prisonReason')),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            SnackBar(content: Text('✅ Toplandı: $count kaynak')),
                                          );
                                        }

                                        ref.read(playerProvider.notifier).loadProfile();
                                        ref.read(inventoryProvider.notifier).loadInventory(silent: true);
                                      },
                                child: Text('✅ Kaynakları Topla ($liveCount)'),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Toplama sonrası yeni üretim başlatabilirsiniz.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          )
                        else if (productionRunning)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              OutlinedButton(
                                onPressed: null,
                                child: Text('⏳ Bekleyin: ${_formatRemaining(targetAt)}'),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Süre dolunca toplama aktif olur.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              FilledButton(
                                onPressed: (inPrison || energy < 50)
                                    ? null
                                    : () async {
                                        final bool ok = await ref.read(facilitiesProvider.notifier).startProduction(
                                              facilityId: facility!.id,
                                            );
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok
                                                ? 'Üretim başlatıldı!'
                                                : (ref.read(facilitiesProvider).errorMessage ?? 'Üretim başlatılamadı')),
                                          ),
                                        );
                                        if (ok) {
                                          ref.read(playerProvider.notifier).loadProfile();
                                        }
                                      },
                                child: const Text('⚡ Üretimi Başlat'),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Maliyet: 50 Enerji (Mevcut: $energy)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                              if (energy < 50) ...<Widget>[
                                const SizedBox(height: 4),
                                const Text(
                                  '❌ Yetersiz enerji',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _syncProductionPolling(String? productionStartedAt, bool productionRunning) {
    final String nextKey = productionRunning && productionStartedAt != null ? productionStartedAt : '';
    if (_productionPollKey == nextKey) return;

    _productionPollKey = nextKey;
    _productionPollTimer?.cancel();

    if (!productionRunning || productionStartedAt == null) {
      _productionPollTimer = null;
      return;
    }

    _productionPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(facilitiesProvider.notifier).loadFacilities();
      ref.read(playerProvider.notifier).loadProfile();
    });
  }

  Future<void> _showUpgradeDialog(String facilityId, String name, int currentLevel, int upgradeCost) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Yükseltme Onayı'),
            content: Text(
              '$name tesisini Lv.${currentLevel + 1}\'e yükseltmek için ${_formatGold(upgradeCost)} altın harcanacak.',
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Onayla')),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final bool ok = await ref.read(facilitiesProvider.notifier).upgradeFacility(facilityId: facilityId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '$name yükseltildi!' : (ref.read(facilitiesProvider).errorMessage ?? '$name yükseltilemedi'))),
    );
    ref.read(playerProvider.notifier).loadProfile();
  }

  Widget _tinyStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black26,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FacilityMeta {
  const _FacilityMeta({
    required this.name,
    required this.icon,
    required this.description,
    required this.baseRate,
    required this.baseUpgradeCost,
    required this.multiplier,
    required this.resources,
  });

  final String name;
  final String icon;
  final String description;
  final double baseRate;
  final int baseUpgradeCost;
  final double multiplier;
  final List<String> resources;
}

const Map<String, _FacilityMeta> _facilityMeta = <String, _FacilityMeta>{
  'mining': _FacilityMeta(
    name: 'Maden Ocağı',
    icon: '⛏️',
    description: 'Demir, bakır, altın ve gümüş cevheri çıkarır',
    baseRate: 10,
    baseUpgradeCost: 100000,
    multiplier: 1.5,
    resources: <String>['Ham Demir', 'Saf Bakır', 'Gümüş Damarı', 'Asil Altın', 'Mithril', 'Saf Celestium'],
  ),
  'quarry': _FacilityMeta(
    name: 'Taş Ocağı',
    icon: '🪨',
    description: 'Granit, mermer ve kristal çıkarır',
    baseRate: 8,
    baseUpgradeCost: 120000,
    multiplier: 1.5,
    resources: <String>['Sıradan Taş', 'Katı Granit', 'Beyaz Mermer', 'Kara Obsidyen', 'Adamantit Parçası', 'Ebedi Taş'],
  ),
  'lumber_mill': _FacilityMeta(
    name: 'Kereste Fabrikası',
    icon: '🪵',
    description: 'Meşe, çam ve bambu odunu üretir',
    baseRate: 12,
    baseUpgradeCost: 150000,
    multiplier: 1.5,
    resources: <String>['Meşe Kerestesi', 'Çam Kerestesi', 'Abanoz', 'Ejder Ağacı', 'Dünya Ağacı Dalı', 'Yggdrasil Dalı'],
  ),
  'clay_pit': _FacilityMeta(
    name: 'Kil Ocağı',
    icon: '🏺',
    description: 'Seramik kili ve tuğla malzemesi çıkarır',
    baseRate: 15,
    baseUpgradeCost: 180000,
    multiplier: 1.5,
    resources: <String>['Sıradan Kil', 'Seramik Kili', 'Altın Kil', 'Ejder Kili', 'Elementel Kil', 'İlkel Kil'],
  ),
  'sand_quarry': _FacilityMeta(
    name: 'Kum Ocağı',
    icon: '🏖️',
    description: 'Cam kumu ve kristal kumu toplar',
    baseRate: 20,
    baseUpgradeCost: 200000,
    multiplier: 1.5,
    resources: <String>['Sıradan Kum', 'Cam Kumu', 'Kristal Kum', 'Altın Kum', 'Yıldız Kumu', 'Zaman Kumu'],
  ),
  'farming': _FacilityMeta(
    name: 'Çiftlik',
    icon: '🌾',
    description: 'Buğday, sebze ve pamuk yetiştirir',
    baseRate: 18,
    baseUpgradeCost: 250000,
    multiplier: 1.5,
    resources: <String>['Sıradan Buğday', 'Güçlü Arpa', 'Altın Pamuk', 'Ejder Meyvesi', 'Yaşam Tohumu', 'Ebedi Bitki'],
  ),
  'herb_garden': _FacilityMeta(
    name: 'Ot Bahçesi',
    icon: '🌿',
    description: 'Şifalı otlar ve nadir bitkiler yetiştirir',
    baseRate: 10,
    baseUpgradeCost: 300000,
    multiplier: 1.5,
    resources: <String>['Şifalı Ot', 'Zehirli Ot', 'Ay Çiçeği', 'Ejder Kökü', 'Ölümsüzlük Otu', 'Hayat Özü'],
  ),
  'ranch': _FacilityMeta(
    name: 'Hayvancılık',
    icon: '🐄',
    description: 'Deri, kemik ve yün üretir',
    baseRate: 12,
    baseUpgradeCost: 350000,
    multiplier: 1.5,
    resources: <String>['Sıradan Deri', 'Güçlü Yün', 'Canavar Boynuzu', 'Wyvern Derisi', 'Unicorn Tırnağı', 'Anka Kanı'],
  ),
  'apiary': _FacilityMeta(
    name: 'Arıcılık',
    icon: '🐝',
    description: 'Bal, balmumu ve arı zehiri toplar',
    baseRate: 8,
    baseUpgradeCost: 400000,
    multiplier: 1.5,
    resources: <String>['Orman Balı', 'Saf Balmumu', 'Kraliyet Jelesi', 'Arı Zehiri Özü', 'Altın Bal', 'İlahi Ambrosia'],
  ),
  'mushroom_farm': _FacilityMeta(
    name: 'Mantar Çiftliği',
    icon: '🍄',
    description: 'Şifalı ve zehirli mantarlar yetiştirir',
    baseRate: 10,
    baseUpgradeCost: 500000,
    multiplier: 1.5,
    resources: <String>['Şifalı Mantar', 'Parlayan Mantar', 'Zehirli Mantar', 'Kristal Mantar', 'Zaman Mantarı', 'İlkel Mantar'],
  ),
  'rune_mine': _FacilityMeta(
    name: 'Rune Madeni',
    icon: '🔮',
    description: 'Ham rune taşları ve büyülü kristaller çıkarır',
    baseRate: 5,
    baseUpgradeCost: 600000,
    multiplier: 1.6,
    resources: <String>['Ham Rune Taşı', 'Büyü Kristali', 'Enerji Parçası', 'Rune Çekirdeği', 'Gizemli Kalp', 'Rune Özü'],
  ),
  'holy_spring': _FacilityMeta(
    name: 'Kutsal Kaynak',
    icon: '⛲',
    description: 'Kutsal su ve mana kristalleri üretir',
    baseRate: 6,
    baseUpgradeCost: 700000,
    multiplier: 1.6,
    resources: <String>['Kutsal Su', 'Mana Kristali', 'Arındırma Suyu', 'Melek Gözyaşı', 'Yaşam Kaynağı', 'Ebedi Su'],
  ),
  'shadow_pit': _FacilityMeta(
    name: 'Gölge Çukuru',
    icon: '🕳️',
    description: 'Karanlık esans ve gölge kristalleri toplar',
    baseRate: 4,
    baseUpgradeCost: 800000,
    multiplier: 1.6,
    resources: <String>['Gölge Tozu', 'Gölge Kristali', 'Karanlık Esansı', 'Gölge Kalbi', 'Uçurum Çekirdeği', 'Ebedi Boşluk'],
  ),
  'elemental_forge': _FacilityMeta(
    name: 'Elementel Ocak',
    icon: '🔥',
    description: 'Ateş, buz ve yıldırım esansı üretir',
    baseRate: 5,
    baseUpgradeCost: 1000000,
    multiplier: 1.6,
    resources: <String>['Ateş Kıvılcımı', 'Buz Parçası', 'Yıldırım Çekirdeği', 'Toprak Kalbi', 'Saf Element', 'Beşinci Element'],
  ),
  'time_well': _FacilityMeta(
    name: 'Zaman Kuyusu',
    icon: '⏳',
    description: 'Zaman kristali ve hızlandırma tozu üretir',
    baseRate: 3,
    baseUpgradeCost: 1200000,
    multiplier: 1.7,
    resources: <String>['Zaman Tozu', 'Saat Parçası', 'Zaman Kristali', 'Kronos Esansı', 'Ebedi An', 'Sonsuz Zaman'],
  ),
};

int _getUpgradeCost(String type, int currentLevel) {
  final _FacilityMeta? meta = _facilityMeta[type];
  if (meta == null) return 0;

  final double cost = meta.baseUpgradeCost * _pow(meta.multiplier, currentLevel - 1);
  return cost.floor();
}

double _pow(double base, int exponent) {
  if (exponent <= 0) return 1;
  double result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

int _sumQueueQuantity(List<FacilityQueueItem> items) {
  int total = 0;
  for (final item in items) {
    total += item.quantity;
  }
  return total;
}

String _formatRemaining(DateTime? targetAt) {
  if (targetAt == null) return '00:00';
  final int remaining = targetAt.difference(DateTime.now()).inSeconds;
  if (remaining <= 0) return '✅';

  final int mins = remaining ~/ 60;
  final int secs = remaining % 60;
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

int _hashString(String value) {
  int hash = 0;
  for (int i = 0; i < value.length; i++) {
    hash = ((hash << 5) - hash) + value.codeUnitAt(i);
    hash &= 0x7fffffff;
  }
  return hash.abs();
}

String _rarityLabel(String rarity) {
  switch (rarity) {
    case 'common':
      return '⚪ Common';
    case 'uncommon':
      return '🟢 Uncommon';
    case 'rare':
      return '🔵 Rare';
    case 'epic':
      return '🟣 Epic';
    case 'legendary':
      return '🟡 Legendary';
    case 'mythic':
      return '🌈 Mythic';
    default:
      return rarity;
  }
}

String _rarityTitle(String rarity) {
  switch (rarity) {
    case 'common':
      return 'Common';
    case 'uncommon':
      return 'Uncommon';
    case 'rare':
      return 'Rare';
    case 'epic':
      return 'Epic';
    case 'legendary':
      return 'Legendary';
    case 'mythic':
      return 'Mythic';
    default:
      return rarity;
  }
}

String _rarityEmoji(String rarity) {
  switch (rarity) {
    case 'common':
      return '⚪';
    case 'uncommon':
      return '🟢';
    case 'rare':
      return '🔵';
    case 'epic':
      return '🟣';
    case 'legendary':
      return '🟡';
    case 'mythic':
      return '🌈';
    default:
      return '⚪';
  }
}

Map<String, int> _getRarityWeightsAtLevel(int level) {
  if (level <= 1) return _dropRatesByLevel[1]!;
  if (level >= 10) return _dropRatesByLevel[10]!;
  return _dropRatesByLevel[level] ?? _dropRatesByLevel[1]!;
}

const List<String> _resourceRarities = <String>['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'];

const Map<String, int> _rarityUnlockLevels = <String, int>{
  'common': 1,
  'uncommon': 2,
  'rare': 3,
  'epic': 4,
  'legendary': 5,
  'mythic': 6,
};

const Map<int, Map<String, int>> _dropRatesByLevel = <int, Map<String, int>>{
  1: <String, int>{'common': 100, 'uncommon': 0, 'rare': 0, 'epic': 0, 'legendary': 0, 'mythic': 0},
  2: <String, int>{'common': 90, 'uncommon': 10, 'rare': 0, 'epic': 0, 'legendary': 0, 'mythic': 0},
  3: <String, int>{'common': 70, 'uncommon': 25, 'rare': 5, 'epic': 0, 'legendary': 0, 'mythic': 0},
  4: <String, int>{'common': 55, 'uncommon': 30, 'rare': 13, 'epic': 2, 'legendary': 0, 'mythic': 0},
  5: <String, int>{'common': 40, 'uncommon': 30, 'rare': 20, 'epic': 8, 'legendary': 2, 'mythic': 0},
  6: <String, int>{'common': 30, 'uncommon': 28, 'rare': 22, 'epic': 14, 'legendary': 5, 'mythic': 1},
  7: <String, int>{'common': 22, 'uncommon': 25, 'rare': 23, 'epic': 18, 'legendary': 9, 'mythic': 3},
  8: <String, int>{'common': 15, 'uncommon': 22, 'rare': 24, 'epic': 22, 'legendary': 12, 'mythic': 5},
  9: <String, int>{'common': 10, 'uncommon': 18, 'rare': 24, 'epic': 24, 'legendary': 16, 'mythic': 8},
  10: <String, int>{'common': 5, 'uncommon': 14, 'rare': 22, 'epic': 26, 'legendary': 20, 'mythic': 13},
};

class _LiveResourceItem {
  const _LiveResourceItem({required this.rarity, required this.quantity});

  final String rarity;
  final int quantity;
}

class _LiveProductionSnapshot {
  const _LiveProductionSnapshot({
    required this.baseProduced,
    required this.totalProduced,
    required this.items,
  });

  final int baseProduced;
  final int totalProduced;
  final List<_LiveResourceItem> items;
}

_LiveProductionSnapshot _buildLiveProductionSnapshot({
  required String facilityType,
  required int level,
  required String? productionStartedAt,
  required DateTime now,
}) {
  if (productionStartedAt == null || productionStartedAt.isEmpty) {
    return const _LiveProductionSnapshot(baseProduced: 0, totalProduced: 0, items: <_LiveResourceItem>[]);
  }

  final DateTime? started = DateTime.tryParse(productionStartedAt);
  if (started == null) {
    return const _LiveProductionSnapshot(baseProduced: 0, totalProduced: 0, items: <_LiveResourceItem>[]);
  }

  final _FacilityMeta? meta = _facilityMeta[facilityType];
  final double baseRate = meta?.baseRate ?? 10;

  final int elapsedMs = now.millisecondsSinceEpoch - started.millisecondsSinceEpoch;
  final int durationMs = _productionDurationSecondsGlobal * 1000;
  final int clampedElapsedMs = elapsedMs.clamp(0, durationMs);
  final double elapsedSeconds = clampedElapsedMs / 1000;
  final double effectiveElapsedSeconds = elapsedSeconds >= 115 ? _productionDurationSecondsGlobal.toDouble() : elapsedSeconds;

  final double baseCalc = (effectiveElapsedSeconds / 3600.0) * (baseRate * level * 10);
  final int baseProduced = baseCalc.round();

  final int seed = _hashString(productionStartedAt).abs() % 2147483647;
  int jitterStep = 0;
  int totalProduced = baseProduced;

  if (baseProduced >= 20) {
    jitterStep = (seed % 11) - 5;
    totalProduced = (baseProduced * (1 + jitterStep / 100)).round();
    totalProduced = totalProduced.clamp(0, baseProduced + (baseProduced * 0.1).ceil());
  }

  if (totalProduced <= 0) {
    return _LiveProductionSnapshot(baseProduced: baseProduced, totalProduced: 0, items: const <_LiveResourceItem>[]);
  }

  final Map<String, int> weights = _getRarityWeightsAtLevel(level);
  final int sum = weights.values.fold<int>(0, (int s, int v) => s + v);
  if (sum <= 0) {
    return _LiveProductionSnapshot(baseProduced: baseProduced, totalProduced: totalProduced, items: const <_LiveResourceItem>[]);
  }

  final Map<String, int> counts = <String, int>{
    'common': 0,
    'uncommon': 0,
    'rare': 0,
    'epic': 0,
    'legendary': 0,
    'mythic': 0,
  };

  for (int i = 0; i < totalProduced; i++) {
    final int roll = ((_hashString('$productionStartedAt-$i') % sum) + sum) % sum;
    int cursor = 0;
    for (final String rarity in _resourceRarities) {
      cursor += weights[rarity] ?? 0;
      if (roll < cursor) {
        counts[rarity] = (counts[rarity] ?? 0) + 1;
        break;
      }
    }
  }

  final List<_LiveResourceItem> items = <_LiveResourceItem>[];
  for (int i = _resourceRarities.length - 1; i >= 0; i--) {
    final String rarity = _resourceRarities[i];
    final int quantity = counts[rarity] ?? 0;
    if (quantity > 0) {
      items.add(_LiveResourceItem(rarity: rarity, quantity: quantity));
    }
  }

  return _LiveProductionSnapshot(
    baseProduced: baseProduced,
    totalProduced: totalProduced,
    items: items,
  );
}

const int _productionDurationSecondsGlobal = 120;

String _resourceNameByRarity(String facilityType, String rarity) {
  final _FacilityMeta? meta = _facilityMeta[facilityType];
  if (meta == null) return rarity;

  final int idx = _resourceRarities.indexOf(rarity.toLowerCase());
  if (idx < 0 || idx >= meta.resources.length) return rarity;
  return meta.resources[idx];
}

bool _isFuture(String? iso) {
  if (iso == null || iso.isEmpty) return false;
  final DateTime? parsed = DateTime.tryParse(iso);
  if (parsed == null) return false;
  return parsed.isAfter(DateTime.now());
}

String _formatGold(int value) => NumberFormat.decimalPattern('tr_TR').format(value);
