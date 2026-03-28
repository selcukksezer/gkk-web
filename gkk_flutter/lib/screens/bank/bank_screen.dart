import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/layout/game_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_model.dart';
import '../../routing/app_router.dart';
import '../../core/services/supabase_service.dart';

class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({super.key});

  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _bankItems = [];
  int _totalSlots = 100;
  int _usedSlots = 0;
  int _tabIndex = 0;
  bool _expanding = false;

  static const int _baseSlots = 100;
  static const int _maxSlots = 200;

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
      int totalSlots = _baseSlots;
      int usedSlots = 0;
      if (accountRaw is Map) {
        totalSlots = (accountRaw['total_slots'] as int?) ?? _baseSlots;
        usedSlots = (accountRaw['used_slots'] as int?) ?? 0;
      }

      final itemsRaw = await SupabaseService.client.rpc('get_bank_items', params: {'p_category': null});
      List<dynamic> rawList = [];
      if (itemsRaw is Map && itemsRaw['items'] != null) {
        rawList = itemsRaw['items'] as List;
      } else if (itemsRaw is List) {
        rawList = itemsRaw;
      }
      final bankItems = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (!mounted) return;
      setState(() {
        _totalSlots = totalSlots;
        _usedSlots = usedSlots;
        _bankItems = bankItems;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Banka verileri yüklenemedi: $e')));
    }
  }

  int _getExpandCost() {
    if (_totalSlots < 125) return 50;
    if (_totalSlots < 150) return 100;
    if (_totalSlots < 175) return 200;
    return 500;
  }

  Future<void> _expandSlots() async {
    if (_totalSlots >= _maxSlots) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maksimum slot sayısına ulaşıldı')));
      return;
    }
    setState(() => _expanding = true);
    try {
      await SupabaseService.client.rpc('expand_bank_slots');
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot genişletildi!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _expanding = false);
    }
  }

  Future<void> _depositDialog(InventoryItem item) async {
    final controller = TextEditingController(text: '1');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2538),
        title: Text('${item.name} Yatır', style: const TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Miktar (maks: ${item.quantity})', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Color(0xFF2A3248),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Yatır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final qty = (int.tryParse(controller.text) ?? 1).clamp(1, item.quantity);
    try {
      await SupabaseService.client.rpc('deposit_to_bank', params: {'p_inventory_item_id': item.rowId, 'p_quantity': qty});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} bankaya yatırıldı')));
      ref.read(inventoryProvider.notifier).loadInventory();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _withdrawDialog(Map<String, dynamic> bankItem) async {
    final maxQty = (bankItem['quantity'] as int?) ?? 1;
    final controller = TextEditingController(text: '1');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2538),
        title: Text('${bankItem['name'] ?? 'Eşya'} Çek', style: const TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Miktar (maks: $maxQty)', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Color(0xFF2A3248),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
            child: const Text('Çek'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final qty = (int.tryParse(controller.text) ?? 1).clamp(1, maxQty);
    try {
      await SupabaseService.client.rpc('withdraw_from_bank', params: {'p_bank_item_id': bankItem['id'], 'p_quantity': qty});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${bankItem['name']} envanterinize taşındı')));
      ref.read(inventoryProvider.notifier).loadInventory();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
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
      appBar: GameTopBar(title: '🏦 Banka', onLogout: logoutHandler),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.bank),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Text('Slot: $_usedSlots / $_totalSlots',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                if (_totalSlots < _maxSlots)
                  TextButton(
                    onPressed: _expanding ? null : _expandSlots,
                    child: Text('Genişlet (${_getExpandCost()}💎)',
                        style: const TextStyle(color: Color(0xFF3B82F6))),
                  )
                else
                  const Text('Maks. Slot',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _buildTab(0, '🏦 Kasa'),
                const SizedBox(width: 8),
                _buildTab(1, '🎒 Envanter'),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                  : _tabIndex == 0
                      ? _buildKasaTab()
                      : _buildEnvanterTab(),
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
            borderRadius: BorderRadius.circular(8),
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

  Widget _buildKasaTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _totalSlots,
      itemBuilder: (ctx, i) {
        if (i < _bankItems.length) {
          final item = _bankItems[i];
          final rarity = (item['rarity'] as String?) ?? 'common';
          return GestureDetector(
            onTap: () => _withdrawDialog(item),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _rarityColor(rarity).withValues(alpha: 0.5)),
                color: _rarityColor(rarity).withValues(alpha: 0.08),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _rarityColor(rarity)),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    (item['name'] as String?) ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 9),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'x${(item['quantity'] as int?) ?? 1}',
                  style: const TextStyle(
                      color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: Colors.white.withValues(alpha: 0.02),
          ),
          child: const Center(child: Icon(Icons.add, color: Colors.white12, size: 16)),
        );
      },
    );
  }

  Widget _buildEnvanterTab() {
    final inventoryState = ref.watch(inventoryProvider);
    final inventoryItems = inventoryState.items.where((item) => !item.isEquipped).toList();
    if (inventoryItems.isEmpty) {
      return const Center(
          child: Text('Envanterde eşya yok', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: inventoryItems.length,
      itemBuilder: (ctx, i) {
        final item = inventoryItems[i];
        final rarity = item.rarity.name;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _rarityColor(rarity).withValues(alpha: 0.4)),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _rarityColor(rarity)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text('x${item.quantity}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
            ElevatedButton(
              onPressed: () => _depositDialog(item),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Yatır', style: TextStyle(fontSize: 12)),
            ),
          ]),
        );
      },
    );
  }
}
