import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ---------------------------------------------------------------------------
// Data helpers
// ---------------------------------------------------------------------------

class _GemPackage {
  const _GemPackage({required this.gems, required this.price, this.isBestValue = false});
  final int gems;
  final String price;
  final bool isBestValue;
}

class _GoldPackage {
  const _GoldPackage({required this.gold, required this.gemCost});
  final int gold;
  final int gemCost;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _battlePassItems = [];
  List<Map<String, dynamic>> _shopItems = [];
  bool _offersLoading = true;
  bool _purchaseLoading = false;
  String _itemSearchQuery = '';
  Map<String, dynamic>? _quantityDialogItem;
  int _quantityInput = 1;
  String? _buyingId;

  static const List<_GemPackage> _gemPackages = <_GemPackage>[
    _GemPackage(gems: 100, price: r'$0.99'),
    _GemPackage(gems: 500, price: r'$4.99'),
    _GemPackage(gems: 1200, price: r'$9.99', isBestValue: true),
    _GemPackage(gems: 2600, price: r'$19.99'),
  ];

  static const List<_GoldPackage> _goldPackages = <_GoldPackage>[
    _GoldPackage(gold: 1000, gemCost: 10),
    _GoldPackage(gold: 5000, gemCost: 45),
    _GoldPackage(gold: 10000, gemCost: 85),
    _GoldPackage(gold: 50000, gemCost: 400),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadOffers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    setState(() => _offersLoading = true);
    try {
      final offersRes = await SupabaseService.client
          .from('shop_offers')
          .select()
          .eq('is_active', true);
      final bpRes =
          await SupabaseService.client.from('battle_pass_items').select();
      final itemsRes = await SupabaseService.client
          .from('shop_items')
          .select()
          .eq('is_active', true);
      if (mounted) {
        setState(() {
          _offers = List<Map<String, dynamic>>.from(offersRes);
          _battlePassItems = List<Map<String, dynamic>>.from(bpRes);
          _shopItems = List<Map<String, dynamic>>.from(itemsRes);
          _offersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _offersLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mağaza yüklenemedi: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

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

  Future<void> _buyShopItem(Map<String, dynamic> item, int qty) async {
    final id = item['id'] as String? ?? '';
    setState(() => _buyingId = id);
    final gemCost = ((item['price'] as num?)?.toInt() ?? 0) * qty;
    final goldCost = ((item['price'] as num?)?.toInt() ?? 0) * qty;
    final profile = ref.read(playerProvider).profile;
    final currency = item['currency'] as String? ?? 'gold';
    final wallet = currency == 'gems' ? (profile?.gems ?? 0) : (profile?.gold ?? 0);
    if (wallet < (currency == 'gems' ? gemCost : goldCost)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yetersiz ${currency == 'gems' ? 'gem' : 'altın'}!')));
      setState(() => _buyingId = null);
      return;
    }
    try {
      await SupabaseService.client.rpc('buy_shop_item', params: {'p_item_id': id, 'p_quantity': qty});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item['name']} satın alındı!'), backgroundColor: Colors.green));
        ref.read(playerProvider.notifier).loadProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  void _handleBuyClick(Map<String, dynamic> item) {
    final isStackable = (item['is_stackable'] as bool?) ?? false;
    if (isStackable) {
      setState(() { _quantityDialogItem = item; _quantityInput = 1; });
    } else {
      _confirmAndBuyItem(item);
    }
  }

  Future<void> _confirmAndBuyItem(Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? 'Eşya';
    final currency = item['currency']?.toString() ?? 'gold';
    final price = item['price'] ?? 0;
    final isGem = currency == 'gems';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        title: Text('🛒 $name', style: const TextStyle(color: Color(0xFFFBBF24))),
        content: Text(
          '$name satın almak istediğinize emin misiniz?\nFiyat: $price ${isGem ? '💎' : '🪙'}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black),
            child: const Text('✓ Satın Al', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _buyShopItem(item, 1);
  }

  Future<void> _buyGoldPackage(_GoldPackage pkg) async {
    final gems = ref.read(playerProvider).profile?.gems ?? 0;
    if (gems < pkg.gemCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Yetersiz elmas! ${pkg.gemCost} 💎 gerekiyor, $gems 💎 var.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _purchaseLoading = true);
    try {
      await SupabaseService.client.rpc(
        'exchange_gems_for_gold',
        params: {'p_gem_cost': pkg.gemCost, 'p_gold_amount': pkg.gold},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_fmtGold(pkg.gold)} altın satın alındı!'),
            backgroundColor: Colors.green,
          ),
        );
        await ref.read(playerProvider.notifier).loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _purchaseLoading = false);
    }
  }

  static String _fmtGold(int gold) {
    if (gold >= 1000) return '${(gold / 1000).toStringAsFixed(0)}K';
    return '$gold';
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final gems = profile?.gems ?? 0;
    final gold = profile?.gold ?? 0;

    return Stack(
      children: [
        Scaffold(
      drawer: GameDrawer(onLogout: _doLogout),
      appBar: GameTopBar(title: 'Mağaza', onLogout: _doLogout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.shop),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.paid_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Text(_fmtGold(gold),
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 20),
                    const Icon(Icons.diamond_rounded,
                        color: Colors.purpleAccent, size: 16),
                    const SizedBox(width: 6),
                    Text('$gems',
                        style: const TextStyle(
                            color: Colors.purpleAccent, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              indicatorColor: Colors.purpleAccent,
              tabs: const <Tab>[
                Tab(text: '💎 Elmas Paketleri'),
                Tab(text: '💰 Altın Paketi'),
                Tab(text: '🎁 Teklifler'),
                Tab(text: '⚔️ Muharebe Geçidi'),
                Tab(text: '🛍️ Eşya'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _GemPackagesTab(packages: _gemPackages),
                  _GoldPackagesTab(
                    packages: _goldPackages,
                    loading: _purchaseLoading,
                    onBuy: _buyGoldPackage,
                  ),
                  _OffersTab(offers: _offers, loading: _offersLoading),
                  _BattlePassTab(items: _battlePassItems, loading: _offersLoading),
                  _ItemsTab(
                    items: _shopItems,
                    loading: _offersLoading,
                    searchQuery: _itemSearchQuery,
                    buyingId: _buyingId,
                    onSearchChanged: (q) => setState(() => _itemSearchQuery = q),
                    onBuyTap: _handleBuyClick,
                    rarityColor: _rarityColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
        ),
        // Quantity dialog overlay
        if (_quantityDialogItem != null)
          GestureDetector(
            onTap: () => setState(() => _quantityDialogItem = null),
            child: Container(
              color: Colors.black87,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2030),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFBBF24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_quantityDialogItem!['name']?.toString() ?? 'Eşya', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24))),
                        const SizedBox(height: 4),
                        Text(
                          'Birim: ${_quantityDialogItem!['currency'] == 'gems' ? '💎' : '🪙'} ${_quantityDialogItem!['price'] ?? 0}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () => setState(() => _quantityInput = (_quantityInput - 1).clamp(1, 99)),
                              icon: const Icon(Icons.remove, color: Color(0xFFFBBF24)),
                            ),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: TextEditingController(text: '$_quantityInput')..selection = TextSelection.collapsed(offset: '$_quantityInput'.length),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFBBF24)),
                                decoration: const InputDecoration(border: InputBorder.none),
                                onChanged: (v) => setState(() => _quantityInput = (int.tryParse(v) ?? 1).clamp(1, 99)),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _quantityInput = (_quantityInput + 1).clamp(1, 99)),
                              icon: const Icon(Icons.add, color: Color(0xFFFBBF24)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final item = _quantityDialogItem!;
                                  final qty = _quantityInput;
                                  setState(() => _quantityDialogItem = null);
                                  _buyShopItem(item, qty);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black),
                                child: const Text('✓ Satın Al', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _quantityDialogItem = null),
                                child: const Text('İptal'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab content widgets
// ---------------------------------------------------------------------------

class _GemPackagesTab extends StatelessWidget {
  const _GemPackagesTab({required this.packages});
  final List<_GemPackage> packages;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: packages.length,
      itemBuilder: (context, index) {
        final pkg = packages[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: pkg.isBestValue
                  ? const <Color>[Color(0xFF4A00E0), Color(0xFF8E2DE2)]
                  : const <Color>[Color(0xFF1A1D2E), Color(0xFF252840)],
            ),
            border: Border.all(
              color: pkg.isBestValue ? Colors.purpleAccent : Colors.white12,
              width: pkg.isBestValue ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (pkg.isBestValue) ...<Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.amber,
                  ),
                  child: const Text('En İyi Değer',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.black)),
                ),
                const SizedBox(height: 6),
              ],
              const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 44),
              const SizedBox(height: 8),
              Text('${pkg.gems} 💎',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Text('Elmas',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1A2030),
                      title: const Text('💎 Elmas Paketi', style: TextStyle(color: Colors.purpleAccent)),
                      content: const Text(
                        'Bu özellik henüz kullanılamıyor. Yakında aktif olacak.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tamam', style: TextStyle(color: Colors.purpleAccent)),
                        ),
                      ],
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  textStyle:
                      const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: Text(pkg.price),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GoldPackagesTab extends StatelessWidget {
  const _GoldPackagesTab({
    required this.packages,
    required this.loading,
    required this.onBuy,
  });

  final List<_GoldPackage> packages;
  final bool loading;
  final void Function(_GoldPackage) onBuy;

  static String _fmtGold(int gold) {
    if (gold >= 1000) return '${(gold / 1000).toStringAsFixed(0)}K';
    return '$gold';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pkg = packages[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.05),
            border:
                Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.paid_rounded, color: Colors.amber, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${_fmtGold(pkg.gold)} Altın',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber)),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.diamond_rounded,
                            size: 12, color: Colors.purpleAccent),
                        const SizedBox(width: 4),
                        Text('${pkg.gemCost} Elmas',
                            style: const TextStyle(
                                color: Colors.purpleAccent, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: loading ? null : () => onBuy(pkg),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8F00),
                  foregroundColor: Colors.black,
                ),
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('Satın Al',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OffersTab extends StatelessWidget {
  const _OffersTab({required this.offers, required this.loading});
  final List<Map<String, dynamic>> offers;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (offers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.local_offer_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text('Şu anda aktif teklif yok.',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(offer['name']?.toString() ?? 'Teklif',
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (offer['description'] != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(offer['description'].toString(),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BattlePassTab extends StatelessWidget {
  const _BattlePassTab({required this.items, required this.loading});
  final List<Map<String, dynamic>> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.military_tech_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text('Muharebe Geçidi yakında aktif olacak.',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(item['name']?.toString() ?? 'İtem',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        );
      },
    );
  }
}

// ── Items tab ──────────────────────────────────────────────────────────────

class _ItemsTab extends StatelessWidget {
  const _ItemsTab({
    required this.items,
    required this.loading,
    required this.searchQuery,
    required this.buyingId,
    required this.onSearchChanged,
    required this.onBuyTap,
    required this.rarityColor,
  });

  final List<Map<String, dynamic>> items;
  final bool loading;
  final String searchQuery;
  final String? buyingId;
  final ValueChanged<String> onSearchChanged;
  final void Function(Map<String, dynamic>) onBuyTap;
  final Color Function(String?) rarityColor;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final q = searchQuery.trim().toLowerCase();
    final filtered = q.isEmpty ? items : items.where((it) => (it['name']?.toString() ?? '').toLowerCase().contains(q)).toList();

    return Column(
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1220),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(children: [
            const Icon(Icons.search, color: Colors.white38, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Eşya ara...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
            if (searchQuery.isNotEmpty)
              GestureDetector(onTap: () => onSearchChanged(''), child: const Icon(Icons.close, color: Colors.white38, size: 14)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${filtered.length} eşya${q.isNotEmpty ? ' "$searchQuery" için bulundu' : ''}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.white12),
                    const SizedBox(height: 10),
                    Text(q.isNotEmpty ? '"$searchQuery" için eşya bulunamadı' : 'Mağazada henüz eşya yok', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  ]),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final id = item['id']?.toString() ?? '';
                    final isBuying = buyingId == id;
                    final rarity = item['rarity']?.toString();
                    final rc = rarityColor(rarity);
                    final currency = item['currency']?.toString() ?? 'gold';
                    final price = item['price'] ?? 0;
                    final isGem = currency == 'gems';

                    return GestureDetector(
                      onTap: isBuying ? null : () => onBuyTap(item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121A2A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: rc.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Rarity dot
                            Align(alignment: Alignment.topRight, child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: rc)),
                            )),
                            // Item icon
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: rc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: rc.withValues(alpha: 0.3))),
                              alignment: Alignment.center,
                              child: Text(item['icon']?.toString() ?? '🎁', style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(item['name']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: (isGem ? Colors.blue : Colors.amber).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: (isGem ? Colors.blue : Colors.amber).withValues(alpha: 0.25)),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(isGem ? '💎' : '🪙', style: const TextStyle(fontSize: 9)),
                                const SizedBox(width: 2),
                                Text(isBuying ? '...' : '$price', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isGem ? const Color(0xFF7DD3FC) : const Color(0xFFFDE68A))),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
