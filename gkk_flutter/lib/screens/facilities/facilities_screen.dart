import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../components/layout/game_chrome.dart';
import '../../models/facility_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/facilities_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class FacilitiesScreen extends ConsumerStatefulWidget {
  const FacilitiesScreen({super.key});

  @override
  ConsumerState<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends ConsumerState<FacilitiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(facilitiesProvider.notifier).loadFacilities();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final facilitiesState = ref.watch(facilitiesProvider);
    final profile = playerState.profile;
    final int level = profile?.level ?? 1;
    final int gold = profile?.gold ?? 0;
    final int gems = profile?.gems ?? 0;
    final int globalSuspicion = profile?.globalSuspicionLevel ?? 0;
    final bool inPrison = _isFuture(profile?.prisonUntil);
    final String prisonReason = (profile?.prisonReason == null || profile!.prisonReason!.trim().isEmpty)
        ? 'Bilinmiyor'
        : profile.prisonReason!;

    final Map<String, PlayerFacility> unlockedByType = <String, PlayerFacility>{
      for (final facility in facilitiesState.facilities) facility.facilityType: facility,
    };

    final List<_TierGroup> tiers = <_TierGroup>[
      _TierGroup(tier: 1, label: '🏚️ Tier 1 — Başlangıç', facilities: _basicFacilities),
      _TierGroup(tier: 2, label: '🏗️ Tier 2 — Gelişmiş', facilities: _organicFacilities),
      _TierGroup(tier: 3, label: '🏰 Tier 3 — İleri', facilities: _mysticalFacilities),
    ];

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Tesisler',
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Operasyon Merkezi',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Color(0xFF67E8F9)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Tesis Ağı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text(
                                'İstasyonları yönet, üretimi ölçekle, riski kontrol et.',
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            const Text('Aktif Tesis', style: TextStyle(fontSize: 10, color: Colors.white60)),
                            Text(
                              '${unlockedByType.length} / 15',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF67E8F9)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(child: _tinyStat('Seviye', 'Lv.$level')),
                        const SizedBox(width: 6),
                        Expanded(child: _tinyStat('Altın', _formatGold(gold))),
                        const SizedBox(width: 6),
                        Expanded(child: _tinyStat('Gem', '$gems')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (inPrison) ...<Widget>[
              const SizedBox(height: 10),
              Card(
                color: const Color(0xCC4A1111),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('👮 Cezaevindesiniz, operasyonlar kilitli.', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('📄 Gerekçe: $prisonReason', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text('🕵️ Genel Şüphe İndeksi', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '%$globalSuspicion',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _suspicionColor(globalSuspicion),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (globalSuspicion / 100).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Yüksek şüphe, baskın ve hapis riskini artırır.',
                            style: TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: (gems < 5 || inPrison)
                              ? null
                              : () => _handleBribe(context, facilitiesState, gems),
                          child: const Text('💎 5 Rüşvet Ver'),
                        ),
                      ],
                    ),
                    if (globalSuspicion <= 0) ...<Widget>[
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Şüphe 0 iken rüşvet verilemez.',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            ...tiers.map((tierGroup) => _buildTierSection(
                  context,
                  tierGroup: tierGroup,
                  level: level,
                  gold: gold,
                  inPrison: inPrison,
                  unlockedByType: unlockedByType,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTierSection(
    BuildContext context, {
    required _TierGroup tierGroup,
    required int level,
    required int gold,
    required bool inPrison,
    required Map<String, PlayerFacility> unlockedByType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(tierGroup.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${tierGroup.facilities.length} istasyon', style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          itemCount: tierGroup.facilities.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _FacilityCardData facility = tierGroup.facilities[index];
            final PlayerFacility? playerFacility = unlockedByType[facility.type];
            final bool isUnlocked = playerFacility != null;
            final bool canUnlock = !isUnlocked && level >= facility.unlockLevel && gold >= facility.unlockCost;

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _onFacilityTap(
                context,
                facility: facility,
                isUnlocked: isUnlocked,
                canUnlock: canUnlock,
                inPrison: inPrison,
                level: level,
                gold: gold,
              ),
              child: Ink(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUnlocked ? const Color(0x8040E0FF) : Colors.white24,
                  ),
                  color: isUnlocked ? const Color(0xD2141E2C) : const Color(0xD2181A20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(facility.icon, style: const TextStyle(fontSize: 22)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: isUnlocked ? const Color(0x3334D399) : Colors.white12,
                          ),
                          child: Text(
                            isUnlocked ? 'Aktif' : 'Kilitli',
                            style: TextStyle(
                              fontSize: 10,
                              color: isUnlocked ? const Color(0xFF86EFAC) : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      facility.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (isUnlocked)
                      Row(
                        children: <Widget>[
                          Expanded(child: Text('Lv.${playerFacility.level}', style: const TextStyle(fontSize: 11))),
                          Expanded(
                            child: Text(
                              '⏳ ${playerFacility.facilityQueue.length}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '🔒 Gereken Seviye: ${facility.unlockLevel}',
                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🪙 Maliyet: ${_formatGold(facility.unlockCost)}',
                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> _onFacilityTap(
    BuildContext context, {
    required _FacilityCardData facility,
    required bool isUnlocked,
    required bool canUnlock,
    required bool inPrison,
    required int level,
    required int gold,
  }) async {
    if (inPrison) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cezaevindeyken detaylara erişilemez. Kefalet ödeyerek serbest kalabilirsiniz.'),
        ),
      );
      return;
    }

    if (isUnlocked) {
      context.push('${AppRoutes.facilities}/${facility.type}');
      return;
    }

    if (canUnlock) {
      final bool confirm = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Onay'),
              content: Text(
                '${facility.name} açmak için ${_formatGold(facility.unlockCost)} altını harcamak istediğinize emin misiniz?',
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Onayla')),
              ],
            ),
          ) ??
          false;

      if (!confirm) return;

      final bool ok = await ref.read(facilitiesProvider.notifier).unlockFacility(facilityType: facility.type);
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(ok ? '${facility.name} açıldı!' : (ref.read(facilitiesProvider).errorMessage ?? 'Tesis açılamadı')),
        ),
      );
      return;
    }

    if (level < facility.unlockLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seviye ${facility.unlockLevel} gerekli')),
      );
      return;
    }

    if (gold < facility.unlockCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_formatGold(facility.unlockCost)} altın gerekli')),
      );
    }
  }

  Future<void> _handleBribe(BuildContext context, FacilitiesState facilitiesState, int gems) async {
        final int globalSuspicion = ref.read(playerProvider).profile?.globalSuspicionLevel ?? 0;
        if (globalSuspicion <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Şüphe 0 iken rüşvet verilemez')),
          );
          return;
        }

    if (gems < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rüşvet için 5 gem gerekli')),
      );
      return;
    }

    final PlayerFacility? unlocked = facilitiesState.facilities.isNotEmpty ? facilitiesState.facilities.first : null;
    if (unlocked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rüşvet için açık tesis yok')),
      );
      return;
    }

    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            content: Text('Seçilen tesis: ${unlocked.facilityType}. 5 Gem ile rüşvet vermek istiyor musunuz?'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Onayla')),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final bool ok = await ref.read(facilitiesProvider.notifier).bribeOfficials(
          facilityType: unlocked.facilityType,
          gemAmount: 5,
        );
    if (!mounted) return;

    if (ok) {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(facilitiesProvider.notifier).loadFacilities();
    }

    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Rüşvet verildi, genel şüphe güncellendi!' : (ref.read(facilitiesProvider).errorMessage ?? 'Rüşvet verilemedi')),
      ),
    );
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

