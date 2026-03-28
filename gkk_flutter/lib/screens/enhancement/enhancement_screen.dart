import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const Map<int, int> _kUpgradeChances = <int, int>{
  0: 100, 1: 100, 2: 100, 3: 100, 4: 70,
  5: 60,  6: 50,  7: 35,  8: 20,  9: 10, 10: 3,
};

const Map<int, int> _kUpgradeCosts = <int, int>{
  0: 100000,    1: 200000,    2: 300000,    3: 500000,
  4: 1500000,   5: 3500000,   6: 7500000,   7: 15000000,
  8: 50000000,  9: 200000000, 10: 1000000000,
};

typedef RuneType = String;

const List<RuneType> _kRuneTypes = <RuneType>[
  'none', 'basic', 'advanced', 'superior', 'legendary', 'protection', 'blessed',
];

const Map<RuneType, String> _kRuneLabels = <RuneType, String>{
  'none':       'Rune Yok',
  'basic':      'Temel Rune',
  'advanced':   'Gelişmiş Rune',
  'superior':   'Üstün Rune',
  'legendary':  'Efsanevi Rune',
  'protection': 'Koruma Runu',
  'blessed':    'Kutsanmış Rune',
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _formatGold(int amount) {
  if (amount >= 1000000000) return '${(amount / 1000000000).toStringAsFixed(1)}G';
  if (amount >= 1000000)    return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000)       return '${(amount / 1000).toStringAsFixed(1)}K';
  return amount.toString();
}

String _scrollIdForRarity(Rarity rarity) {
  if (rarity == Rarity.common || rarity == Rarity.uncommon) return 'scroll_upgrade_low';
  if (rarity == Rarity.rare   || rarity == Rarity.epic)    return 'scroll_upgrade_middle';
  return 'scroll_upgrade_high';
}

String _scrollLabelForRarity(Rarity rarity) {
  if (rarity == Rarity.common || rarity == Rarity.uncommon) return 'Düşük Sınıf Parşömen';
  if (rarity == Rarity.rare   || rarity == Rarity.epic)    return 'Orta Sınıf Parşömen';
  return 'Yüksek Sınıf Parşömen';
}

bool _isEquipment(InventoryItem item) {
  const Set<ItemType> equipTypes = <ItemType>{
    ItemType.weapon, ItemType.armor,
  };
  return equipTypes.contains(item.itemType) ||
      item.equipSlot != EquipSlot.none;
}

bool _isEnhanceable(InventoryItem item) =>
    item.canEnhance && _isEquipment(item) && item.enhancementLevel < 10;

Color _rarityColor(Rarity rarity) => getRarityColor(rarity);

String _itemEmoji(InventoryItem item) {
  switch (item.itemType) {
    case ItemType.weapon:  return '⚔️';
    case ItemType.armor:   return '🛡️';
    case ItemType.scroll:  return '📜';
    case ItemType.rune:    return '🔮';
    case ItemType.potion:  return '🧪';
    default:               return '📦';
  }
}

String _riskLabel(int level) {
  if (level >= 6) return 'YOK OLMA RİSKİ';
  if (level >= 4) return 'Seviye düşer';
  return 'Risksiz';
}

