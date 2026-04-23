import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/inventory_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

const int _baseBankSlots = 100;
const int _maxBankSlots = 200;
const int _slotsPerPage = 20;
const int _inventoryPerPage = 20;

int _expandCost(int total) {
  if (total >= 175) return 500;
  if (total >= 150) return 200;
  if (total >= 125) return 100;
  return 50;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

enum _DragSourceType { inventory, bank }

class _DragPayload {
  const _DragPayload({
    required this.sourceType,
    required this.sourceId,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.isStackable,
  });

  final _DragSourceType sourceType;
  final String sourceId;
  final String itemId;
  final String name;
  final int quantity;
  final bool isStackable;
}

class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({super.key});

  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _bankItems = <Map<String, dynamic>>[];
  int _totalSlots = _baseBankSlots;
  int _usedSlots = 0;

  int _bankPage = 1;
  int _inventoryPage = 1;

  final Set<String> _selectedBankIds = <String>{};
  final Set<String> _selectedInventoryRowIds = <String>{};

  bool _depositing = false;
  bool _withdrawing = false;
  bool _expanding = false;
  bool get _actionInProgress => _depositing || _withdrawing || _expanding;

  final Map<String, bool> _stackableCache = <String, bool>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      await ref.read(inventoryProvider.notifier).loadInventory();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final dynamic accountRaw = await SupabaseService.client.rpc(
        'get_bank_account',
      );

      int totalSlots = _baseBankSlots;
      int usedSlots = 0;

      if (accountRaw is Map) {
        totalSlots = _asInt(
          accountRaw['total_slots'],
          fallback: _baseBankSlots,
        );
        usedSlots = _asInt(accountRaw['used_slots']);
      } else if (accountRaw is List && accountRaw.isNotEmpty) {
        final dynamic first = accountRaw[0];
        if (first is Map) {
          totalSlots = _asInt(first['total_slots'], fallback: _baseBankSlots);
          usedSlots = _asInt(first['used_slots']);
        }
      }

      final dynamic itemsRaw = await SupabaseService.client.rpc(
        'get_bank_items',
        params: <String, dynamic>{'p_category': null},
      );

      List<dynamic> rawList = <dynamic>[];
      if (itemsRaw is Map && itemsRaw['items'] is List) {
        rawList = itemsRaw['items'] as List<dynamic>;
      } else if (itemsRaw is List && itemsRaw.isNotEmpty) {
        final dynamic first = itemsRaw[0];
        if (first is Map && first['items'] is List) {
          rawList = first['items'] as List<dynamic>;
        } else {
          rawList = itemsRaw;
        }
      }

      final List<Map<String, dynamic>> bankItems = rawList
          .whereType<Map>()
          .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
          .where((Map<String, dynamic> row) => _asInt(row['quantity']) > 0)
          .toList();

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Banka yuklenemedi: $e')));
    }
  }

  Future<void> _refreshAll({bool silentInventory = true}) async {
    await Future.wait(<Future<void>>[
      _loadData(),
      ref
          .read(inventoryProvider.notifier)
          .loadInventory(silent: silentInventory),
    ]);
  }

  Map<String, dynamic>? _findBankItemAtSlot(int slotIndex) {
    for (final Map<String, dynamic> item in _bankItems) {
      final int pos = _asInt(
        item['slot_position'],
        fallback: _asInt(item['position'], fallback: -1),
      );
      if (pos == slotIndex) return item;
    }
    return null;
  }

  List<InventoryItem?> _buildInventorySlots(
    List<InventoryItem> items,
    int page,
  ) {
    final List<InventoryItem?> slots = List<InventoryItem?>.filled(
      _inventoryPerPage,
      null,
    );
    final int pageStart = (page - 1) * _inventoryPerPage;

    for (final InventoryItem item in items) {
      final int localIndex = item.slotPosition - pageStart;
      if (localIndex >= 0 && localIndex < _inventoryPerPage) {
        slots[localIndex] = item;
      }
    }

    int fillCursor = 0;
    for (final InventoryItem item in items) {
      if (item.slotPosition >= 0) continue;
      while (fillCursor < _inventoryPerPage && slots[fillCursor] != null) {
        fillCursor++;
      }
      if (fillCursor >= _inventoryPerPage) break;
      slots[fillCursor] = item;
      fillCursor++;
    }

    return slots;
  }

  Future<bool> _isStackableByItemId(String itemId, bool fallback) async {
    if (itemId.isEmpty) return fallback;
    if (_stackableCache.containsKey(itemId)) {
      return _stackableCache[itemId] ?? fallback;
    }

    try {
      final List<dynamic> rows = await SupabaseService.client
          .from('items')
          .select('max_stack')
          .eq('id', itemId)
          .limit(1);
      if (rows.isNotEmpty) {
        final dynamic row = rows.first;
        if (row is Map) {
          final int maxStack = _asInt(row['max_stack'], fallback: 1);
          final bool isStackable = maxStack > 1;
          _stackableCache[itemId] = isStackable;
          return isStackable;
        }
      }
    } catch (_) {
      // Fallback to caller data.
    }

    _stackableCache[itemId] = fallback;
    return fallback;
  }

  Future<int?> _askQuantity({
    required String title,
    required String subtitle,
    required int maxQuantity,
    required Color accent,
  }) async {
    if (maxQuantity <= 0) return null;

    int quantity = maxQuantity;
    final TextEditingController qtyCtrl = TextEditingController(
      text: '$maxQuantity',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A2030),
              title: Text(
                title,
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      const Text(
                        'Miktar:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFF0F0F0F),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                          ),
                          onChanged: (String value) {
                            final int parsed = _asInt(
                              value,
                              fallback: 1,
                            ).clamp(1, maxQuantity);
                            quantity = parsed;
                            setModalState(() {
                              qtyCtrl.value = TextEditingValue(
                                text: '$parsed',
                                selection: TextSelection.collapsed(
                                  offset: '$parsed'.length,
                                ),
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        children: <Widget>[
                          SizedBox(
                            height: 30,
                            child: IconButton(
                              splashRadius: 16,
                              onPressed: () {
                                quantity = (quantity + 1).clamp(1, maxQuantity);
                                setModalState(() => qtyCtrl.text = '$quantity');
                              },
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 30,
                            child: IconButton(
                              splashRadius: 16,
                              onPressed: () {
                                quantity = (quantity - 1).clamp(1, maxQuantity);
                                setModalState(() => qtyCtrl.text = '$quantity');
                              },
                              icon: const Icon(
                                Icons.remove,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Iptal',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Onayla'),
                ),
              ],
            );
          },
        );
      },
    );

    qtyCtrl.dispose();

    if (confirmed != true) return null;
    return quantity.clamp(1, maxQuantity);
  }

  Future<void> _performSwap({
    required _DragPayload payload,
    required _DragSourceType targetType,
    required int targetSlot,
    required String? targetId,
    required int quantity,
  }) async {
    if (_actionInProgress) return;
    if (quantity <= 0) return;

    if (payload.sourceType == _DragSourceType.bank &&
        targetType == _DragSourceType.inventory) {
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      final InventoryAddCheck addCheck = ref
          .read(inventoryProvider.notifier)
          .canAddItem(itemId: payload.itemId, quantity: quantity);
      if (!addCheck.canAdd) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(addCheck.reason ?? 'Envanter dolu!')),
          );
        }
        return;
      }
    }

    setState(() {
      if (payload.sourceType == _DragSourceType.inventory) {
        _depositing = true;
      } else {
        _withdrawing = true;
      }
    });

    try {
      await SupabaseService.client.rpc(
        'swap_inventory_bank',
        params: <String, dynamic>{
          'p_source_type': payload.sourceType == _DragSourceType.inventory
              ? 'inventory'
              : 'bank',
          'p_source_id': payload.sourceId,
          'p_target_type': targetType == _DragSourceType.inventory
              ? 'inventory'
              : 'bank',
          'p_target_id': targetId,
          'p_quantity': quantity,
          'p_target_slot': targetSlot,
        },
      );

      _selectedBankIds.clear();
      _selectedInventoryRowIds.clear();
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tasima basarisiz: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _depositing = false;
          _withdrawing = false;
        });
      }
    }
  }

  Future<void> _handleDrop({
    required _DragPayload payload,
    required _DragSourceType targetType,
    required int targetSlot,
    required String? targetId,
    required bool targetLocked,
  }) async {
    if (targetLocked || _actionInProgress) return;

    if (payload.sourceType == targetType) {
      if (targetType == _DragSourceType.bank && targetSlot >= _totalSlots)
        return;
    }

    if (payload.sourceType == _DragSourceType.inventory &&
        payload.sourceId.isEmpty)
      return;
    if (payload.sourceType == _DragSourceType.bank && payload.sourceId.isEmpty)
      return;

    final bool isStackable = await _isStackableByItemId(
      payload.itemId,
      payload.isStackable,
    );

    int transferQty = payload.quantity;
    if (isStackable && payload.quantity > 1) {
      final int? picked = await _askQuantity(
        title: payload.sourceType == _DragSourceType.inventory
            ? 'Envanterden Tasima'
            : 'Bankadan Tasima',
        subtitle: 'Maksimum: ${payload.quantity} adet',
        maxQuantity: payload.quantity,
        accent: const Color(0xFFFBBF24),
      );
      if (picked == null) return;
      transferQty = picked;
    }

    await _performSwap(
      payload: payload,
      targetType: targetType,
      targetSlot: targetSlot,
      targetId: targetId,
      quantity: transferQty,
    );
  }

  Future<void> _depositSingle(InventoryItem item) async {
    if (_actionInProgress) return;
    if (item.quantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yatirilacak gecerli miktar yok.')),
        );
      }
      return;
    }

    int qty = item.quantity;
    if (item.isStackable && item.quantity > 1) {
      final int? picked = await _askQuantity(
        title: 'Bankaya Aktar',
        subtitle: 'Envanterde: ${item.quantity} adet',
        maxQuantity: item.quantity,
        accent: const Color(0xFFFBBF24),
      );
      if (picked == null) return;
      qty = picked;
    }

    final _DragPayload payload = _DragPayload(
      sourceType: _DragSourceType.inventory,
      sourceId: item.rowId,
      itemId: item.itemId,
      name: item.name,
      quantity: item.quantity,
      isStackable: item.isStackable,
    );

    await _performSwap(
      payload: payload,
      targetType: _DragSourceType.bank,
      targetSlot: -1,
      targetId: null,
      quantity: qty,
    );
  }

  Future<void> _depositBatch() async {
    if (_selectedInventoryRowIds.isEmpty || _actionInProgress) return;

    final InventoryState inventoryState = ref.read(inventoryProvider);
    final List<InventoryItem> selectedRows = inventoryState.items
        .where((InventoryItem item) => !item.isEquipped)
        .where(
          (InventoryItem item) => _selectedInventoryRowIds.contains(item.rowId),
        )
        .where((InventoryItem item) => item.quantity > 0)
        .toList();

    if (selectedRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yatirilacak gecerli item secilmedi.')),
        );
      }
      return;
    }

    final List<String> rowIds = selectedRows
        .map((InventoryItem e) => e.rowId)
        .toList();
    final List<int> quantities = selectedRows
        .map((InventoryItem e) => e.quantity)
        .toList();

    setState(() => _depositing = true);
    try {
      await SupabaseService.client.rpc(
        'deposit_to_bank',
        params: <String, dynamic>{
          'p_item_row_ids': rowIds,
          'p_quantities': quantities,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${rowIds.length} esya bankaya yatirildi')),
      );
      _selectedInventoryRowIds.clear();
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _depositing = false);
    }
  }

  Future<void> _withdrawSingle(Map<String, dynamic> bankItem) async {
    if (_actionInProgress) return;

    final String id = bankItem['id']?.toString() ?? '';
    final String name = bankItem['name']?.toString() ?? 'Esya';
    final String itemId = bankItem['item_id']?.toString() ?? '';
    final int maxQty = _asInt(bankItem['quantity']);

    if (id.isEmpty || maxQty <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bankada cekilecek gecerli miktar yok.'),
          ),
        );
      }
      return;
    }

    int qty = maxQty;
    final bool stackable = await _isStackableByItemId(itemId, maxQty > 1);
    if (stackable && maxQty > 1) {
      final int? picked = await _askQuantity(
        title: 'Bankadan Cek',
        subtitle: 'Bankada: $maxQty adet',
        maxQuantity: maxQty,
        accent: Colors.greenAccent,
      );
      if (picked == null) return;
      qty = picked;
    }

    await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    final InventoryAddCheck addCheck = ref
        .read(inventoryProvider.notifier)
        .canAddItem(itemId: itemId, quantity: qty);
    if (!addCheck.canAdd) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(addCheck.reason ?? 'Envanter dolu!')),
        );
      }
      return;
    }

    setState(() => _withdrawing = true);
    try {
      await SupabaseService.client.rpc(
        'withdraw_from_bank',
        params: <String, dynamic>{
          'p_bank_item_ids': <String>[id],
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name envanterinize tasindi')));
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  Future<void> _withdrawBatch() async {
    if (_selectedBankIds.isEmpty || _actionInProgress) return;

    final List<Map<String, dynamic>> selectedRows = _bankItems.where((
      Map<String, dynamic> row,
    ) {
      final String rid = row['id']?.toString() ?? '';
      return rid.isNotEmpty && _selectedBankIds.contains(rid);
    }).toList();

    final List<String> validIds = <String>[];
    final Map<String, int> demandByItem = <String, int>{};

    for (final Map<String, dynamic> row in selectedRows) {
      final String rid = row['id']?.toString() ?? '';
      final String itemId = row['item_id']?.toString() ?? '';
      final int qty = _asInt(row['quantity']);
      if (rid.isEmpty || qty <= 0) continue;
      validIds.add(rid);
      if (itemId.isNotEmpty) {
        demandByItem[itemId] = (demandByItem[itemId] ?? 0) + qty;
      }
    }

    if (validIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cekilecek gecerli banka itemi yok.')),
        );
      }
      return;
    }

    await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    for (final MapEntry<String, int> entry in demandByItem.entries) {
      final InventoryAddCheck addCheck = ref
          .read(inventoryProvider.notifier)
          .canAddItem(itemId: entry.key, quantity: entry.value);
      if (!addCheck.canAdd) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(addCheck.reason ?? 'Envanter dolu!')),
          );
        }
        return;
      }
    }

    setState(() => _withdrawing = true);
    try {
      await SupabaseService.client.rpc(
        'withdraw_from_bank',
        params: <String, dynamic>{'p_bank_item_ids': validIds},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${validIds.length} esya envanterinize tasindi'),
        ),
      );
      _selectedBankIds.clear();
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  Future<void> _expandBank() async {
    if (_totalSlots >= _maxBankSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimum slot sayisina ulasildi')),
      );
      return;
    }
    if (_actionInProgress) return;

    final int gemCost = _expandCost(_totalSlots);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        title: const Text(
          'Banka Genisletme',
          style: TextStyle(color: Color(0xFFFBBF24)),
        ),
        content: Text(
          'Banka slotlarini genisletmek icin $gemCost gem harcamak istiyor musunuz?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Iptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBBF24),
              foregroundColor: Colors.black,
            ),
            child: Text(
              '$gemCost gem harca',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _expanding = true);
    try {
      await SupabaseService.client.rpc(
        'expand_bank_slots',
        params: <String, dynamic>{'p_num_expansions': 1},
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banka slotlari genisletildi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Genisletme basarisiz: $e')));
    } finally {
      if (mounted) setState(() => _expanding = false);
    }
  }

  Color _rarityColor(String? rarity) {
    switch ((rarity ?? '').toLowerCase()) {
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

  Widget _buildItemIcon({required String icon, required Color rarityColor}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: rarityColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rarityColor.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        icon.isEmpty ? '📦' : icon,
        style: const TextStyle(fontSize: 20),
      ),
    );
  }

  Widget _buildInventorySlot({
    required InventoryItem? item,
    required int globalSlotIndex,
    required bool isDragTargetActive,
  }) {
    final bool hasItem = item != null;
    final String id = item?.rowId ?? '';
    final bool selected = hasItem && _selectedInventoryRowIds.contains(id);
    final Color rarityColor = hasItem
        ? _rarityColor(item.rarity.name)
        : Colors.white24;

    final Widget slotBody = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDragTargetActive
              ? const Color(0xFF4ECDC4)
              : selected
              ? const Color(0xFF4ECDC4)
              : hasItem
              ? rarityColor.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: isDragTargetActive ? 1.8 : 1,
        ),
        color: isDragTargetActive
            ? const Color(0xFF17322E)
            : selected
            ? const Color(0xFF1F3530)
            : hasItem
            ? const Color(0xFF151515)
            : Colors.transparent,
      ),
      child: hasItem
          ? Stack(
              children: <Widget>[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _buildItemIcon(icon: item.icon, rarityColor: rarityColor),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          item.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.quantity > 1)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (item.enhancementLevel > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${item.enhancementLevel}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 4,
                  top: 3,
                  child: Text(
                    '#${globalSlotIndex + 1}',
                    style: const TextStyle(color: Colors.white24, fontSize: 7),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.add, color: Colors.white12, size: 14),
                  Text(
                    '#${globalSlotIndex + 1}',
                    style: const TextStyle(color: Colors.white12, fontSize: 7),
                  ),
                ],
              ),
            ),
    );

    final Widget interactive = GestureDetector(
      onTap: !hasItem
          ? null
          : () {
              setState(() {
                if (selected) {
                  _selectedInventoryRowIds.remove(id);
                } else {
                  _selectedInventoryRowIds.add(id);
                }
              });
            },
      onLongPress: !hasItem ? null : () => _depositSingle(item),
      child: slotBody,
    );

    if (!hasItem) return interactive;

    final _DragPayload payload = _DragPayload(
      sourceType: _DragSourceType.inventory,
      sourceId: item.rowId,
      itemId: item.itemId,
      name: item.name,
      quantity: item.quantity,
      isStackable: item.isStackable,
    );

    return LongPressDraggable<_DragPayload>(
      data: payload,
      delay: const Duration(milliseconds: 120),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 74, height: 86, child: slotBody),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: interactive),
      child: interactive,
    );
  }

  Widget _buildBankSlot({
    required Map<String, dynamic>? item,
    required int globalSlotIndex,
    required bool isLocked,
    required bool isDragTargetActive,
  }) {
    final bool hasItem = item != null;
    final String id = hasItem ? item['id']?.toString() ?? '' : '';
    final bool selected = hasItem && _selectedBankIds.contains(id);
    final Color rarityColor = hasItem
        ? _rarityColor(item['rarity']?.toString())
        : Colors.white24;
    final int qty = hasItem ? _asInt(item['quantity']) : 0;
    final int upgradeLevel = hasItem
        ? _asInt(item['upgrade_level'], fallback: _asInt(item['upgradeLevel']))
        : 0;

    final Widget slotBody = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLocked
              ? Colors.white12
              : isDragTargetActive
              ? const Color(0xFF4ECDC4)
              : selected
              ? const Color(0xFF4ECDC4)
              : hasItem
              ? const Color(0xFFFBBF24).withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
          width: isDragTargetActive ? 1.8 : 1,
        ),
        color: isLocked
            ? Colors.black.withValues(alpha: 0.28)
            : isDragTargetActive
            ? const Color(0xFF17322E)
            : selected
            ? const Color(0xFF1F3530)
            : hasItem
            ? const Color(0xFF151515)
            : Colors.transparent,
      ),
      child: isLocked
          ? const Center(child: Text('🔒', style: TextStyle(fontSize: 16)))
          : hasItem
          ? Stack(
              children: <Widget>[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _buildItemIcon(
                        icon: item['icon']?.toString() ?? '',
                        rarityColor: rarityColor,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          item['name']?.toString() ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (qty > 1)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (upgradeLevel > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+$upgradeLevel',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 4,
                  top: 3,
                  child: Text(
                    '#${globalSlotIndex + 1}',
                    style: const TextStyle(color: Colors.white24, fontSize: 7),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.add, color: Colors.white12, size: 14),
                  Text(
                    '#${globalSlotIndex + 1}',
                    style: const TextStyle(color: Colors.white12, fontSize: 7),
                  ),
                ],
              ),
            ),
    );

    final Widget interactive = GestureDetector(
      onTap: (!hasItem || isLocked)
          ? null
          : () {
              setState(() {
                if (selected) {
                  _selectedBankIds.remove(id);
                } else {
                  _selectedBankIds.add(id);
                }
              });
            },
      onLongPress: (!hasItem || isLocked) ? null : () => _withdrawSingle(item),
      child: slotBody,
    );

    if (!hasItem || isLocked) return interactive;

    final String itemId = item['item_id']?.toString() ?? '';
    final String name = item['name']?.toString() ?? 'Esya';

    final _DragPayload payload = _DragPayload(
      sourceType: _DragSourceType.bank,
      sourceId: id,
      itemId: itemId,
      name: name,
      quantity: qty,
      isStackable: qty > 1,
    );

    return LongPressDraggable<_DragPayload>(
      data: payload,
      delay: const Duration(milliseconds: 120),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 74, height: 86, child: slotBody),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: interactive),
      child: interactive,
    );
  }

  Widget _sectionHeader({
    required String title,
    required String actionText,
    required Color actionColor,
    required bool enabled,
    required bool loading,
    required VoidCallback onAction,
    required int selectedCount,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          if (selectedCount > 0)
            Text(
              '$selectedCount secili',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          const Spacer(),
          if (selectedCount > 0)
            TextButton(
              onPressed: onClear,
              child: const Text(
                'Temizle',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ElevatedButton(
            onPressed: (!enabled || loading) ? null : onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    actionText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryArea() {
    final InventoryState inventoryState = ref.watch(inventoryProvider);
    final List<InventoryItem> items = inventoryState.items
        .where((InventoryItem item) => !item.isEquipped)
        .where((InventoryItem item) => item.quantity > 0)
        .toList();

    final int totalPages = (items.length / _inventoryPerPage).ceil().clamp(
      1,
      9999,
    );
    if (_inventoryPage > totalPages) {
      _inventoryPage = totalPages;
    }

    final List<InventoryItem?> pageSlots = _buildInventorySlots(
      items,
      _inventoryPage,
    );
    final int pageStart = (_inventoryPage - 1) * _inventoryPerPage;

    return Expanded(
      child: Column(
        children: <Widget>[
          _sectionHeader(
            title: 'Envanter',
            actionText:
                'Secilenleri Yatir (${_selectedInventoryRowIds.length})',
            actionColor: const Color(0xFF4ECDC4),
            enabled: _selectedInventoryRowIds.isNotEmpty,
            loading: _depositing,
            onAction: _depositBatch,
            selectedCount: _selectedInventoryRowIds.length,
            onClear: () => setState(_selectedInventoryRowIds.clear),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.90,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _inventoryPerPage,
              itemBuilder: (BuildContext context, int index) {
                final int globalSlotIndex = pageStart + index;
                final InventoryItem? item = pageSlots[index];
                final String? targetId = item?.rowId;

                return DragTarget<_DragPayload>(
                  onWillAcceptWithDetails:
                      (DragTargetDetails<_DragPayload> details) {
                        if (_actionInProgress) return false;
                        if (details.data.sourceType ==
                                _DragSourceType.inventory &&
                            details.data.sourceId == targetId) {
                          return false;
                        }
                        return true;
                      },
                  onAcceptWithDetails:
                      (DragTargetDetails<_DragPayload> details) {
                        unawaited(
                          _handleDrop(
                            payload: details.data,
                            targetType: _DragSourceType.inventory,
                            targetSlot: globalSlotIndex,
                            targetId: targetId,
                            targetLocked: false,
                          ),
                        );
                      },
                  builder:
                      (
                        BuildContext context,
                        List<_DragPayload?> candidateData,
                        List<dynamic> rejectedData,
                      ) {
                        return _buildInventorySlot(
                          item: item,
                          globalSlotIndex: globalSlotIndex,
                          isDragTargetActive: candidateData.isNotEmpty,
                        );
                      },
                );
              },
            ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    onPressed: _inventoryPage > 1
                        ? () => setState(() => _inventoryPage--)
                        : null,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                  Text(
                    '$_inventoryPage / $totalPages',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  IconButton(
                    onPressed: _inventoryPage < totalPages
                        ? () => setState(() => _inventoryPage++)
                        : null,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBankArea() {
    final int bankTotalPages = (_maxBankSlots / _slotsPerPage).ceil();
    if (_bankPage > bankTotalPages) {
      _bankPage = bankTotalPages;
    }

    final int bankStartIndex = (_bankPage - 1) * _slotsPerPage;

    return Expanded(
      child: Column(
        children: <Widget>[
          _sectionHeader(
            title: 'Banka',
            actionText: 'Secilenleri Cek (${_selectedBankIds.length})',
            actionColor: Colors.redAccent,
            enabled: _selectedBankIds.isNotEmpty,
            loading: _withdrawing,
            onAction: _withdrawBatch,
            selectedCount: _selectedBankIds.length,
            onClear: () => setState(_selectedBankIds.clear),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.90,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _slotsPerPage,
              itemBuilder: (BuildContext context, int index) {
                final int globalSlotIndex = bankStartIndex + index;
                final bool isLocked = globalSlotIndex >= _totalSlots;
                final Map<String, dynamic>? item = _findBankItemAtSlot(
                  globalSlotIndex,
                );
                final String? targetId = item?['id']?.toString();

                return DragTarget<_DragPayload>(
                  onWillAcceptWithDetails:
                      (DragTargetDetails<_DragPayload> details) {
                        if (_actionInProgress || isLocked) return false;
                        if (details.data.sourceType == _DragSourceType.bank &&
                            details.data.sourceId == targetId) {
                          return false;
                        }
                        return true;
                      },
                  onAcceptWithDetails:
                      (DragTargetDetails<_DragPayload> details) {
                        unawaited(
                          _handleDrop(
                            payload: details.data,
                            targetType: _DragSourceType.bank,
                            targetSlot: globalSlotIndex,
                            targetId: targetId,
                            targetLocked: isLocked,
                          ),
                        );
                      },
                  builder:
                      (
                        BuildContext context,
                        List<_DragPayload?> candidateData,
                        List<dynamic> rejectedData,
                      ) {
                        return _buildBankSlot(
                          item: item,
                          globalSlotIndex: globalSlotIndex,
                          isLocked: isLocked,
                          isDragTargetActive: candidateData.isNotEmpty,
                        );
                      },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  onPressed: _bankPage > 1
                      ? () => setState(() => _bankPage--)
                      : null,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFFFBBF24),
                  ),
                ),
                Text(
                  '$_bankPage / $bankTotalPages',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                IconButton(
                  onPressed: _bankPage < bankTotalPages
                      ? () => setState(() => _bankPage++)
                      : null,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final int freeSlots = (_totalSlots - _usedSlots).clamp(0, _maxBankSlots);
    final double fillPct = _totalSlots > 0
        ? (_usedSlots / _totalSlots).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                _statCard('Toplam', '$_totalSlots'),
                _statCard('Kullanilan', '$_usedSlots'),
                _statCard('Bos', '$freeSlots'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Doluluk: ${(fillPct * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: fillPct,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFBBF24),
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_totalSlots < _maxBankSlots)
                  ElevatedButton(
                    onPressed: (_expanding || _actionInProgress)
                        ? null
                        : _expandBank,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFBBF24),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: _expanding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Genislet ${_expandCost(_totalSlots)} gem',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  )
                else
                  const Text(
                    'Max Slot',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFFFBBF24),
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Future<void> Function() logoutHandler = () async {
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
            colors: <Color>[Color(0xFF0D0D0D), Color(0xFF141414)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFBBF24)),
                )
              : Column(
                  children: <Widget>[
                    _buildStatsCard(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          _buildInventoryArea(),
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          _buildBankArea(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
