import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/mekan_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class MekanDetailScreen extends ConsumerStatefulWidget {
  const MekanDetailScreen({super.key, required this.mekanId});
  final String mekanId;

  @override
  ConsumerState<MekanDetailScreen> createState() => _MekanDetailScreenState();
}

class _MekanDetailScreenState extends ConsumerState<MekanDetailScreen> {
  Mekan? _mekan;
  List<MekanStock> _stock = [];
  bool _isLoading = true;
  String? _buyingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final mRes = await SupabaseService.client
          .from('mekans')
          .select()
          .eq('id', widget.mekanId)
          .single();
      final sRes = await SupabaseService.client
          .from('mekan_stock')
          .select()
          .eq('mekan_id', widget.mekanId)
          .gt('quantity', 0);
      if (mounted) {
        setState(() {
          _mekan = Mekan.fromJson(Map<String, dynamic>.from(mRes as Map));
          _stock = (sRes as List).map((e) => MekanStock.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _buy(MekanStock item) async {
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return;
    if (profile.gold < item.sellPrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetersiz altın!')));
      return;
    }
    setState(() => _buyingId = item.id);
    try {
      await SupabaseService.client.rpc('buy_from_mekan', {'p_mekan_stock_id': item.id, 'p_quantity': 1});
      if (mounted) {
        setState(() {
          _stock = _stock.map((s) => s.id == item.id ? MekanStock(id: s.id, mekanId: s.mekanId, itemId: s.itemId, quantity: s.quantity - 1, sellPrice: s.sellPrice, stockedAt: s.stockedAt) : s).where((s) => s.quantity > 0).toList();
          _buyingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Satın alma başarılı!')));
      }
    } catch (_) {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  Color _rarityColor(String? r) {
    switch (r) {
      case 'uncommon': return Colors.green;
      case 'rare': return Colors.blue;
      case 'epic': return Colors.purple;
      case 'legendary': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _mekanTypeLabel(MekanType t) {
    switch (t) {
      case MekanType.bar: return 'Bar';
      case MekanType.kahvehane: return 'Kahvehane';
      case MekanType.dovus_kulubu: return 'Dövüş Kulübü';
      case MekanType.luks_lounge: return 'Lüks Lounge';
      case MekanType.yeralti: return 'Yeraltı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final isOwner = profile?.id == _mekan?.ownerId;

    return Scaffold(
      drawer: GameDrawer(onLogout: () async { await ref.read(authProvider.notifier).logout(); ref.read(playerProvider.notifier).clear(); }),
      appBar: GameTopBar(title: _mekan?.name ?? 'Mekan', onLogout: () async { await ref.read(authProvider.notifier).logout(); ref.read(playerProvider.notifier).clear(); }),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.mekans),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)])),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _mekan == null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Mekan bulunamadı', style: TextStyle(color: Colors.white54)), const SizedBox(height: 12), TextButton(onPressed: () => context.go(AppRoutes.mekans), child: const Text('Geri Dön'))]))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    // Header
                    Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(_mekan!.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _mekan!.isOpen ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Text(_mekan!.isOpen ? '🟢 Açık' : '🔴 Kapalı', style: TextStyle(fontSize: 12, color: _mekan!.isOpen ? Colors.green : Colors.red))),
                      ]),
                      const SizedBox(height: 8),
                      Text('Tür: ${_mekanTypeLabel(_mekan!.mekanType)} | Seviye: ${_mekan!.level} | Şöhret: ${_mekan!.fame}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text('Şüphe: ${_mekan!.suspicion}', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                      if (isOwner) ...[const SizedBox(height: 12), ElevatedButton(onPressed: () => context.go(AppRoutes.myMekan), child: const Text('Mekanımı Yönet'))],
                    ]))),
                    const SizedBox(height: 16),
                    Text('Ürünler', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 8),
                    if (_stock.isEmpty) const Card(color: Colors.white10, child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Stokta ürün yok', style: TextStyle(color: Colors.white38)))))
                    else ..._stock.map((s) => Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _rarityColor(null))),
                        title: Text(s.itemId, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Adet: ${s.quantity}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${s.sellPrice}🪙', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _buyingId == s.id ? null : () => _buy(s),
                            child: _buyingId == s.id ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Satın Al'),
                          ),
                        ]),
                      ),
                    )),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: () => context.go(AppRoutes.mekans), child: const Text('Geri Dön')),
                  ]),
      ),
    );
  }
}
