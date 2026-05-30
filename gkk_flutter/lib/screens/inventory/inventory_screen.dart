import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_chrome.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadInventory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Inventory',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.inventory),
      body: switch (inventoryState.status) {
        InventoryStatus.initial || InventoryStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        InventoryStatus.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(inventoryState.errorMessage ?? 'Envanter yuklenemedi.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.read(inventoryProvider.notifier).loadInventory(),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          ),
        InventoryStatus.ready => _InventoryReadyView(state: inventoryState),
      },
    );
  }
}

class _InventoryReadyView extends StatelessWidget {
  const _InventoryReadyView({required this.state});

  final InventoryState state;

  @override
  Widget build(BuildContext context) {
    return _InventoryReadyInteractive(state: state);
  }
}

class _InventoryReadyInteractive extends ConsumerStatefulWidget {
  const _InventoryReadyInteractive({required this.state});

  final InventoryState state;

  @override
  ConsumerState<_InventoryReadyInteractive> createState() => _InventoryReadyInteractiveState();
}

class _InventoryReadyInteractiveState extends ConsumerState<_InventoryReadyInteractive> {
  String? _selectedRowId;
  _InventoryFilter _activeFilter = _InventoryFilter.all;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleUnequip(String slot) async {
    final ok = await ref.read(inventoryProvider.notifier).unequipItem(slot: slot);
    if (!ok) {
      if (!mounted) return;
      final error = ref.read(inventoryProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Islem basarisiz')),
      );
    }
  }

  Future<void> _handleEquip(InventoryItem item) async {
    final String slot = item.equipSlot.name;
    if (slot == 'none') return;

    final ok = await ref.read(inventoryProvider.notifier).equipItem(
          rowId: item.rowId,
          slot: slot,
        );

    if (!ok) {
      if (!mounted) return;
      final error = ref.read(inventoryProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Kusanma basarisiz')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedRowId = null;
    });
  }

  Future<void> _handleSwap(int fromSlot, int toSlot) async {
    if (fromSlot == toSlot) return;

    final ok = await ref.read(inventoryProvider.notifier).swapSlots(
          fromSlot: fromSlot,
          toSlot: toSlot,
        );

    if (!ok) {
      if (!mounted) return;
      final error = ref.read(inventoryProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Slot degistirme basarisiz')),
      );
    }
  }

