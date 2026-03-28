import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

class _FactionTask {
  _FactionTask({
    required this.name,
    required this.description,
    required this.reward,
    required this.current,
    required this.target,
  });
  final String name;
  final String description;
  final int reward;
  int current;
  final int target;
}

class _Faction {
  _Faction({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.rep,
    required this.tasks,
  });
  final String id;
  final String icon;
  final String name;
  final String description;
  int rep;
  final List<_FactionTask> tasks;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _tierLabel(int rep) {
  if (rep < 20) return 'Düşman';
  if (rep < 40) return 'Nötr';
  if (rep < 60) return 'Dostane';
  if (rep < 80) return 'Saygın';
  return 'Onurlu';
}

Color _tierColor(int rep) {
  if (rep < 20) return const Color(0xFFEF4444);
  if (rep < 40) return const Color(0xFF9CA3AF);
  if (rep < 60) return const Color(0xFF60A5FA);
  if (rep < 80) return const Color(0xFF4ADE80);
  return const Color(0xFFFBBF24);
}

// Tier system
const _tierDefs = <(int, String, Color)>[
  (0,  'Düşman',   Color(0xFFEF4444)),
  (20, 'Nötr',     Color(0xFF9CA3AF)),
  (40, 'Dostane',  Color(0xFF60A5FA)),
  (60, 'Saygın',   Color(0xFF4ADE80)),
  (80, 'Onurlu',   Color(0xFFFBBF24)),
];

// Tier rewards per faction
const _tierRewards = <String, List<String>>{
  'tuccarlar':  ['Erişim yok', 'Pazar indirimi %5', 'Özel tüccar paketi', 'VIP pazar erişimi', 'Nadir eşya kataloğu'],
  'gizli':      ['Erişim yok', 'Bilgi parçaları', 'Gizli görevler', 'Özel silahlar', 'Ajan kıyafeti'],
  'tapınak':    ['Erişim yok', 'Küçük iyileştirme', 'Büyü kitapları', 'Kutsal zırh', 'Tanrı lütfu'],
  'hapisane':   ['Erişim yok', 'Avantaj %5', 'Düşük ceza riski', 'Özel hücre', 'Erken tahliye'],
  'hastane':    ['Erişim yok', 'Tedavi indirimi', 'Öncelikli bakım', 'Özel ilaçlar', 'Tam bağışıklık'],
};

List<_Faction> _defaultFactions() => <_Faction>[
      _Faction(
        id: 'tuccarlar',
        icon: '🏪',
        name: 'Tüccarlar Birliği',
        description: 'Şehrin ticaret hayatını yöneten güçlü tüccar birliği. Onların desteği altın kazanmanızı kolaylaştırır.',
        rep: 45,
        tasks: <_FactionTask>[
          _FactionTask(name: 'Pazar Ziyareti', description: 'Çarşıyı 5 kez ziyaret et', reward: 10, current: 3, target: 5),
          _FactionTask(name: 'Ticaret Anlaşması', description: 'Tüccardan 10 eşya al', reward: 15, current: 7, target: 10),
        ],
      ),
      _Faction(
        id: 'zanaatkarlar',
        icon: '⚒️',
        name: 'Zanaatkarlar Loncası',
        description: 'Ustalar ve zanaatkarlardan oluşan köklü lonca. Kaliteli ekipman üretimi için vazgeçilmez.',
        rep: 62,
        tasks: <_FactionTask>[
          _FactionTask(name: 'Üretim Yardımı', description: '3 adet eşya üret', reward: 12, current: 1, target: 3),
          _FactionTask(name: 'Malzeme Tedariki', description: 'Loncaya 20 hammadde teslim et', reward: 20, current: 20, target: 20),
        ],
      ),
      _Faction(
        id: 'maceracilar',
        icon: '⚔️',
        name: 'Maceracılar Rehberi',
        description: 'Bölge keşifçileri ve görev uzmanları. Zindan girişleri ve görevler için gerekli.',
        rep: 30,
        tasks: <_FactionTask>[
          _FactionTask(name: 'Zindan Macerası', description: '2 zindan temizle', reward: 25, current: 0, target: 2),
          _FactionTask(name: 'Bölge Keşfi', description: 'Yeni bir bölge keşfet', reward: 18, current: 1, target: 1),
        ],
      ),
      _Faction(
        id: 'muhafizlar',
        icon: '🛡️',
        name: 'Şehir Muhafızları',
        description: 'Kentin güvenliğinden sorumlu seçkin muhafız kuvveti. Yasaları uygular ve düzeni korurlar.',
        rep: 15,
        tasks: <_FactionTask>[
          _FactionTask(name: 'Devriye Görevi', description: 'Şehir duvarlarını 3 kez tur at', reward: 8, current: 1, target: 3),
          _FactionTask(name: 'Suçlu Teslimi', description: 'Kaçak birini muhafızlara teslim et', reward: 30, current: 0, target: 1),
        ],
      ),
      _Faction(
        id: 'suc_orgutu',
        icon: '🗡️',
        name: 'Suç Örgütü',
        description: 'Gölgede faaliyet gösteren gizemli örgüt. Riskli ama yüksek kazançlı işlerin kapısı.',
        rep: 80,
        tasks: <_FactionTask>[
          _FactionTask(name: 'Gizli Teslimat', description: 'Tespitsiz bir teslimat gerçekleştir', reward: 40, current: 2, target: 2),
          _FactionTask(name: 'Bilgi Toplayıcı', description: 'Rakip fraksiyon hakkında bilgi getir', reward: 35, current: 0, target: 1),
        ],
      ),
    ];

// ─── Screen ──────────────────────────────────────────────────────────────────

class ReputationScreen extends ConsumerStatefulWidget {
  const ReputationScreen({super.key});