Color _riskColor(int level) {
  if (level >= 6) return const Color(0xFFEF4444);
  if (level >= 4) return const Color(0xFFF97316);
  return const Color(0xFF22C55E);
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------
enum _ResultType { success, failure, destroyed }

class _EnhanceResult {
  const _EnhanceResult({required this.type, required this.newLevel, required this.message});
  final _ResultType type;
  final int newLevel;
  final String message;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class EnhancementScreen extends ConsumerStatefulWidget {
  const EnhancementScreen({super.key});

  @override
  ConsumerState<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends ConsumerState<EnhancementScreen> {
  InventoryItem? _selectedItem;
  InventoryItem? _selectedScroll;
  RuneType _selectedRune = 'none';
  bool _isLoading = false;
  _EnhanceResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(inventoryProvider.notifier).loadInventory();
    });
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  // ---------------------------------------------------------------------------
  // Item selection bottom sheet
  // ---------------------------------------------------------------------------
  void _openItemPicker() {
    final List<InventoryItem> items = ref
        .read(inventoryProvider)
        .items
        .where(_isEnhanceable)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A2035),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ItemPickerSheet(
        items: items,
        title: 'Güçlendirilecek Eşyayı Seç',
        onSelected: (InventoryItem item) {
          setState(() {
            _selectedItem = item;
            _selectedScroll = null;
            _lastResult = null;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scroll selection bottom sheet
  // ---------------------------------------------------------------------------
  void _openScrollPicker() {
    if (_selectedItem == null) return;

    final String requiredScrollId = _scrollIdForRarity(_selectedItem!.rarity);
    final List<InventoryItem> scrolls = ref
        .read(inventoryProvider)
        .items
        .where((InventoryItem i) =>
            i.itemType == ItemType.scroll && i.itemId == requiredScrollId)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A2035),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ItemPickerSheet(
        items: scrolls,
        title: 'Parşömen Seç',
        onSelected: (InventoryItem scroll) {
          setState(() => _selectedScroll = scroll);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Enhancement action
  // ---------------------------------------------------------------------------
  Future<void> _enhance() async {
    final InventoryItem? item = _selectedItem;
    if (item == null) return;

    final int cost = _kUpgradeCosts[item.enhancementLevel] ?? 0;
    final int gold = ref.read(playerProvider).profile?.gold ?? 0;

    if (gold < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yetersiz altın!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      final dynamic result = await SupabaseService.client.rpc(
        'enhance_item',
        params: <String, dynamic>{
          'p_inventory_item_id': item.rowId,
          'p_scroll_inventory_id': _selectedScroll?.rowId,
          'p_rune_type': _selectedRune,
        },
      );

      final Map<String, dynamic> data = (result as Map<String, dynamic>);
      final bool success = data['success'] as bool? ?? false;
      final bool destroyed = data['destroyed'] as bool? ?? false;
      final int newLevel = (data['new_level'] as num?)?.toInt() ?? item.enhancementLevel;
      final String message = data['message'] as String? ?? '';

      final _ResultType resultType = destroyed
          ? _ResultType.destroyed
          : success
              ? _ResultType.success
              : _ResultType.failure;

      setState(() {
        _lastResult = _EnhanceResult(type: resultType, newLevel: newLevel, message: message);
        if (destroyed) {
          _selectedItem = null;
          _selectedScroll = null;
        }
      });

      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(playerProvider.notifier).loadProfile();

      if (mounted) _showResultDialog(_lastResult!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showResultDialog(_EnhanceResult result) {
    final (String emoji, String title, Color color) = switch (result.type) {
      _ResultType.success   => ('🎉', 'BAŞARILI!', const Color(0xFF22C55E)),
      _ResultType.failure   => ('😔', 'BAŞARISIZ', const Color(0xFFF97316)),
      _ResultType.destroyed => ('💀', 'EŞYA YOK OLDU', const Color(0xFFEF4444)),
    };

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          result.message.isNotEmpty
              ? result.message
              : result.type == _ResultType.success
                  ? 'Eşyan +${result.newLevel} seviyesine yükseldi!'
                  : result.type == _ResultType.failure
                      ? 'Güçlendirme başarısız. Seviye düştü.'
                      : 'Eşyan yok oldu.',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam', style: TextStyle(color: Color(0xFF5296FF))),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final InventoryItem? item = _selectedItem;
    final int currentLevel = item?.enhancementLevel ?? 0;
    final int nextCost = _kUpgradeCosts[currentLevel] ?? 0;
    final int successChance = _kUpgradeChances[currentLevel] ?? 0;
    final int gold = ref.watch(playerProvider).profile?.gold ?? 0;

    return Scaffold(
      drawer: GameDrawer(onLogout: _logout),
      appBar: GameTopBar(title: 'Güçlendirme', onLogout: _logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.enhancement),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // -----------------------------------------------------------
                  // Item slot
                  // -----------------------------------------------------------
                  _SectionCard(
                    title: 'Güçlendirilecek Eşya',
                    child: _ItemSlotButton(
                      item: item,
                      onTap: _openItemPicker,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // -----------------------------------------------------------
                  // Enhancement level display
                  // -----------------------------------------------------------
                  if (item != null) ...<Widget>[
                    _SectionCard(
                      title: 'Mevcut Durum',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          _StatBadge(
                            label: 'Seviye',
                            value: '+$currentLevel',
                            color: const Color(0xFF5296FF),
                          ),
                          _StatBadge(
                            label: 'Başarı Şansı',
                            value: '$successChance%',
                            color: successChance >= 70
                                ? const Color(0xFF22C55E)
                                : successChance >= 40
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFFEF4444),
                          ),
                          _StatBadge(
                            label: 'Risk',
                            value: _riskLabel(currentLevel),
                            color: _riskColor(currentLevel),
                            small: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ---------------------------------------------------------
                    // Scroll selection
                    // ---------------------------------------------------------
                    _SectionCard(
                      title: 'Parşömen',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Gerekli: ${_scrollLabelForRarity(item.rarity)}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          _ItemSlotButton(
                            item: _selectedScroll,
                            placeholder: 'Parşömen Seç',
                            placeholderIcon: '📜',
                            onTap: _openScrollPicker,
                          ),
                          if (_selectedScroll != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _selectedScroll = null),
                                child: const Text('Kaldır',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ---------------------------------------------------------
                    // Rune selection
                    // ---------------------------------------------------------
                    _SectionCard(
                      title: 'Rune (Opsiyonel)',
                      child: DropdownButton<RuneType>(
                        value: _selectedRune,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A2035),
                        style: const TextStyle(color: Colors.white),
                        underline: Container(height: 1, color: Colors.white24),
                        onChanged: (RuneType? v) {
                          if (v != null) setState(() => _selectedRune = v);
                        },
                        items: _kRuneTypes
                            .map((RuneType r) => DropdownMenuItem<RuneType>(
                                  value: r,
                                  child: Text(_kRuneLabels[r] ?? r),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ---------------------------------------------------------
                    // Enhance button
                    // ---------------------------------------------------------
                    _SectionCard(
                      title: 'Güçlendirme Maliyeti',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text('Gerekli Altın:',
                                  style: TextStyle(color: Colors.white70)),
                              Text(
                                _formatGold(nextCost),
                                style: TextStyle(
                                  color: gold >= nextCost
                                      ? const Color(0xFFDDB200)
                                      : const Color(0xFFEF4444),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text('Mevcut Altın:',
                                  style: TextStyle(color: Colors.white54, fontSize: 12)),
                              Text(
                                _formatGold(gold),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed:
                                  (_isLoading || item.enhancementLevel >= 10)
                                      ? null
                                      : _enhance,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF5296FF),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text(
                                      item.enhancementLevel >= 10
                                          ? 'Maksimum Seviye'
                                          : 'Güçlendir',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // -----------------------------------------------------------
                  // Upgrade table
                  // -----------------------------------------------------------
                  _SectionCard(
                    title: 'Güçlendirme Tablosu',
                    child: _UpgradeTable(currentLevel: currentLevel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card
// ---------------------------------------------------------------------------
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        color: Colors.black26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item slot button
// ---------------------------------------------------------------------------
class _ItemSlotButton extends StatelessWidget {
  const _ItemSlotButton({
    required this.item,
    required this.onTap,
    this.placeholder = 'Öğe Seç',
    this.placeholderIcon = '⚔️',
  });

  final InventoryItem? item;
  final VoidCallback onTap;
  final String placeholder;
  final String placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: item != null
                ? _rarityColor(item!.rarity).withOpacity(0.6)
                : Colors.white24,
            width: 1.5,
          ),
          color: item != null
              ? _rarityColor(item!.rarity).withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
        ),
        child: item != null
            ? Row(
                children: <Widget>[
                  Text(_itemEmoji(item!), style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '+${item!.enhancementLevel} ${item!.name}',
                          style: TextStyle(
                            color: _rarityColor(item!.rarity),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          getRarityLabel(item!.rarity),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.swap_horiz,
                      color: Colors.white38, size: 18),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(placeholderIcon,
                      style: const TextStyle(
                          fontSize: 24, color: Colors.white38)),
                  const SizedBox(width: 10),
                  Text(placeholder,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 14)),
                  const SizedBox(width: 6),
                  const Icon(Icons.add_circle_outline,
                      color: Colors.white38, size: 18),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat badge
// ---------------------------------------------------------------------------
class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
    this.small = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: small ? 12 : 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Upgrade table
// ---------------------------------------------------------------------------
class _UpgradeTable extends StatelessWidget {
  const _UpgradeTable({required this.currentLevel});

  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.5),
      },
      children: <TableRow>[
        // Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          children: <Widget>[
            _th('Seviye'),
            _th('Maliyet'),
            _th('Şans'),
            _th('Risk'),
          ],
        ),
        // Rows 0-10
        for (int lvl = 0; lvl <= 10; lvl++)
          TableRow(
            decoration: BoxDecoration(
              color: lvl == currentLevel
                  ? const Color(0xFF5296FF).withOpacity(0.12)
                  : Colors.transparent,
            ),
            children: <Widget>[
              _td('+$lvl',
                  bold: lvl == currentLevel,
                  color: lvl == currentLevel
                      ? const Color(0xFF5296FF)
                      : Colors.white70),
              _td(_formatGold(_kUpgradeCosts[lvl] ?? 0),
                  color: const Color(0xFFDDB200)),
              _td('${_kUpgradeChances[lvl] ?? 0}%'),
              _td(
                _riskLabel(lvl),
                color: _riskColor(lvl),
                small: true,
              ),
            ],
          ),
      ],
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  Widget _td(String text,
      {Color color = Colors.white70, bool bold = false, bool small = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: small ? 10 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Item picker bottom sheet
// ---------------------------------------------------------------------------
class _ItemPickerSheet extends StatelessWidget {
  const _ItemPickerSheet({
    required this.items,
    required this.title,
    required this.onSelected,
  });

  final List<InventoryItem> items;
  final String title;
  final void Function(InventoryItem) onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(color: Colors.white12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Uygun eşya bulunamadı.',
                  style: TextStyle(color: Colors.white38)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (BuildContext ctx, int i) {
                  final InventoryItem item = items[i];
                  return ListTile(
                    leading: Text(_itemEmoji(item),
                        style: const TextStyle(fontSize: 22)),
                    title: Text(
                      '+${item.enhancementLevel} ${item.name}',
                      style: TextStyle(
                        color: _rarityColor(item.rarity),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      getRarityLabel(item.rarity),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    trailing: item.quantity > 1
                        ? Text(
                            'x${item.quantity}',
                            style: const TextStyle(color: Colors.white54),
                          )
                        : null,
                    onTap: () => onSelected(item),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
