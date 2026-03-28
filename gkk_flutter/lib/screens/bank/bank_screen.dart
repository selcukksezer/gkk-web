import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_model.dart';
import '../../routing/app_router.dart';
import '../../core/services/supabase_service.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const _baseBankSlots = 100;
const _maxBankSlots = 200;
const _slotsPerPage = 20;
const _inventoryPerPage = 20;

int _expandCost(int total) {
  if (total >= 175) return 500;
  if (total >= 150) return 200;
  if (total >= 125) return 100;
  return 50;
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({super.key});

  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _bankItems = [];
  int _totalSlots = _baseBankSlots;
  int _usedSlots = 0;

  // Tabs: 0=bank, 1=inventory
  int _tabIndex = 0;

  // Pagination
  int _bankPage = 1;
  int _inventoryPage = 1;

  // Multi-select
  final Set<String> _selectedBankIds = {};
  final Set<String> _selectedInventoryRowIds = {};

  // Operations
  bool _depositing = false;
  bool _withdrawing = false;
  bool _expanding = false;
  bool get _actionInProgress => _depositing || _withdrawing || _expanding;

  // Deposit modal
  Map<String, dynamic>? _depositItem;   // inventory item
  int _depositQty = 1;
  // Withdraw modal
  Map<String, dynamic>? _withdrawItem;  // bank item
  int _withdrawQty = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      ref.read(inventoryProvider.notifier).loadInventory();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final accountRaw = await SupabaseService.client.rpc('get_bank_account');
      int totalSlots = _baseBankSlots;
      int usedSlots = 0;
      if (accountRaw is Map) {
        totalSlots = (accountRaw['total_slots'] as int?) ?? _baseBankSlots;
        usedSlots = (accountRaw['used_slots'] as int?) ?? 0;
      } else if (accountRaw is List && accountRaw.isNotEmpty) {
        final m = accountRaw[0] as Map;
        totalSlots = (m['total_slots'] as int?) ?? _baseBankSlots;
        usedSlots = (m['used_slots'] as int?) ?? 0;
      }

      final itemsRaw = await SupabaseService.client.rpc('get_bank_items', params: {'p_category': null});
      List<dynamic> rawList = [];
      if (itemsRaw is Map && itemsRaw['items'] is List) {
        rawList = itemsRaw['items'] as List;
      } else if (itemsRaw is List && itemsRaw.isNotEmpty) {
        final first = itemsRaw[0];
        if (first is Map && first['items'] is List) {
          rawList = first['items'] as List;
        } else {
          rawList = itemsRaw;
        }
      }
      final bankItems = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (!mounted) return;
      setState(() {
        _totalSlots = totalSlots.clamp(_baseBankSlots, _maxBankSlots);
        _usedSlots = usedSlots;
        _bankItems = bankItems;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Banka yüklenemedi: $e')));
    }
  }

  // ─── Deposit ──────────────────────────────────────────────────────────────
  Future<void> _depositSingle(InventoryItem item) async {
    if (_actionInProgress) return;
    setState(() { _depositItem = {'row_id': item.rowId, 'name': item.name, 'quantity': item.quantity, 'is_stackable': item.quantity > 1}; _depositQty = item.quantity; });
    await _showDepositModal(item.rowId, item.name, item.quantity);
  }

  Future<void> _depositBatch() async {
    if (_selectedInventoryRowIds.isEmpty || _actionInProgress) return;
    setState(() => _depositing = true);
    try {
      await SupabaseService.client.rpc('deposit_to_bank', params: {'p_item_row_ids': _selectedInventoryRowIds.toList()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedInventoryRowIds.length} eşya bankaya yatırıldı')));
      _selectedInventoryRowIds.clear();
      ref.read(inventoryProvider.notifier).loadInventory();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _depositing = false);
    }
  }

  Future<void> _showDepositModal(String rowId, String name, int maxQty) async {
    final qtyCtrl = TextEditingController(text: '$maxQty');
    int qty = maxQty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        title: Text('🏦 $name Yatır', style: const TextStyle(color: Color(0xFFFBBF24))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Envanterde: $maxQty adet', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Miktar:', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(filled: true, fillColor: Color(0xFF0F0F0F), border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
              onChanged: (v) => qty = (int.tryParse(v) ?? 1).clamp(1, maxQty),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black), child: const Text('✓ Onayla')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _depositing = true);
    try {
      await SupabaseService.client.rpc('deposit_to_bank', params: {'p_item_row_ids': [rowId], 'p_quantities': [qty]});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name bankaya yatırıldı')));
      ref.read(inventoryProvider.notifier).loadInventory();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _depositing = false);
    }
  }

  // ─── Withdraw ─────────────────────────────────────────────────────────────
  Future<void> _withdrawSingle(Map<String, dynamic> bankItem) async {
    if (_actionInProgress) return;
    final id = bankItem['id']?.toString() ?? '';
    final name = bankItem['name']?.toString() ?? 'Eşya';
    final maxQty = (bankItem['quantity'] as int?) ?? 1;
    final qtyCtrl = TextEditingController(text: '$maxQty');
    int qty = maxQty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        title: Text('🎒 $name Çek', style: const TextStyle(color: Colors.greenAccent)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Bankada: $maxQty adet', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Miktar:', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(filled: true, fillColor: Color(0xFF0F0F0F), border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
              onChanged: (v) => qty = (int.tryParse(v) ?? 1).clamp(1, maxQty),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black), child: const Text('✓ Çek')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _withdrawing = true);
    try {
      await SupabaseService.client.rpc('withdraw_from_bank', params: {'p_bank_item_ids': [id]});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name envanterinize taşındı')));
      ref.read(inventoryProvider.notifier).loadInventory();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  Future<void> _withdrawBatch() async {
    if (_selectedBankIds.isEmpty || _actionInProgress) return;
    setState(() => _withdrawing = true);
    try {
      await SupabaseService.client.rpc('withdraw_from_bank', params: {'p_bank_item_ids': _selectedBankIds.toList()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedBankIds.length} eşya envanterinize taşındı')));
      _selectedBankIds.clear();
      ref.read(inventoryProvider.notifier).loadInventory();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  // ─── Expand slots ─────────────────────────────────────────────────────────
  Future<void> _expandBank() async {
    if (_totalSlots >= _maxBankSlots) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maksimum slot sayısına ulaşıldı')));
      return;
    }
    if (_actionInProgress) return;
    final gemCost = _expandCost(_totalSlots);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        title: const Text('💎 Banka Genişletme', style: TextStyle(color: Color(0xFFFBBF24))),
        content: Text(
          'Banka slotlarını genişletmek için $gemCost 💎 harcamak istiyor musunuz?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black),
            child: Text('$gemCost 💎 Harca', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _expanding = true);
    try {
      await SupabaseService.client.rpc('expand_bank_slots', params: {'p_num_expansions': 1});
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Banka slotları genişletildi!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Genişletme başarısız: $e')));
    } finally {
      if (mounted) setState(() => _expanding = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Color _rarityColor(String? rarity) {
    switch ((rarity ?? '').toLowerCase()) {
      case 'uncommon': return const Color(0xFF22C55E);
      case 'rare':     return const Color(0xFF3B82F6);
      case 'epic':     return const Color(0xFFA855F7);
      case 'legendary':return const Color(0xFFF59E0B);
      case 'mythic':   return const Color(0xFFEF4444);
      default:         return const Color(0xFF94A3B8);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final logoutHandler = () async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    };

    final freeSlots = (_totalSlots - _usedSlots).clamp(0, _maxBankSlots);
    final fillPct = _totalSlots > 0 ? (_usedSlots / _totalSlots).clamp(0.0, 1.0) : 0.0;
    final bankTotalPages = (_maxBankSlots / _slotsPerPage).ceil();
    final bankStartIndex = (_bankPage - 1) * _slotsPerPage;

    return Scaffold(
      drawer: GameDrawer(onLogout: logoutHandler),
      appBar: GameTopBar(title: '🏦 Banka', onLogout: logoutHandler),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.bank),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D0D0D), Color(0xFF141414)])),
        child: SafeArea(
          child: Column(children: [
            // ── Stats card ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                child: Column(children: [
                  Row(children: [
                    _statCard('Toplam', '$_totalSlots', Icons.grid_view),
                    _statCard('Kullanılan', '$_usedSlots', Icons.inventory_2_outlined),
                    _statCard('Boş', '$freeSlots', Icons.add_box_outlined),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Doluluk: ${(fillPct * 100).round()}%', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: fillPct, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)), minHeight: 6, borderRadius: BorderRadius.circular(3)),
                    ])),
                    const SizedBox(width: 12),
                    if (_totalSlots < _maxBankSlots)
                      ElevatedButton(
                        onPressed: (_expanding || _actionInProgress) ? null : _expandBank,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                        child: _expanding ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Genişlet ${_expandCost(_totalSlots)}💎', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    else
                      const Text('Max Slot', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ]),
              ),
            ),
            // ── Tab selector ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                _buildTab(0, '🏦 Kasa'),
                const SizedBox(width: 8),
                _buildTab(1, '🎒 Envanter'),
              ]),
            ),
            // ── Batch action bar ───────────────────────────────────────────
            if (_tabIndex == 0 && _selectedBankIds.isNotEmpty)
              _batchBar('${_selectedBankIds.length} seçili', 'Çıkar (${_selectedBankIds.length})', Colors.redAccent, _withdrawing, _withdrawBatch),
            if (_tabIndex == 1 && _selectedInventoryRowIds.isNotEmpty)
              _batchBar('${_selectedInventoryRowIds.length} seçili', 'Yatır (${_selectedInventoryRowIds.length})', const Color(0xFF4ECDC4), _depositing, _depositBatch),
            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                  : _tabIndex == 0
                      ? _buildBankGrid(bankStartIndex, bankTotalPages)
                      : _buildInventoryList(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFFD700))),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]),
  );

  Widget _buildTab(int index, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _tabIndex = index; _selectedBankIds.clear(); _selectedInventoryRowIds.clear(); }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active ? const Color(0xFFFFD700).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: active ? const Color(0xFFFFD700) : Colors.white12),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: active ? const Color(0xFFFFD700) : Colors.white54, fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _batchBar(String selLabel, String actionLabel, Color actionColor, bool loading, VoidCallback onAction) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: Colors.white.withValues(alpha: 0.05),
    child: Row(children: [
      Text(selLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const Spacer(),
      TextButton(onPressed: () => setState(() { _selectedBankIds.clear(); _selectedInventoryRowIds.clear(); }), child: const Text('Temizle', style: TextStyle(color: Colors.white38, fontSize: 12))),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: loading ? null : onAction,
        style: ElevatedButton.styleFrom(backgroundColor: actionColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
        child: loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ]),
  );

  Widget _buildBankGrid(int bankStartIndex, int bankTotalPages) {
    final bankTotalPagesActual = (_maxBankSlots / _slotsPerPage).ceil();

    return Column(children: [
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, childAspectRatio: 0.9, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemCount: _slotsPerPage,
          itemBuilder: (ctx, i) {
            final globalSlotIndex = bankStartIndex + i;
            final isLocked = globalSlotIndex >= _totalSlots;
            final bankItem = _bankItems.firstWhere(
              (item) => ((item['slot_position'] ?? item['position']) as int?) == globalSlotIndex,
              orElse: () => {},
            );
            final hasItem = bankItem.isNotEmpty;
            final id = bankItem['id']?.toString() ?? '';
            final selected = _selectedBankIds.contains(id);
            final rarity = bankItem['rarity']?.toString();
            final rc = _rarityColor(rarity);
            final upgradeLevel = bankItem['upgrade_level'] as int? ?? bankItem['upgradeLevel'] as int? ?? 0;

            return GestureDetector(
              onTap: () {
                if (isLocked || !hasItem) return;
                setState(() {
                  if (selected) _selectedBankIds.remove(id);
                  else _selectedBankIds.add(id);
                });
              },
              onLongPress: hasItem && !isLocked ? () => _withdrawSingle(bankItem) : null,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selected ? const Color(0xFF4ECDC4) : hasItem ? const Color(0xFFFFD700).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                  color: selected ? const Color(0xFF1F3530) : hasItem ? const Color(0xFF151515) : Colors.transparent,
                ),
                child: isLocked
                    ? const Center(child: Text('🔒', style: TextStyle(fontSize: 16)))
                    : hasItem
                        ? Stack(children: [
                            Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: rc)),
                              const SizedBox(height: 2),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(bankItem['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
                              Text('x${bankItem['quantity'] ?? 1}', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 9, fontWeight: FontWeight.bold)),
                            ])),
                            if (upgradeLevel > 0) Positioned(top: 3, right: 3, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(4)),
                              child: Text('+$upgradeLevel', style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                            )),
                            Positioned(top: 2, left: 3, child: Text('#${globalSlotIndex + 1}', style: const TextStyle(color: Colors.white24, fontSize: 7))),
                          ])
                        : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.add, color: Colors.white12, size: 14),
                            Text('#${globalSlotIndex + 1}', style: const TextStyle(color: Colors.white12, fontSize: 7)),
                          ])),
              ),
            );
          },
        ),
      ),
      // Pagination
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: _bankPage > 1 ? () => setState(() => _bankPage--) : null, icon: const Icon(Icons.chevron_left, color: Color(0xFFFFD700))),
          Text('$_bankPage / $bankTotalPagesActual', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          IconButton(onPressed: _bankPage < bankTotalPagesActual ? () => setState(() => _bankPage++) : null, icon: const Icon(Icons.chevron_right, color: Color(0xFFFFD700))),
        ]),
      ),
    ]);
  }

  Widget _buildInventoryList() {
    final inventoryState = ref.watch(inventoryProvider);
    final items = inventoryState.items.where((item) => !item.isEquipped).toList();
    final totalPages = (items.length / _inventoryPerPage).ceil().clamp(1, 9999);
    final pageItems = items.skip((_inventoryPage - 1) * _inventoryPerPage).take(_inventoryPerPage).toList();

    if (items.isEmpty) {
      return const Center(child: Text('Envanterde eşya yok', style: TextStyle(color: Colors.white54)));
    }

    return Column(children: [
      // Select all header
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Text('${items.length} eşya', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              if (_selectedInventoryRowIds.length == pageItems.length) {
                for (final item in pageItems) _selectedInventoryRowIds.remove(item.rowId);
              } else {
                for (final item in pageItems) _selectedInventoryRowIds.add(item.rowId);
              }
            }),
            child: Text(_selectedInventoryRowIds.length == pageItems.length && pageItems.isNotEmpty ? 'Tümünü Kaldır' : 'Tümünü Seç', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          itemCount: pageItems.length,
          itemBuilder: (ctx, i) {
            final item = pageItems[i];
            final rc = _rarityColor(item.rarity.name);
            final selected = _selectedInventoryRowIds.contains(item.rowId);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) _selectedInventoryRowIds.remove(item.rowId);
                else _selectedInventoryRowIds.add(item.rowId);
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? const Color(0xFF4ECDC4) : rc.withValues(alpha: 0.35)),
                  color: selected ? const Color(0xFF0D1F1C) : Colors.white.withValues(alpha: 0.03),
                ),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: rc)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('x${item.quantity}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ])),
                  ElevatedButton(
                    onPressed: _actionInProgress ? null : () => _depositSingle(item),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4ECDC4), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Yatır', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      // Pagination
      if (totalPages > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: _inventoryPage > 1 ? () => setState(() => _inventoryPage--) : null, icon: const Icon(Icons.chevron_left, color: Color(0xFFFFD700))),
            Text('$_inventoryPage / $totalPages', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            IconButton(onPressed: _inventoryPage < totalPages ? () => setState(() => _inventoryPage++) : null, icon: const Icon(Icons.chevron_right, color: Color(0xFFFFD700))),
          ]),
        ),
    ]);
  }
}
