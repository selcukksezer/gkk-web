import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class _Region {
  _Region({
    required this.id,
    required this.name,
    required this.icon,
    required this.danger,
    required this.travelMinutes,
    required this.energyCost,
    required this.description,
    required this.activities,
    required this.isCurrent,
  });
  final String id;
  final String name;
  final String icon;
  final int danger;
  final int travelMinutes;
  final int energyCost;
  final String description;
  final List<String> activities;
  bool isCurrent;
}

List<_Region> _defaultRegions() => <_Region>[
      _Region(id: 'baslangic_koyu', name: 'Başlangıç Köyü', icon: '🏘️', danger: 0, travelMinutes: 0, energyCost: 0,
          description: 'Huzurlu bir başlangıç köyü. Acemi maceracılar için ideal bir üs.',
          activities: <String>['görev', 'ticaret', 'zanaat', 'dinlenme'], isCurrent: true),
      _Region(id: 'orman_bolgesi', name: 'Orman Bölgesi', icon: '🌲', danger: 20, travelMinutes: 5, energyCost: 5,
          description: 'Geniş ve sık ormanlık alan. Yabani hayvanlar ve küçük canavarlar bu bölgede yaşar.',
          activities: <String>['avlanma', 'keşif', 'görev'], isCurrent: false),
      _Region(id: 'dag_gecidi', name: 'Dağ Geçidi', icon: '⛰️', danger: 45, travelMinutes: 10, energyCost: 10,
          description: 'Sarp kayalıklar ve dar geçitlerle dolu tehlikeli dağ yolu.',
          activities: <String>['zanaat', 'avlanma', 'keşif'], isCurrent: false),
      _Region(id: 'karanlik_orman', name: 'Karanlık Orman', icon: '🌑', danger: 65, travelMinutes: 15, energyCost: 15,
          description: 'Lanetli karanlık orman. Elite canavarlar ve nadir loot buraya özgü.',
          activities: <String>['zindan', 'avlanma', 'görev'], isCurrent: false),
      _Region(id: 'lanetli_topraklar', name: 'Lanetli Topraklar', icon: '💀', danger: 80, travelMinutes: 20, energyCost: 20,
          description: 'Antik bir savaşın izlerini taşıyan lanetli bölge.',
          activities: <String>['zindan', 'görev'], isCurrent: false),
      _Region(id: 'ejderha_yurdu', name: 'Ejderha Yurdu', icon: '🐉', danger: 95, travelMinutes: 30, energyCost: 30,
          description: 'Kadim ejderhaların yurdu. Efsanevi ödüller burada gizli.',
          activities: <String>['zindan'], isCurrent: false),
    ];

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _dangerColor(int d) {
  if (d == 0) return const Color(0xFF4ADE80);
  if (d < 30) return const Color(0xFF4ADE80);
  if (d < 50) return const Color(0xFFFBBF24);
  if (d < 70) return const Color(0xFFF97316);
  if (d < 85) return const Color(0xFFEF4444);
  return const Color(0xFFDC2626);
}

String _dangerLabel(int d) {
  if (d == 0) return 'Güvenli';
  if (d < 30) return 'Düşük Risk';
  if (d < 50) return 'Orta Risk';
  if (d < 70) return 'Tehlikeli';
  if (d < 85) return 'Çok Tehlikeli';
  return 'Ölüm Tuzağı';
}

String _dangerEmoji(int d) {
  if (d == 0) return '🟢';
  if (d < 30) return '🟡';
  if (d < 50) return '🟠';
  if (d < 70) return '🔴';
  return '💀';
}