class _TierGroup {
  const _TierGroup({
    required this.tier,
    required this.label,
    required this.facilities,
  });

  final int tier;
  final String label;
  final List<_FacilityCardData> facilities;
}

class _FacilityCardData {
  const _FacilityCardData({
    required this.type,
    required this.name,
    required this.icon,
    required this.unlockLevel,
    required this.unlockCost,
  });

  final String type;
  final String name;
  final String icon;
  final int unlockLevel;
  final int unlockCost;
}

const List<_FacilityCardData> _basicFacilities = <_FacilityCardData>[
  _FacilityCardData(type: 'mining', name: 'Maden Ocağı', icon: '⛏️', unlockLevel: 1, unlockCost: 50000),
  _FacilityCardData(type: 'quarry', name: 'Taş Ocağı', icon: '🪨', unlockLevel: 2, unlockCost: 80000),
  _FacilityCardData(type: 'lumber_mill', name: 'Kereste Fabrikası', icon: '🪵', unlockLevel: 3, unlockCost: 100000),
  _FacilityCardData(type: 'clay_pit', name: 'Kil Ocağı', icon: '🏺', unlockLevel: 4, unlockCost: 120000),
  _FacilityCardData(type: 'sand_quarry', name: 'Kum Ocağı', icon: '🏖️', unlockLevel: 5, unlockCost: 150000),
];

const List<_FacilityCardData> _organicFacilities = <_FacilityCardData>[
  _FacilityCardData(type: 'farming', name: 'Çiftlik', icon: '🌾', unlockLevel: 6, unlockCost: 200000),
  _FacilityCardData(type: 'herb_garden', name: 'Ot Bahçesi', icon: '🌿', unlockLevel: 7, unlockCost: 250000),
  _FacilityCardData(type: 'ranch', name: 'Hayvancılık', icon: '🐄', unlockLevel: 8, unlockCost: 300000),
  _FacilityCardData(type: 'apiary', name: 'Arıcılık', icon: '🐝', unlockLevel: 9, unlockCost: 350000),
  _FacilityCardData(type: 'mushroom_farm', name: 'Mantar Çiftliği', icon: '🍄', unlockLevel: 10, unlockCost: 400000),
];

const List<_FacilityCardData> _mysticalFacilities = <_FacilityCardData>[
  _FacilityCardData(type: 'rune_mine', name: 'Rune Madeni', icon: '🔮', unlockLevel: 15, unlockCost: 500000),
  _FacilityCardData(type: 'holy_spring', name: 'Kutsal Kaynak', icon: '⛲', unlockLevel: 20, unlockCost: 600000),
  _FacilityCardData(type: 'shadow_pit', name: 'Gölge Çukuru', icon: '🕳️', unlockLevel: 25, unlockCost: 700000),
  _FacilityCardData(type: 'elemental_forge', name: 'Elementel Ocak', icon: '🔥', unlockLevel: 30, unlockCost: 800000),
  _FacilityCardData(type: 'time_well', name: 'Zaman Kuyusu', icon: '⏳', unlockLevel: 40, unlockCost: 1000000),
];

Color _suspicionColor(int value) {
  if (value >= 80) return const Color(0xFFFF6B6B);
  if (value >= 50) return const Color(0xFFFFD166);
  return const Color(0xFF7CFFB2);
}

bool _isFuture(String? iso) {
  if (iso == null || iso.isEmpty) return false;
  final DateTime? parsed = DateTime.tryParse(iso);
  if (parsed == null) return false;
  return parsed.isAfter(DateTime.now());
}

String _formatGold(int value) => NumberFormat.decimalPattern('tr_TR').format(value);
