import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../components/layout/game_chrome.dart';
import '../../models/inventory_model.dart';
import '../../models/market_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/market_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../models/item_model.dart';

enum _MarketTab { browse, sell, orders }

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  _MarketTab _tab = _MarketTab.browse;
  String _search = '';
  String _categoryFilter = '';
  String _rarityFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadInventory(silent: false);
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(marketProvider.notifier).loadTickers();
      ref.read(marketProvider.notifier).loadMyOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final playerState = ref.watch(playerProvider);
    final marketState = ref.watch(marketProvider);
    final int gold = playerState.profile?.gold ?? 0;

    final List<InventoryItem> tradeableItems = inventoryState.items
        .where((item) => item.isTradeable && !item.isEquipped)
        .toList();

    final List<MarketTicker> filteredTickers = marketState.tickers.where((ticker) {
      final String q = _search.trim().toLowerCase();
      if (q.isNotEmpty) {
        final bool inName = ticker.itemName.toLowerCase().contains(q);
        final bool inType = ticker.itemType.toLowerCase().contains(q);
        if (!inName && !inType) return false;
      }

      if (_categoryFilter.isNotEmpty && ticker.itemType != _categoryFilter) {
        return false;
      }

      if (_rarityFilter.isNotEmpty && ticker.rarity != _rarityFilter) {
        return false;
      }

      return true;
    }).toList();

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Pazar',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.market),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF090D14), Color(0xFF101722), Color(0xFF090D14)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            const Text(
              '🏪 Pazar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _tabButton(_MarketTab.browse, '📋 Gözat'),
                const SizedBox(width: 6),
                _tabButton(_MarketTab.sell, '💰 Sat'),
                const SizedBox(width: 6),
                _tabButton(_MarketTab.orders, '📦 Siparişlerim'),
              ],
            ),
            const SizedBox(height: 10),
            if (_tab == _MarketTab.browse) ...<Widget>[
              TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  hintText: 'Eşya ara...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _categoryFilter,
                      items: _categoryFilters
                          .map((filter) => DropdownMenuItem<String>(
                                value: filter.key,
                                child: Text(filter.label),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _categoryFilter = value ?? ''),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _rarityFilter,
                      items: _rarityFilters
                          .map((filter) => DropdownMenuItem<String>(
                                value: filter.key,
                                child: Text(filter.label),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _rarityFilter = value ?? ''),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (marketState.status == MarketStatus.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Yükleniyor...')),
                )
              else if (filteredTickers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Sonuç bulunamadı')),
                )
              else
                ...filteredTickers.map((ticker) => Card(
                      child: ListTile(
                        onTap: ticker.cheapestOrderId != null
                            ? () => _openBuyDialog(context, ticker: ticker, gold: gold)
                            : null,
                        title: Text(
                          ticker.itemName,
                          style: TextStyle(
                            color: _rarityColorFromName(ticker.rarity),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text('${_rarityLabelFromName(ticker.rarity)} • ${ticker.volume} adet'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              '🪙 ${_formatGold(ticker.lowestPrice)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${ticker.priceChange >= 0 ? '▲' : '▼'} ${ticker.priceChange.abs()}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: ticker.priceChange >= 0
                                    ? Colors.greenAccent.shade100
                                    : Colors.redAccent.shade100,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
            if (_tab == _MarketTab.sell) ...<Widget>[
              if (tradeableItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Satılabilir eşya yok')),
                )
              else
                ...tradeableItems.map((item) {
                  final bool locked = item.isMarketTradeable == false || item.isHanOnly == true;
                  return Card(
                    child: ListTile(
                      title: Text(
                        item.name,
                        style: TextStyle(
                          color: getRarityColor(item.rarity),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.quantity > 1 ? '${item.quantity} adet' : _rarityLabelWeb(item.rarity)),
                          if (locked)
                            const Text(
                              'Bu eşya pazarda satılamaz (Han-only)',
                              style: TextStyle(fontSize: 11, color: Colors.amber),
                            ),
                        ],
                      ),
                      trailing: FilledButton(
                        onPressed: locked
                            ? null
                            : () => _openSellModal(
                                  context,
                                  rowId: item.rowId,
                                  itemName: item.name,
                                  initialPrice: item.basePrice > 0 ? item.basePrice : 100,
                                  maxQuantity: item.quantity,
                                ),
                        child: const Text('Sat'),
                      ),
                    ),
                  );
                }),
            ],
            if (_tab == _MarketTab.orders)
              if (marketState.myOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Aktif sipariş yok')),
                )
              else
                ...marketState.myOrders.map(
                  (order) => Card(
                    child: ListTile(
                      title: Text(order.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('🪙 ${_formatGold(order.price)} • Adet: ${order.quantity}'),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          final bool ok = await ref.read(marketProvider.notifier).cancelOrder(orderId: order.orderId);
                          _toast(ok ? 'Sipariş iptal edildi' : (ref.read(marketProvider).errorMessage ?? 'İptal başarısız'));
                        },
                        child: const Text('İptal'),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Altın: ${_formatGold(gold)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Expanded _tabButton(_MarketTab tab, String label) {
    final bool active = _tab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? const Color(0xFF4F77F7) : const Color(0xFF1A2130),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Future<void> _openBuyDialog(
    BuildContext context, {
    required MarketTicker ticker,
    required int gold,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final bool canAfford = gold >= ticker.lowestPrice;
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1722),
          title: Text(
            ticker.itemName,
            style: TextStyle(
              color: _rarityColorFromName(ticker.rarity),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Fiyat: 🪙 ${_formatGold(ticker.lowestPrice)}'),
              const SizedBox(height: 4),
              Text('Altınınız: 🪙 ${_formatGold(gold)}'),
              if (!canAfford) ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  'Yeterli altınınız yok!',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: canAfford ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text('Satın Al'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final bool ok = await ref.read(marketProvider.notifier).purchaseListing(
          orderId: ticker.cheapestOrderId!,
          itemId: ticker.itemId,
          quantity: 1,
        );

    if (!mounted) return;

    if (ok) {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      _toast('Satın alma başarılı!');
    } else {
      _toast(ref.read(marketProvider).errorMessage ?? 'Satın alma başarısız');
    }
  }

  Future<void> _openSellModal(
    BuildContext context, {
    required String rowId,
    required String itemName,
    required int initialPrice,
    required int maxQuantity,
  }) async {
    final TextEditingController priceController = TextEditingController(text: '$initialPrice');
    final TextEditingController quantityController = TextEditingController(text: '1');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1722),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$itemName — Satış Emri',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text('Fiyat (Altın)', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              const Text('Adet', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final int price = int.tryParse(priceController.text) ?? 0;
                        final int quantity = int.tryParse(quantityController.text) ?? 0;
                        if (price <= 0) {
                          _toast('Geçerli bir fiyat girin');
                          return;
                        }
                        if (quantity <= 0 || quantity > maxQuantity) {
                          _toast('Geçerli bir adet girin');
                          return;
                        }
                        final bool ok = await ref.read(marketProvider.notifier).createOrder(
                              itemRowId: rowId,
                              quantity: quantity,
                              price: price,
                            );
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        _toast(ok ? 'Satış emri oluşturuldu!' : (ref.read(marketProvider).errorMessage ?? 'Satış emri oluşturulamadı'));
                      },
                      child: const Text('Satış Emri Ver'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _FilterOption {
  const _FilterOption(this.key, this.label);

  final String key;
  final String label;
}

const List<_FilterOption> _categoryFilters = <_FilterOption>[
  _FilterOption('', 'Tümü'),
  _FilterOption('weapon', '⚔️ Silah'),
  _FilterOption('armor', '🛡️ Zırh'),
  _FilterOption('consumable', '🧪 İksir'),
  _FilterOption('material', '🪨 Malzeme'),
  _FilterOption('accessory', '💍 Aksesuar'),
];

const List<_FilterOption> _rarityFilters = <_FilterOption>[
  _FilterOption('', 'Tüm Nadirlik'),
  _FilterOption('common', 'Yaygın'),
  _FilterOption('uncommon', 'Olağandışı'),
  _FilterOption('rare', 'Nadir'),
  _FilterOption('epic', 'Destansı'),
  _FilterOption('legendary', 'Efsanevi'),
];

String _rarityLabelWeb(Rarity rarity) {
  switch (rarity) {
    case Rarity.common:
      return 'Yaygın';
    case Rarity.uncommon:
      return 'Olağandışı';
    case Rarity.rare:
      return 'Nadir';
    case Rarity.epic:
      return 'Destansı';
    case Rarity.legendary:
      return 'Efsanevi';
    case Rarity.mythic:
      return 'Mitik';
  }
}

Color _rarityColorFromName(String rarityName) {
  switch (rarityName) {
    case 'common':
      return getRarityColor(Rarity.common);
    case 'uncommon':
      return getRarityColor(Rarity.uncommon);
    case 'rare':
      return getRarityColor(Rarity.rare);
    case 'epic':
      return getRarityColor(Rarity.epic);
    case 'legendary':
      return getRarityColor(Rarity.legendary);
    case 'mythic':
      return getRarityColor(Rarity.mythic);
    default:
      return Colors.white;
  }
}

String _rarityLabelFromName(String rarityName) {
  switch (rarityName) {
    case 'common':
      return 'Yaygın';
    case 'uncommon':
      return 'Olağandışı';
    case 'rare':
      return 'Nadir';
    case 'epic':
      return 'Destansı';
    case 'legendary':
      return 'Efsanevi';
    case 'mythic':
      return 'Mitik';
    default:
      return 'Yaygın';
  }
}

String _formatGold(int value) {
  return NumberFormat.decimalPattern('tr_TR').format(value);
}