  Future<void> _handleMoveItemToSlot(String rowId, int targetSlot) async {
    final ok = await ref.read(inventoryProvider.notifier).moveItemToSlot(
          rowId: rowId,
          targetSlot: targetSlot,
        );
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Item tasima basarisiz');
    }
  }

  Future<void> _handleUnequipToSlot({
    required String rowId,
    required String equipSlot,
    required int targetSlot,
  }) async {
    final ok = await ref.read(inventoryProvider.notifier).unequipItemToSlot(
          rowId: rowId,
          slot: equipSlot,
          targetSlot: targetSlot,
        );
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Kusanilan item hedef slota birakilamadi');
    }
  }

  Future<void> _handleSwapEquipWithSlot({
    required String equipSlot,
    required int targetSlot,
  }) async {
    final ok = await ref.read(inventoryProvider.notifier).swapEquipWithSlot(
          equipSlot: equipSlot,
          targetSlot: targetSlot,
        );
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Kusanilan item swap basarisiz');
    }
  }

  Future<void> _handleDropOnInventorySlot({
    required _DragPayload payload,
    required int targetSlot,
    required InventoryItem? targetItem,
  }) async {
    if (payload.item.isEquipped) {
      final String equipSlot = payload.equipSlot ?? payload.item.equippedSlot;
      if (equipSlot.isEmpty) {
        _showSnack('Kusanilan item slotu tespit edilemedi.');
        return;
      }

      if (targetItem == null) {
        await _handleUnequipToSlot(
          rowId: payload.item.rowId,
          equipSlot: equipSlot,
          targetSlot: targetSlot,
        );
        return;
      }

      await _handleSwapEquipWithSlot(
        equipSlot: equipSlot,
        targetSlot: targetSlot,
      );
      return;
    }

    final int fromSlot = payload.item.slotPosition;
    if (fromSlot == targetSlot) return;

    if (targetItem == null) {
      await _handleMoveItemToSlot(payload.item.rowId, targetSlot);
      return;
    }

    await _handleSwap(fromSlot, targetSlot);
  }

  Future<void> _handleDropOnEquipSlot({
    required _DragPayload payload,
    required String targetEquipSlot,
    required InventoryItem? occupiedInTarget,
  }) async {
    final String normalized = targetEquipSlot.toLowerCase();

    if (payload.item.equipSlot.name.toLowerCase() != normalized) {
      _showSnack('Bu item bu slota kusanamaz.');
      return;
    }

    if (payload.item.isEquipped) {
      if (payload.item.equippedSlot.toLowerCase() == normalized) return;
      _showSnack('Kusanili item baska kusan slotuna suruklenemez.');
      return;
    }

    if (occupiedInTarget != null && occupiedInTarget.rowId != payload.item.rowId) {
      await _handleSwapEquipWithSlot(
        equipSlot: normalized,
        targetSlot: payload.item.slotPosition,
      );
      return;
    }

    await _handleEquip(payload.item);
  }

  Future<void> _handleUse(InventoryItem item) async {
    if (item.itemType != ItemType.potion && item.itemType != ItemType.consumable) {
      _showSnack('Bu item kullanilamaz.');
      return;
    }

    final bool ok = await ref.read(inventoryProvider.notifier).useItem(item: item);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Item kullanimi basarisiz.');
      return;
    }
    _showSnack('${item.name} kullanildi.');
  }

  Future<void> _handleSell(InventoryItem item) async {
    if (!item.isTradeable) {
      _showSnack('Bu item satilamaz.');
      return;
    }

    final int? quantity = await showDialog<int>(
      context: context,
      builder: (context) => _QuantityActionDialog(
        title: 'Item Sat',
        subtitle: '${item.name} satmak istedigin miktari sec.',
        confirmLabel: 'Sat',
        unitValue: item.vendorSellPrice,
        maxQuantity: item.quantity,
      ),
    );

    if (quantity == null) return;
    final result = await ref.read(inventoryProvider.notifier).sellItemByRow(
          rowId: item.rowId,
          quantity: quantity,
        );
    if (!result.success) {
      _showSnack(result.error ?? 'Satis basarisiz.');
      return;
    }
    _showSnack('$quantity adet ${item.name} satildi (+${result.goldEarned} altin).');
  }

  Future<void> _handleSplit(InventoryItem item) async {
    if (!item.isStackable || item.quantity <= 1) {
      _showSnack('Bu item bolunemez.');
      return;
    }

    final int? quantity = await showDialog<int>(
      context: context,
      builder: (context) => _QuantityActionDialog(
        title: 'Stack Bol',
        subtitle: 'Yeni stack icin miktar sec.',
        confirmLabel: 'Bol',
        unitValue: 0,
        maxQuantity: item.quantity - 1,
        showTotalValue: false,
      ),
    );

    if (quantity == null) return;
    final bool ok = await ref.read(inventoryProvider.notifier).splitStack(
          rowId: item.rowId,
          splitQuantity: quantity,
        );
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Stack bolme basarisiz.');
      return;
    }
    _showSnack('$quantity adet ${item.name} ayrildi.');
  }

  Future<void> _handleDelete(InventoryItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Sil'),
        content: Text('${item.name} itemini cop kutusuna gondermek istiyor musun?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final bool ok = await ref.read(inventoryProvider.notifier).trashItem(rowId: item.rowId);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Silme basarisiz.');
      return;
    }
    _showSnack('${item.name} silindi.');
  }

  Future<void> _handleToggleFavorite(InventoryItem item) async {
    final bool target = !item.isFavorite;
    final bool ok = await ref.read(inventoryProvider.notifier).toggleFavorite(
          rowId: item.rowId,
          isFavorite: target,
        );
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Favori guncellenemedi.');
      return;
    }
    _showSnack(target ? 'Favorilere eklendi.' : 'Favorilerden cikarildi.');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final state = widget.state;
        final bool isWide = constraints.maxWidth >= 980;
        final int occupiedSlots = state.items.where((item) => !item.isEquipped).length;

        return Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF090D14), Color(0xFF101722), Color(0xFF090D14)],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SummaryBar(state: state),
                  const SizedBox(height: 12),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('Kusanilanlar', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 10),
                                _EquippedPanel(
                                  equippedItems: state.equippedItems,
                                  onUnequip: _handleUnequip,
                                  onDropToSlot: (payload, slotName, occupied) => _handleDropOnEquipSlot(
                                    payload: payload,
                                    targetEquipSlot: slotName,
                                    occupiedInTarget: occupied,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 7,
                          child: _inventoryCard(state, occupiedSlots),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Kusanilanlar', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          _EquippedPanel(
                            equippedItems: state.equippedItems,
                            onUnequip: _handleUnequip,
                            onDropToSlot: (payload, slotName, occupied) => _handleDropOnEquipSlot(
                              payload: payload,
                              targetEquipSlot: slotName,
                              occupiedInTarget: occupied,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _inventoryCard(state, occupiedSlots),
                  ],
                  const SizedBox(height: 16),
                  _SelectedItemPanel(
                    item: _selectedItem(state.items),
                    onEquip: _handleEquip,
                    onUse: _handleUse,
                    onSell: _handleSell,
                    onSplit: _handleSplit,
                    onDelete: _handleDelete,
                    onToggleFavorite: _handleToggleFavorite,
                    isFavorite: _selectedItem(state.items)?.isFavorite ?? false,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _inventoryCard(InventoryState state, int occupiedSlots) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text('ENVANTER', style: TextStyle(fontSize: 10, letterSpacing: 1.5)),
                  SizedBox(height: 2),
                  Text('Esyalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                  color: Colors.black26,
                ),
                child: Text('$occupiedSlots/$inventoryCapacity', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InventoryFilterBar(
            activeFilter: _activeFilter,
            onChanged: (filter) {
              setState(() {
                _activeFilter = filter;
              });
            },
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: inventoryCapacity,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final rawItem = _getItemBySlot(state.items, index);
              final item = (rawItem != null && _matchesFilter(rawItem, _activeFilter)) ? rawItem : null;
              final card = _InventorySlotCard(
                item: item,
                slotIndex: index,
                isSelected: item != null && item.rowId == _selectedRowId,
                onTap: item == null
                    ? null
                    : () {
                        setState(() {
                          _selectedRowId = item.rowId;
                        });
                      },
              );

                final Widget draggable = item == null
                  ? card
                  : LongPressDraggable<_DragPayload>(
                    data: _DragPayload.fromInventory(item),
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: _InventorySlotCard(
                            item: item,
                            slotIndex: index,
                            isSelected: false,
                            onTap: null,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: card,
                      ),
                      child: card,
                    );

              return DragTarget<_DragPayload>(
                onWillAcceptWithDetails: (details) {
                  final data = details.data;
                  if (!data.item.isEquipped && data.item.slotPosition == index) return false;
                  if (data.item.isEquipped && data.item.equippedSlot.isEmpty) return false;
                  return true;
                },
                onAcceptWithDetails: (details) => _handleDropOnInventorySlot(
                  payload: details.data,
                  targetSlot: index,
                  targetItem: rawItem,
                ),
                builder: (context, candidateData, rejectedData) {
                  final bool highlighted = candidateData.isNotEmpty;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: highlighted
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: draggable,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(InventoryItem item, _InventoryFilter filter) {
    switch (filter) {
      case _InventoryFilter.all:
        return true;
      case _InventoryFilter.weapon:
        return item.itemType == ItemType.weapon;
      case _InventoryFilter.armor:
        return item.itemType == ItemType.armor;
      case _InventoryFilter.potion:
        return item.itemType == ItemType.potion || item.itemType == ItemType.consumable;
      case _InventoryFilter.material:
        return item.itemType == ItemType.material;
    }
  }

  InventoryItem? _selectedItem(List<InventoryItem> items) {
    if (_selectedRowId == null) return null;
    for (final item in items) {
      if (item.rowId == _selectedRowId) return item;
    }
    return null;
  }

  InventoryItem? _getItemBySlot(List<InventoryItem> items, int slot) {
    for (final item in items) {
      if (item.slotPosition == slot) return item;
    }
    return null;
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.state});

  final InventoryState state;

  @override
  Widget build(BuildContext context) {
    final int usedSlots = state.items
        .map((e) => e.slotPosition)
        .where((slot) => slot >= 0 && slot < inventoryCapacity)
        .toSet()
        .length;
    final int totalValue = state.items.fold<int>(0, (sum, item) => sum + (item.vendorSellPrice * item.quantity));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Dolu Slot: $usedSlots/$inventoryCapacity'),
            Text('Satis Degeri: $totalValue'),
          ],
        ),
      ),
    );
  }
}

enum _InventoryFilter {
  all,
  weapon,
  armor,
  potion,
  material,
}

class _InventoryFilterBar extends StatelessWidget {
  const _InventoryFilterBar({
    required this.activeFilter,
    required this.onChanged,
  });

  final _InventoryFilter activeFilter;
  final ValueChanged<_InventoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = <(_InventoryFilter, String, String)>[
      (_InventoryFilter.all, 'Hepsi', '📦'),
      (_InventoryFilter.weapon, 'Silahlar', '⚔️'),
      (_InventoryFilter.armor, 'Zirh', '🛡️'),
      (_InventoryFilter.potion, 'Iksirler', '🧪'),
      (_InventoryFilter.material, 'Malzeme', '🪨'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((entry) {
        final bool selected = entry.$1 == activeFilter;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => onChanged(entry.$1),
          avatar: Text(entry.$3),
          label: Text(entry.$2),
        );
      }).toList(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xF0141B26), Color(0xF0090D15)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x55000000), blurRadius: 20, offset: Offset(0, 12)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _EquippedPanel extends StatelessWidget {
  const _EquippedPanel({
    required this.equippedItems,
    required this.onUnequip,
    required this.onDropToSlot,
  });

  final Map<String, InventoryItem?> equippedItems;
  final Future<void> Function(String slot) onUnequip;
  final Future<void> Function(_DragPayload payload, String slotName, InventoryItem? occupiedItem) onDropToSlot;

  @override
  Widget build(BuildContext context) {
    const slots = <(String, String, IconData)>[
      ('weapon', 'Silah', Icons.gps_fixed),
      ('head', 'Kafa', Icons.shield_moon),
      ('chest', 'Gogus', Icons.checkroom),
      ('legs', 'Bacak', Icons.accessibility_new),
      ('boots', 'Bot', Icons.hiking),
      ('gloves', 'Eldiven', Icons.back_hand),
      ('ring', 'Yuzuk', Icons.circle_outlined),
      ('necklace', 'Kolye', Icons.diamond_outlined),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slotMeta) {
        final item = equippedItems[slotMeta.$1];
        final bool hasItem = item != null;
        final Color rarityColor = hasItem
            ? getRarityColor(item.rarity)
            : Colors.white54;
        final Widget slotBody = Container(
          width: 165,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasItem
                  ? rarityColor.withValues(alpha: 0.85)
                  : Colors.white24,
              width: hasItem ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xCC101824), Color(0xCC0A101A)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    slotMeta.$3,
                    size: 13,
                    color: hasItem
                        ? rarityColor.withValues(alpha: 0.95)
                        : Colors.white60,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    slotMeta.$2.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: rarityColor.withValues(alpha: 0.45),
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ItemIconView(
                        iconValue: item.icon,
                        itemId: item.itemId,
                        itemType: item.itemType,
                        size: 30,
                        expand: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.itemId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'Bos',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              if (hasItem)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'ATK ${item.attack}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'DEF ${item.defense}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => onUnequip(slotMeta.$1),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            foregroundColor: const Color(0xFF66A3FF),
                          ),
                          child: const Text('Cikar'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

        final Widget draggable = item == null
            ? slotBody
            : LongPressDraggable<_DragPayload>(
                data: _DragPayload.fromEquipped(item, slotMeta.$1),
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(width: 165, child: slotBody),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: slotBody),
                child: slotBody,
              );

        return DragTarget<_DragPayload>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) => onDropToSlot(details.data, slotMeta.$1, item),
          builder: (context, candidateData, rejectedData) {
            final bool highlighted = candidateData.isNotEmpty;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: highlighted ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
              ),
              child: draggable,
            );
          },
        );
      }).toList(),
    );
  }
}