Color _activityColor(String activity) {
  switch (activity) {
    case 'zindan': return const Color(0xFFAB8FFF);
    case 'görev': return const Color(0xFF649BFF);
    case 'pazar': return const Color(0xFFDDB200);
    case 'zanaat': return const Color(0xFFF97316);
    case 'ticaret': return const Color(0xFF22C55E);
    case 'avlanma': return const Color(0xFFEF4444);
    case 'keşif': return const Color(0xFF06B6D4);
    case 'dinlenme': return const Color(0xFF4ADE80);
    default: return Colors.white54;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  List<_Region> _regions = <_Region>[];
  bool _loading = true;
  String? _travellingTo;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dynamic result = await SupabaseService.client.rpc('get_map_locations');
      if (result is List && result.isNotEmpty) {
        setState(() {
          _regions = _defaultRegions();
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // fall through
    }
    setState(() {
      _regions = _defaultRegions();
      _loading = false;
    });
  }

  _Region? get _currentRegion => _regions.where((_Region r) => r.isCurrent).isNotEmpty
      ? _regions.firstWhere((_Region r) => r.isCurrent)
      : null;

  Future<void> _confirmTravel(_Region region) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final Color dColor = _dangerColor(region.danger);
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2035),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${region.icon} ${region.name}\'e Seyahat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Text(_dangerEmoji(region.danger), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(_dangerLabel(region.danger), style: TextStyle(color: dColor, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              _travelInfoRow('⚡ Enerji Maliyeti', '${region.energyCost} enerji'),
              _travelInfoRow('🕐 Seyahat Süresi', '${region.travelMinutes} dakika'),
              if (region.danger >= 65) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  ),
                  child: const Text('⚠️ Uyarı: Bu bölge son derece tehlikeli!',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: dColor),
              child: const Text('Seyahat Et', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _travel(region);
  }

  Widget _travelInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );

  Future<void> _travel(_Region region) async {
    setState(() => _travellingTo = region.id);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    try {
      await SupabaseService.client.rpc('travel_to_region', params: <String, dynamic>{'p_region_id': region.id});
    } catch (_) {
      // ignore failure
    }
    setState(() {
      for (final _Region r in _regions) {
        r.isCurrent = r.id == region.id;
      }
      _travellingTo = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Seyahat Tamamlandı! ${region.name} bölgesine ulaştın.')),
      );
    }
  }

  // ─── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildCurrentBanner() {
    final _Region? current = _currentRegion;
    if (current == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF4ADE80).withValues(alpha: 0.1),
        border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (BuildContext context, Widget? child) => Opacity(
              opacity: _pulseAnim.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(current.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Mevcut Konumunuz', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w700)),
                Text(current.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionCard(_Region region) {
    final Color dColor = _dangerColor(region.danger);
    final bool isTravelling = _travellingTo == region.id;
    final int energy = ref.watch(playerProvider).profile?.energy ?? 100;
    final bool canTravel = energy >= region.energyCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF111827),
        border: Border.all(
          color: region.isCurrent ? const Color(0xFF4ADE80).withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header
            Row(
              children: <Widget>[
                Text(region.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(region.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Row(
                        children: <Widget>[
                          Text(_dangerEmoji(region.danger), style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(_dangerLabel(region.danger), style: TextStyle(color: dColor, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Danger bar
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: region.danger / 100,
                minHeight: 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(dColor),
              ),
            ),
            // Description
            const SizedBox(height: 8),
            Text(region.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            // Activities
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: region.activities.map((String a) {
                final Color c = _activityColor(a);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: c.withValues(alpha: 0.15),
                    border: Border.all(color: c.withValues(alpha: 0.4)),
                  ),
                  child: Text(a, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // Action button
            if (region.isCurrent)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.location_on, size: 14),
                  label: const Text('📍 Mevcut Konumunuz', style: TextStyle(fontSize: 12)),
                ),
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  Text('🕐 ${region.travelMinutes} dk', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text('⚡ ${region.energyCost} enerji', style: TextStyle(color: canTravel ? Colors.white54 : const Color(0xFFEF4444), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              if (!canTravel)
                Text('⚡ ${region.energyCost} Enerji Gerekli', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canTravel && !isTravelling ? () => _confirmTravel(region) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dColor.withValues(alpha: 0.2),
                    foregroundColor: dColor,
                    side: BorderSide(color: dColor.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: isTravelling
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Seyahat Et', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
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
        title: 'Harita',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.map),
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
                  const Text('Dünya Haritası', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Seyahat etmek istediğin bölgeyi seç', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 16),
                  _buildCurrentBanner(),
                  ..._regions.map(_buildRegionCard),
                ],
              ),
      ),
    );
  }
}
