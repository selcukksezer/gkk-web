import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

const Map<String, String> _mekanTypeLabels = {
  'bar': 'Bar',
  'kahvehane': 'Kahvehane',
  'dovus_kulubu': 'Dövüş Kulübü',
  'luks_lounge': 'Lüks Lounge',
  'yeralti': 'Yeraltı',
};

class MyMekanScreen extends ConsumerStatefulWidget {
  const MyMekanScreen({super.key});

  @override
  ConsumerState<MyMekanScreen> createState() => _MyMekanScreenState();
}

class _MyMekanScreenState extends ConsumerState<MyMekanScreen> {
  Map<String, dynamic>? _mekan;
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _inventory = [];
  bool _loading = true;
  String? _error;

  String? _selectedItemId;
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = SupabaseService.client;
      final userId = client.auth.currentUser?.id ?? '';

      final mekanRes = await client
          .from('mekans')
          .select('*')
          .eq('owner_id', userId)
          .maybeSingle();

      if (mekanRes == null) {
        if (mounted) {
          setState(() {
            _mekan = null;
            _loading = false;
          });
        }
        return;
      }

      final mekan = Map<String, dynamic>.from(mekanRes as Map);
      final mekanId = mekan['id']?.toString() ?? '';

      final stockRes = await client.from('mekan_stock').select('*').eq('mekan_id', mekanId);
      final invRes = await client.from('inventory').select('*, items(name)').eq('user_id', userId);

      if (mounted) {
        setState(() {
          _mekan = mekan;
          _stock = List<Map<String, dynamic>>.from(stockRes as List);
          _inventory = List<Map<String, dynamic>>.from(invRes as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  Future<void> _toggleOpen() async {
    final mekan = _mekan;
    if (mekan == null) return;
    final mekanId = mekan['id']?.toString() ?? '';
    final currentlyOpen = mekan['is_open'] == true;
    try {
      await SupabaseService.client.rpc('toggle_mekan_status', params: {
        'p_mekan_id': mekanId,
        'p_is_open': !currentlyOpen,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!currentlyOpen ? 'Mekan açıldı!' : 'Mekan kapatıldı.')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _saveStock() async {
    final mekan = _mekan;
    if (mekan == null || _selectedItemId == null) return;
    final mekanId = mekan['id']?.toString() ?? '';
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final price = int.tryParse(_priceController.text) ?? 100;
    try {
      await SupabaseService.client.rpc('update_mekan_stock', params: {
        'p_mekan_id': mekanId,
        'p_item_id': _selectedItemId,
        'p_quantity': qty,
        'p_sell_price': price,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stok güncellendi!')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: GameDrawer(onLogout: _doLogout),
      appBar: GameTopBar(title: 'Benim Mekanım', onLogout: _doLogout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.myMekan),
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
            : _error != null && _mekan == null
                ? _buildError()
                : _mekan == null
                    ? _buildNoMekan()
                    : _buildMekan(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Hata: $_error', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildNoMekan() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_outlined, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text('Henüz bir mekanınız yok.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Kendi mekanınızı açarak ticaret yapabilirsiniz.',
                style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.mekanCreate),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Mekan Aç'),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMekan() {
    final mekan = _mekan!;
    final name = mekan['name']?.toString() ?? '';
    final type = mekan['mekan_type']?.toString() ?? '';
    final typeLabel = _mekanTypeLabels[type] ?? type;
    final level = _asInt(mekan['level']);
    final fame = _asInt(mekan['fame']);
    final suspicion = _asInt(mekan['suspicion']);
    final isOpen = mekan['is_open'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('$typeLabel • Seviye $level',
                              style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _toggleOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: isOpen ? Colors.redAccent : Colors.greenAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isOpen ? 'Kapat' : 'Aç'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _statRow('Şöhret', fame, 1000, Colors.amber),
                const SizedBox(height: 8),
                _statRow('Şüphe', suspicion, 100,
                    suspicion > 60 ? Colors.redAccent : Colors.blueAccent),
                if (suspicion > 60) ...[
                  const SizedBox(height: 6),
                  const Text('⚠️ Şüphe seviyesi kritik!',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('📦 Stok Yönetimi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedItemId,
                  decoration: const InputDecoration(
                    labelText: 'Envanter\'den Ürün Seç',
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  dropdownColor: const Color(0xFF171E2C),
                  items: _inventory.map((inv) {
                    final itemId = inv['item_id']?.toString() ?? '';
                    final itemName = (inv['items'] is Map
                            ? inv['items']['name']
                            : null)
                        ?.toString() ?? itemId;
                    return DropdownMenuItem(value: itemId, child: Text(itemName));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedItemId = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Adet',
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fiyat (Altın)',
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selectedItemId != null ? _saveStock : null,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('🛒 Mevcut Stok',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_stock.isEmpty)
            _emptyCard('Stokta ürün yok.')
          else
            ..._stock.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _card(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['item_id']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Adet: ${_asInt(s['quantity'])}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('${_asInt(s['sell_price'])} G',
                            style: const TextStyle(
                                color: Colors.amber, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _statRow(String label, int value, int max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text('$value / $max',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _card({required Widget child, Color borderColor = Colors.white12}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(child: Text(message, style: const TextStyle(color: Colors.white54))),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
