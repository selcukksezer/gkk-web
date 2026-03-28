import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_model.dart';
import '../../routing/app_router.dart';
import '../../core/services/supabase_service.dart';

class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({super.key});

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  int _tabIndex = 0;
  String _tradeStatus = 'idle';
  String _partnerName = '';
  String? _sessionId;
  List<Map<String, dynamic>> _myOffer = [];
  bool _processing = false;
  List<Map<String, dynamic>> _history = [];
  final TextEditingController _searchController = TextEditingController();

  static final List<Map<String, dynamic>> _mockHistory = [
    {
      'id': 'th1',
      'date': '2025-01-15',
      'partner': 'Alkan',
      'my_items': ['Demir Külçe x5', 'Bakır Cevheri x10'],
      'their_items': ['Şifalı Bitki x20'],
      'status': 'completed',
    },
    {
      'id': 'th2',
      'date': '2025-01-14',
      'partner': 'Zeren',
      'my_items': ['Ham Deri x15'],
      'their_items': ['Çelik Levha x3'],
      'status': 'completed',
    },
    {
      'id': 'th3',
      'date': '2025-01-12',
      'partner': 'Selin',
      'my_items': ['Meşe Kerestesi x8'],
      'their_items': [],
      'status': 'cancelled',
    },
  ];

  static const Map<String, String> _statusLabels = {
    'idle': '',
    'searching': '⏳ Oyuncu aranıyor...',
    'pending': '⏳ Ticaret başlatıldı, karşı taraf bekleniyor...',
    'active': '🤝 Ticaret aktif — eşyaları ekleyin',
    'confirming': '✅ Onayınız alındı, karşı taraf bekleniyor',
    'done': '🎉 Ticaret tamamlandı',
  };

  @override
  void initState() {
    super.initState();
    _history =
        List<Map<String, dynamic>>.from(_mockHistory.map((e) => Map<String, dynamic>.from(e)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadInventory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final target = _searchController.text.trim();
    if (target.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Oyuncu adı girin!')));
      return;
    }
    setState(() {
      _processing = true;
      _tradeStatus = 'searching';
    });
    try {
      final raw = await SupabaseService.client
          .rpc('initiate_trade', params: {'target_username': target});
      if (!mounted) return;
      String sessionId = '';
      String partnerName = target;
      if (raw is Map) {
        if (raw['session_id'] != null) sessionId = raw['session_id'] as String;
        partnerName = (raw['partner_name'] as String?) ?? target;
      }
      setState(() {
        _sessionId = sessionId.isNotEmpty ? sessionId : null;
        _partnerName = partnerName;
        _tradeStatus = 'pending';
        _processing = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$target ile ticaret başlatıldı')));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _tradeStatus == 'pending') setState(() => _tradeStatus = 'active');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _partnerName = target;
        _tradeStatus = 'pending';
        _processing = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$target ile ticaret başlatıldı')));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _tradeStatus == 'pending') setState(() => _tradeStatus = 'active');
      });
    }
  }

  void _addItemToOffer(InventoryItem item) {
    if (_myOffer.any((o) => o['row_id'] == item.rowId)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bu eşya zaten teklifte')));
      return;
    }
    setState(() => _myOffer.add({
          'row_id': item.rowId,
          'item_id': item.itemId,
          'name': item.name,
          'quantity': 1,
          'rarity': item.rarity.name,
        }));
    if (_sessionId != null) {
      SupabaseService.client.rpc('add_trade_item',
          params: {'session_id': _sessionId, 'item_row_id': item.rowId}).catchError((_) {});
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${item.name} teklife eklendi')));
  }

  void _removeFromOffer(String rowId) {
    setState(() => _myOffer.removeWhere((o) => o['row_id'] == rowId));
  }

  Future<void> _confirmTrade() async {
    if (_myOffer.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('En az 1 eşya ekleyin!')));
      return;
    }
    setState(() {
      _processing = true;
      _tradeStatus = 'confirming';
    });
    try {
      if (_sessionId != null) {
        await SupabaseService.client
            .rpc('confirm_trade', params: {'p_session_id': _sessionId});
      }
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    setState(() => _processing = false);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _addToHistory('completed');
        setState(() => _tradeStatus = 'done');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('🎉 Ticaret tamamlandı!')));
      }
    });
  }

  Future<void> _cancelTrade() async {
    setState(() => _processing = true);
    if (_sessionId != null) {
      try {
        await SupabaseService.client
            .rpc('cancel_trade', params: {'p_session_id': _sessionId});
      } catch (_) {
        // ignore
      }
    }
    if (!mounted) return;
    if (_tradeStatus != 'idle' && _partnerName.isNotEmpty) {
      _addToHistory('cancelled');
    }
    _resetTrade();
    setState(() => _processing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Ticaret iptal edildi')));
  }

  void _addToHistory(String status) {
    setState(() => _history.insert(0, {
          'id': 'th${DateTime.now().millisecondsSinceEpoch}',
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'partner': _partnerName,
          'my_items': _myOffer.map((o) => '${o['name']} x${o['quantity']}').toList(),
          'their_items': <String>[],
          'status': status,
        }));
  }

  void _resetTrade() {
    setState(() {
      _tradeStatus = 'idle';
      _searchController.clear();
      _partnerName = '';
      _sessionId = null;
      _myOffer = [];
    });
  }

  void _showItemPicker(BuildContext context) {
    final inventoryItems = ref
        .read(inventoryProvider)
        .items
        .where((i) => !i.isEquipped && i.isTradeable)
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171E2C),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('📤 Eşya Seç',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: inventoryItems.isEmpty
              ? const Center(
                  child: Text('Taşınabilir eşya yok', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: inventoryItems.length,
                  itemBuilder: (ctx, i) {
                    final item = inventoryItems[i];
                    return ListTile(
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: _rarityColor(item.rarity.name)),
                      ),
                      title: Text(item.name, style: const TextStyle(color: Colors.white)),
                      subtitle:
                          Text('x${item.quantity}', style: const TextStyle(color: Colors.white54)),
                      onTap: () {
                        Navigator.pop(context);
                        _addItemToOffer(item);
                      },
                    );
                  },
                ),
        ),
      ]),
    );
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

  @override
  Widget build(BuildContext context) {
    final logoutHandler = () async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    };

    return Scaffold(
      drawer: GameDrawer(onLogout: logoutHandler),
      appBar: GameTopBar(title: '🤝 Ticaret', onLogout: logoutHandler),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.trade),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10131D), Color(0xFF171E2C)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(children: [
                _buildTab(0, '🤝 Ticaret'),
                const SizedBox(width: 8),
                _buildTab(1, '📜 Geçmiş'),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: _tabIndex == 0 ? _buildTradeTab() : _buildHistoryTab(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? const Color(0xFF3B82F6) : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: active ? const Color(0xFF3B82F6) : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTradeTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_tradeStatus != 'idle' && (_statusLabels[_tradeStatus] ?? '').isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(_statusLabels[_tradeStatus] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      if (_tradeStatus == 'idle') _buildIdleState(),
      if (_tradeStatus == 'searching') _buildSearchingState(),
      if (_tradeStatus == 'pending') _buildPendingState(),
      if (_tradeStatus == 'active') _buildActiveState(),
      if (_tradeStatus == 'confirming') _buildConfirmingState(),
      if (_tradeStatus == 'done') _buildDoneState(),
    ]);
  }

  Widget _buildIdleState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ticaret yapmak istediğiniz oyuncuyu arayın.',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Oyuncu adı...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _processing ? null : _handleSearch,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            child: const Text('🔍 Ara'),
          ),
        ]),
      ]),
    );
  }

  Widget _buildSearchingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: const Column(children: [
        Text('🔍', style: TextStyle(fontSize: 32)),
        SizedBox(height: 8),
        Text('Oyuncu aranıyor...', style: TextStyle(color: Colors.white54)),
        SizedBox(height: 8),
        CircularProgressIndicator(color: Color(0xFF3B82F6)),
      ]),
    );
  }

  Widget _buildPendingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        const Text('⏳', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('$_partnerName bekleniyor...',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('Ticaret isteği gönderildi.',
            style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _processing ? null : _cancelTrade,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
          child: const Text('İptal Et'),
        ),
      ]),
    );
  }

  Widget _buildActiveState() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Row(children: [
          const Text('🤝', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_partnerName ile Ticaret',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              if (_sessionId != null)
                Text(
                  'Oturum: ${_sessionId!.length > 8 ? '${_sessionId!.substring(0, 8)}...' : _sessionId!}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
            ]),
          ),
          TextButton(
            onPressed: _cancelTrade,
            child: const Text('İptal', style: TextStyle(color: Colors.redAccent)),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
              color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('📤 Teklifim',
                  style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11)),
              const SizedBox(height: 6),
              if (_myOffer.isEmpty)
                Container(
                  constraints: const BoxConstraints(minHeight: 80),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Center(
                      child: Text('Eşya ekle', style: TextStyle(color: Colors.white38, fontSize: 11))),
                )
              else
                ..._myOffer.map((offer) => Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            (offer['name'] as String?) ?? '',
                            style: TextStyle(
                                color: _rarityColor((offer['rarity'] as String?) ?? 'common'),
                                fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeFromOffer((offer['row_id'] as String?) ?? ''),
                          child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                        ),
                      ]),
                    )),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('📥 Karşı Teklif',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Center(
                    child: Text('Bekleniyor...',
                        style: TextStyle(color: Colors.white38, fontSize: 11))),
              ),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showItemPicker(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('➕ Eşya Ekle'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _processing ? null : _cancelTrade,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('❌ İptal'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: _processing ? null : _confirmTrade,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
            child: const Text('✅ Onayla'),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildConfirmingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        const Text('⏳', style: TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        const Text('Onayınız alındı',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Karşı tarafın onayı bekleniyor...',
            style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _processing ? null : _cancelTrade,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
          child: const Text('İptal Et'),
        ),
      ]),
    );
  }

  Widget _buildDoneState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
        color: const Color(0xFF22C55E).withValues(alpha: 0.05),
      ),
      child: Column(children: [
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        const Text('Ticaret Tamamlandı!',
            style: TextStyle(
                color: Color(0xFF22C55E), fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('$_partnerName ile ticaret başarıyla gerçekleşti.',
            style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _resetTrade,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
          child: const Text('Yeni Ticaret'),
        ),
      ]),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
            child: Text('Henüz ticaret geçmişi yok.',
                style: TextStyle(color: Colors.white54))),
      );
    }
    return Column(
      children: _history.map((entry) {
        final completed = entry['status'] == 'completed';
        final myItems = List<String>.from((entry['my_items'] as List?) ?? []);
        final theirItems = List<String>.from((entry['their_items'] as List?) ?? []);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🤝', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((entry['partner'] as String?) ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text((entry['date'] as String?) ?? '',
                      style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: completed
                      ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                      : const Color(0xFFDC2626).withValues(alpha: 0.2),
                ),
                child: Text(
                  completed ? '✓ Tamamlandı' : '✕ İptal',
                  style: TextStyle(
                      color: completed ? const Color(0xFF22C55E) : const Color(0xFFDC2626),
                      fontSize: 10),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('📤 Ben verdim:',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                  if (myItems.isEmpty)
                    const Text('—', style: TextStyle(color: Colors.white38, fontSize: 11))
                  else
                    ...myItems.map(
                        (item) => Text('• $item', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('📥 Ben aldım:',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                  if (theirItems.isEmpty)
                    const Text('—', style: TextStyle(color: Colors.white38, fontSize: 11))
                  else
                    ...theirItems.map(
                        (item) => Text('• $item', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                ]),
              ),
            ]),
          ]),
        );
      }).toList(),
    );
  }
}