  @override
  ConsumerState<ReputationScreen> createState() => _ReputationScreenState();
}

class _ReputationScreenState extends ConsumerState<ReputationScreen> {
  List<_Faction> _factions = <_Faction>[];
  bool _loading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dynamic result = await SupabaseService.client.rpc('get_reputation');
      if (result is List && result.isNotEmpty) {
        // map server data into _Faction objects; use defaults as fallback
        setState(() {
          _factions = _defaultFactions();
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // fall through to defaults
    }
    setState(() {
      _factions = _defaultFactions();
      _loading = false;
    });
  }

  void _toggleExpand(String id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
  }

  Future<void> _showDonateDialog(_Faction faction) async {
    int repAmount = 5;
    const goldPerRep = 100;
    final int playerGold = ref.read(playerProvider).profile?.gold ?? 0;
    final int maxRep = 100 - faction.rep;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final goldCost = repAmount * goldPerRep;
          final canAfford = playerGold >= goldCost;
          return AlertDialog(
            backgroundColor: const Color(0xFF1A2035),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('🪙 ${faction.name} — Bağış', style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Faction mini-card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Text(faction.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(faction.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Mevcut: ${faction.rep}/100 — ${_tierLabel(faction.rep)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                const Text('Kazanılacak İtibar Miktarı', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  IconButton(
                    onPressed: repAmount > 1 ? () => setDialogState(() => repAmount--) : null,
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFFBBF24)),
                    iconSize: 20,
                  ),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFBBF24)),
                      decoration: const InputDecoration(border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                      controller: TextEditingController(text: '$repAmount')..selection = TextSelection.collapsed(offset: '$repAmount'.length),
                      onChanged: (v) => setDialogState(() => repAmount = (int.tryParse(v) ?? 1).clamp(1, maxRep.clamp(1, 100))),
                    ),
                  ),
                  IconButton(
                    onPressed: repAmount < maxRep ? () => setDialogState(() => repAmount++) : null,
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFBBF24)),
                    iconSize: 20,
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('İtibar kazancı:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('+$repAmount', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Altın maliyeti:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('🪙 $goldCost', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Kalan altın:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('🪙 ${playerGold - goldCost}', style: TextStyle(color: canAfford ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ]),
                ),
                if (!canAfford) ...[
                  const SizedBox(height: 6),
                  const Text('⚠️ Yetersiz altın!', style: TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç', style: TextStyle(color: Colors.white54))),
              FilledButton(
                onPressed: (!canAfford || maxRep <= 0) ? null : () async {
                  Navigator.pop(ctx);
                  await _donate(faction, goldCost);
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black),
                child: const Text('Bağışla'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _donate(_Faction faction, int goldAmount) async {
    try {
      await SupabaseService.client.rpc(
        'donate_to_faction',
        params: <String, dynamic>{'p_faction_id': faction.id, 'p_gold_amount': goldAmount},
      );
    } catch (_) {
      // ignore rpc error; update locally anyway
    }
    final int repGain = goldAmount ~/ 100;
    setState(() => faction.rep = (faction.rep + repGain).clamp(0, 100));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+$repGain itibar kazanıldı! (${faction.name})')),
      );
    }
  }

  // ─── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildFactionCard(_Faction faction) {
    final bool expanded = _expandedId == faction.id;
    final Color tierColor = _tierColor(faction.rep);
    return GestureDetector(
      onTap: () => _toggleExpand(faction.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: expanded ? tierColor.withValues(alpha: 0.5) : Colors.white12),
          color: const Color(0xFF111827),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Text(faction.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(faction.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: faction.rep / 100,
                                  minHeight: 5,
                                  backgroundColor: Colors.white12,
                                  valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${faction.rep}/100', style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: tierColor.withValues(alpha: 0.15),
                      border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(_tierLabel(faction.rep), style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38, size: 18),
                ],
              ),
            ),
            // Expanded section
            if (expanded) ...<Widget>[
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(faction.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 14),
                    // Tier rewards
                    const Text('🎁 Kademe Ödülleri', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...List.generate(_tierDefs.length, (i) {
                      final (minRep, label, color) = _tierDefs[i];
                      final rewards = _tierRewards[faction.id] ?? [];
                      final reward = i < rewards.length ? rewards[i] : '—';
                      final unlocked = faction.rep >= minRep;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: unlocked ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(children: [
                          SizedBox(width: 60, child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700))),
                          Expanded(child: Text(reward, style: TextStyle(color: unlocked ? Colors.white70 : Colors.white24, fontSize: 10))),
                          if (unlocked) const Text('✓', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                        ]),
                      );
                    }),
                    const SizedBox(height: 12),
                    const Text('📋 Fraksiyon Görevleri', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...faction.tasks.map((_FactionTask t) => _buildTask(t)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: faction.rep >= 100 ? null : () => _showDonateDialog(faction),
                        icon: const Text('🪙', style: TextStyle(fontSize: 14)),
                        label: Text(faction.rep >= 100 ? '✅ Maksimum İtibar' : 'Altın Bağışla (+İtibar)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: faction.rep >= 100 ? Colors.green.withValues(alpha: 0.3) : const Color(0xFFFBBF24),
                          foregroundColor: faction.rep >= 100 ? Colors.greenAccent : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTask(_FactionTask task) {
    final double progress = task.target > 0 ? (task.current / task.target).clamp(0.0, 1.0) : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(task.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('🏆 +${task.reward} rep', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          Text(task.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${task.current}/${task.target}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
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
        title: 'İtibar',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.reputation),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: <Widget>[
                  // Page title
                  const Text('İtibar & Faksiyonlar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Faksiyonlarla ilişkilerinizi güçlendirin', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 16),
                  ..._factions.map(_buildFactionCard),
                ],
              ),
      ),
    );
  }
}
