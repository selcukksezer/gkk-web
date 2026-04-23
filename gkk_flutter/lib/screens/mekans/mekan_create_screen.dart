import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/mekan_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

const List<Map<String, dynamic>> _kMekanTypes = [
  {'type': 'bar', 'name': 'Bar', 'desc': 'İksir satışı + sosyal alan', 'cost': 5000000, 'reqLevel': 15},
  {'type': 'kahvehane', 'name': 'Kahvehane', 'desc': 'Buff iksir + detox satışı', 'cost': 8000000, 'reqLevel': 20},
  {'type': 'dovus_kulubu', 'name': 'Dövüş Kulübü', 'desc': 'PvP arena + bahis', 'cost': 15000000, 'reqLevel': 30},
  {'type': 'luks_lounge', 'name': 'Lüks Lounge', 'desc': 'Tüm özellikler + VIP', 'cost': 50000000, 'reqLevel': 45},
  {'type': 'yeralti', 'name': 'Yeraltı İmparatorluğu', 'desc': 'Tüm özellikler + kaçak ticaret', 'cost': 200000000, 'reqLevel': 60},
];

class MekanCreateScreen extends ConsumerStatefulWidget {
  const MekanCreateScreen({super.key});

  @override
  ConsumerState<MekanCreateScreen> createState() => _MekanCreateScreenState();
}

class _MekanCreateScreenState extends ConsumerState<MekanCreateScreen> {
  final _nameController = TextEditingController();
  String? _selectedType;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatCost(int cost) {
    if (cost >= 1000000) return '${(cost / 1000000).toStringAsFixed(1)}M';
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(0)}K';
    return cost.toString();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mekan adı boş olamaz!'))); return; }
    if (_selectedType == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mekan türü seçmelisiniz!'))); return; }

    final typeInfo = _kMekanTypes.firstWhere((t) => t['type'] == _selectedType);
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return;

    if (profile.level < (typeInfo['reqLevel'] as int)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bu mekanı açmak için Level ${typeInfo['reqLevel']} gerekiyor!')));
      return;
    }
    if (profile.gold < (typeInfo['cost'] as int)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yetersiz altın! (${_formatCost(typeInfo['cost'] as int)} G gerekli)')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.client.rpc('create_mekan', params: {'p_name': name, 'p_mekan_type': _selectedType});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mekan başarıyla açıldı!')));
        context.go(AppRoutes.myMekan);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: GameDrawer(onLogout: () async { await ref.read(authProvider.notifier).logout(); ref.read(playerProvider.notifier).clear(); }),
      appBar: GameTopBar(title: 'Yeni Mekan Aç', onLogout: () async { await ref.read(authProvider.notifier).logout(); ref.read(playerProvider.notifier).clear(); }),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.mekans),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)])),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mekan Adı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(controller: _nameController, maxLength: 30, decoration: const InputDecoration(hintText: 'Mekanınıza bir isim verin...', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(), counterStyle: TextStyle(color: Colors.white38))),
          ]))),
          const SizedBox(height: 16),
          const Text('Mekan Türü Seçin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 8),
          ..._kMekanTypes.map((t) {
            final selected = _selectedType == t['type'];
            return GestureDetector(
              onTap: () => setState(() => _selectedType = t['type'] as String),
              child: Card(
                color: selected ? const Color(0xFFFBBF24).withValues(alpha: 0.15) : Colors.white10,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? const Color(0xFFFBBF24) : Colors.transparent, width: 2)),
                child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                  Radio<String>(value: t['type'] as String, groupValue: _selectedType, onChanged: (v) => setState(() => _selectedType = v), activeColor: const Color(0xFFFBBF24)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(t['desc'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('💰 ${_formatCost(t['cost'] as int)} Altın', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('📊 Level ${t['reqLevel']}', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                    ]),
                  ])),
                ])),
              ),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _create,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('Mekan Aç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.go(AppRoutes.mekans), child: const Text('Geri Dön')),
        ]),
      ),
    );
  }
}