enum _DragSource {
  inventory,
  equipped,
}

class _DragPayload {
  const _DragPayload({
    required this.item,
    required this.source,
    this.equipSlot,
  });

  final InventoryItem item;
  final _DragSource source;
  final String? equipSlot;

  factory _DragPayload.fromInventory(InventoryItem item) {
    return _DragPayload(item: item, source: _DragSource.inventory);
  }

  factory _DragPayload.fromEquipped(InventoryItem item, String slot) {
    return _DragPayload(item: item, source: _DragSource.equipped, equipSlot: slot);
  }
}

class _InventorySlotCard extends StatelessWidget {
  const _InventorySlotCard({
    required this.item,
    required this.slotIndex,
    required this.isSelected,
    required this.onTap,
  });

  final InventoryItem? item;
  final int slotIndex;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // ── Boş slot ──────────────────────────────────────────────────────────────
    if (item == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x28101723),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
        ),
      );
    }

    final rarityColor = getRarityColor(item!.rarity);
    final Color borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : rarityColor.withValues(alpha: 0.65);
    final double borderWidth = isSelected ? 2.0 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          color: const Color(0xFF0C1220),
        ),
        child: Stack(
          children: <Widget>[
            // Item icon fills the slot body area.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 14),
                child: ItemIconView(
                  iconValue: item!.icon,
                  itemId: item!.itemId,
                  itemType: item!.itemType,
                  size: 56,
                  expand: true,
                ),
              ),
            ),

            // Name badge (top)
            Positioned(
              left: 4,
              right: 4,
              top: 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: rarityColor,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  if (item!.isFavorite)
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Icon(Icons.star_rounded, size: 10, color: Colors.amber),
                    ),
                ],
              ),
            ),

            // Quantity badge (bottom-left)
            if (item!.isStackable && item!.quantity > 1)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: rarityColor.withValues(alpha: 0.55), width: 0.8),
                  ),
                  child: Text(
                    '${item!.quantity}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: rarityColor,
                      height: 1,
                    ),
                  ),
                ),
              ),

            // Slot index (bottom-right)
            Positioned(
              right: 5,
              bottom: 4,
              child: Text(
                '#${slotIndex + 1}',
                style: const TextStyle(fontSize: 10, height: 1, color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedItemPanel extends StatelessWidget {
  const _SelectedItemPanel({
    required this.item,
    required this.onEquip,
    required this.onUse,
    required this.onSell,
    required this.onSplit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final InventoryItem? item;
  final Future<void> Function(InventoryItem item) onEquip;
  final Future<void> Function(InventoryItem item) onUse;
  final Future<void> Function(InventoryItem item) onSell;
  final Future<void> Function(InventoryItem item) onSplit;
  final Future<void> Function(InventoryItem item) onDelete;
  final ValueChanged<InventoryItem> onToggleFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Bir item secin.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final bool canEquip = item!.equipSlot != EquipSlot.none;
    final bool canUse = item!.itemType == ItemType.potion || item!.itemType == ItemType.consumable;
    final bool canSplit = item!.isStackable && item!.quantity > 1;
    final bool canSell = item!.isTradeable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ItemIconView(
                    iconValue: item!.icon,
                    itemId: item!.itemId,
                    itemType: item!.itemType,
                    size: 34,
                    expand: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item!.name, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item!.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatChip(label: 'ATK', value: item!.attack),
                _StatChip(label: 'DEF', value: item!.defense),
                _StatChip(label: 'POW', value: item!.power),
                _StatChip(label: 'LVL', value: item!.requiredLevel),
                _StatChip(label: 'SATIS', value: item!.vendorSellPrice),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: canUse ? () => onUse(item!) : null,
                  child: const Text('Kullan'),
                ),
                FilledButton(
                  onPressed: canEquip ? () => onEquip(item!) : null,
                  child: Text(canEquip ? 'Kusan (${item!.equipSlot.name})' : 'Kusanamaz'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onToggleFavorite(item!),
                  icon: Icon(isFavorite ? Icons.star : Icons.star_outline),
                  label: Text(isFavorite ? 'Favoride' : 'Favori'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: canSell ? () => onSell(item!) : null,
                  child: const Text('Sat'),
                ),
                OutlinedButton(
                  onPressed: canSplit ? () => onSplit(item!) : null,
                  child: const Text('Bol'),
                ),
                OutlinedButton(
                  onPressed: () => onDelete(item!),
                  child: const Text('Cop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityActionDialog extends StatefulWidget {
  const _QuantityActionDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.unitValue,
    required this.maxQuantity,
    this.showTotalValue = true,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final int unitValue;
  final int maxQuantity;
  final bool showTotalValue;

  @override
  State<_QuantityActionDialog> createState() => _QuantityActionDialogState();
}

class _QuantityActionDialogState extends State<_QuantityActionDialog> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.maxQuantity < 1 ? 1 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.unitValue * _quantity;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.subtitle),
          const SizedBox(height: 12),
          Text('Miktar: $_quantity / ${widget.maxQuantity}'),
          Slider(
            value: _quantity.toDouble(),
            min: 1,
            max: widget.maxQuantity.toDouble(),
            divisions: widget.maxQuantity > 1 ? widget.maxQuantity - 1 : null,
            onChanged: widget.maxQuantity <= 1
                ? null
                : (value) {
                    setState(() {
                      _quantity = value.round();
                    });
                  },
          ),
          if (widget.showTotalValue)
            Text('Toplam Deger: $total', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Iptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_quantity),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text('$label: $value'),
    );
  }
}
