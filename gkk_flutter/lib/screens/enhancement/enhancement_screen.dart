import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ============================================================================
// DESIGN SYSTEM
// ============================================================================
class _EnhancementDesignSystem {
  // Colors - same as chat system for consistency
  static const Color colorSuccess = Color(0xFF10B981);
  static const Color colorWarning = Color(0xFFFB923C);
  static const Color colorError = Color(0xFFF87171);
  static const Color colorGold = Color(0xFFDDB200);

  // Backgrounds
  static const Color colorBgSecondary = Color(0xFF090D15);
  static const LinearGradient gradientBgPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xF0141B26), Color(0xF0090D15)],
  );

  // Text
  static const Color colorTextSecondary = Color(0xFFE2E8F0);

  // Spacing
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;

  // Radius
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  // Shadows
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Map<int, int> _kUpgradeChances = <int, int>{
  0: 100,
  1: 100,
  2: 100,
  3: 100,
  4: 70,
  5: 60,
  6: 50,
  7: 35,
  8: 20,
  9: 10,
  10: 3,
};

const Map<int, int> _kUpgradeCosts = <int, int>{
  0: 100000,
  1: 200000,
  2: 300000,
  3: 500000,
  4: 1500000,
  5: 3500000,
  6: 7500000,
  7: 15000000,
  8: 50000000,
  9: 200000000,
  10: 1000000000,
};

typedef RuneType = String;

const List<RuneType> _kRuneTypes = <RuneType>[
  'none',
  'basic',
  'advanced',
  'superior',
  'legendary',
  'protection',
  'blessed',
];

const Map<RuneType, String> _kRuneLabels = <RuneType, String>{
  'none': 'Rune Yok',
  'basic': 'Temel Rune',
  'advanced': 'Gelişmiş Rune',
  'superior': 'Üstün Rune',
  'legendary': 'Efsanevi Rune',
  'protection': 'Koruma Runu',
  'blessed': 'Kutsanmış Rune',
};

enum _EnhanceResultType { success, failure, destroyed }

class _EnhanceResult {
  const _EnhanceResult({
    required this.type,
    required this.newLevel,
    required this.message,
  });

  final _EnhanceResultType type;
  final int newLevel;
  final String message;
}

// ============================================================================
// HELPERS
// ============================================================================
String _formatGold(int amount) {
  if (amount >= 1000000000) {
    return '${(amount / 1000000000).toStringAsFixed(1)}G';
  }
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount.toString();
}

String _scrollIdForRarity(Rarity rarity) {
  if (rarity == Rarity.common || rarity == Rarity.uncommon) {
    return 'scroll_upgrade_low';
  }
  if (rarity == Rarity.rare || rarity == Rarity.epic) {
    return 'scroll_upgrade_middle';
  }
  return 'scroll_upgrade_high';
}

String _scrollLabelForRarity(Rarity rarity) {
  if (rarity == Rarity.common || rarity == Rarity.uncommon) {
    return 'Düşük Sınıf Parşömen';
  }
  if (rarity == Rarity.rare || rarity == Rarity.epic) {
    return 'Orta Sınıf Parşömen';
  }
  return 'Yüksek Sınıf Parşömen';
}

bool _isEquipment(InventoryItem item) {
  const Set<ItemType> equipTypes = <ItemType>{ItemType.weapon, ItemType.armor};
  return equipTypes.contains(item.itemType) || item.equipSlot != EquipSlot.none;
}

bool _isEnhanceable(InventoryItem item) =>
    _isEquipment(item) && item.enhancementLevel < 10;

Color _rarityColor(Rarity rarity) => getRarityColor(rarity);

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

// ============================================================================
// MAIN SCREEN
// ============================================================================
class EnhancementScreen extends ConsumerStatefulWidget {
  const EnhancementScreen({super.key});

  @override
  ConsumerState<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends ConsumerState<EnhancementScreen> {
  static const int _maxScrollSlots = 9;

  InventoryItem? _selectedItem;
  final List<InventoryItem?> _selectedScrollSlots = List<InventoryItem?>.filled(
    _maxScrollSlots,
    null,
  );
  RuneType _selectedRune = 'none';
  bool _isEnhancing = false;
  _EnhanceResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(inventoryProvider.notifier).loadInventory();
      await ref.read(playerProvider.notifier).loadProfile();
    });
  }

  Future<void> _enhance() async {
    final InventoryItem? item = _selectedItem;
    if (item == null) return;
    final String? authId = SupabaseService.client.auth.currentUser?.id;
    if (authId == null || authId.isEmpty) {
      _showSnack('Oturum bulunamadi!');
      return;
    }

    final int cost = _kUpgradeCosts[item.enhancementLevel] ?? 0;
    final int gold = ref.read(playerProvider).profile?.gold ?? 0;

    if (gold < cost) {
      _showSnack('Yetersiz altın!');
      return;
    }

    final InventoryItem? compatibleScroll = _findCompatibleScroll();
    if (compatibleScroll == null) {
      _showSnack('Uyumlu parşömen gerekli!');
      return;
    }

    setState(() {
      _isEnhancing = true;
      _lastResult = null;
    });

    try {
      final dynamic result = await SupabaseService.client.rpc(
        'enhance_item',
        params: <String, dynamic>{
          'p_player_id': authId,
          'p_row_id': item.rowId,
          'p_rune_type': _selectedRune,
        },
      );

      final Map<String, dynamic> data = (result as Map<String, dynamic>);
      final bool success = data['success'] as bool? ?? false;
      final bool destroyed = data['destroyed'] as bool? ?? false;
      final int newLevel =
          (data['new_level'] as num?)?.toInt() ?? item.enhancementLevel;
      final String message = data['message'] as String? ?? '';

      final _EnhanceResultType resultType = destroyed
          ? _EnhanceResultType.destroyed
          : success
          ? _EnhanceResultType.success
          : _EnhanceResultType.failure;

      setState(() {
        _lastResult = _EnhanceResult(
          type: resultType,
          newLevel: newLevel,
          message: message,
        );
        if (destroyed) {
          _selectedItem = null;
          _selectedScrollSlots.fillRange(0, _maxScrollSlots, null);
        }
      });

      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(playerProvider.notifier).loadProfile();

      if (mounted) _showResultDialog(_lastResult!);

      // Clear after 3 seconds
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _lastResult = null;
          _selectedItem = null;
          _selectedScrollSlots.fillRange(0, _maxScrollSlots, null);
          _selectedRune = 'none';
        });
      }
    } catch (e) {
      if (mounted) _showSnack('Hata: $e');
    } finally {
      if (mounted) setState(() => _isEnhancing = false);
    }
  }

  InventoryItem? _findCompatibleScroll() {
    if (_selectedItem == null) return null;
    final String requiredId = _scrollIdForRarity(_selectedItem!.rarity);
    for (final InventoryItem? scroll in _selectedScrollSlots) {
      if (scroll != null && scroll.itemId == requiredId) {
        return scroll;
      }
    }
    return null;
  }

  bool _isScrollItem(InventoryItem item) {
    return item.itemType == ItemType.scroll || item.itemId.contains('scroll');
  }

  bool _isRuneItem(InventoryItem item) {
    return item.itemType == ItemType.rune || item.itemId.startsWith('rune_');
  }

  void _showResultDialog(_EnhanceResult result) {
    final (String emoji, String title, Color color) = switch (result.type) {
      _EnhanceResultType.success => (
        '✨',
        'BAŞARILI!',
        _EnhancementDesignSystem.colorSuccess,
      ),
      _EnhanceResultType.failure => (
        '💨',
        'BAŞARISIZ',
        _EnhancementDesignSystem.colorWarning,
      ),
      _EnhanceResultType.destroyed => (
        '💥',
        'YANARAK YOK OLDU',
        _EnhancementDesignSystem.colorError,
      ),
    };

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _EnhancementDesignSystem.colorBgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: _EnhancementDesignSystem.spaceMd),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          result.message.isNotEmpty
              ? result.message
              : result.type == _EnhanceResultType.success
              ? 'Eşyan +${result.newLevel} seviyesine yükseldi!'
              : result.type == _EnhanceResultType.failure
              ? 'Güçlendirme başarısız. Seviye düştü.'
              : 'Eşyan yok oldu.',
          style: const TextStyle(
            color: _EnhancementDesignSystem.colorTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tamam',
              style: TextStyle(color: Color(0xFF5296FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final int currentLevel = _selectedItem?.enhancementLevel ?? 0;
    final int nextCost = _kUpgradeCosts[currentLevel] ?? 0;
    final int successChance = _kUpgradeChances[currentLevel] ?? 0;
    final int gold = ref.watch(playerProvider).profile?.gold ?? 0;
    final bool canEnhance =
        _selectedItem != null &&
        _findCompatibleScroll() != null &&
        gold >= nextCost &&
        !_isEnhancing;
    final String requiredScrollLabel = _selectedItem != null
        ? _scrollLabelForRarity(_selectedItem!.rarity)
        : '';

    final previewLevel = currentLevel + 1;

    return PopScope(
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        drawer: GameDrawer(
          onLogout: () async {
            await ref.read(authProvider.notifier).logout();
            ref.read(playerProvider.notifier).clear();
          },
        ),
        appBar: GameTopBar(
          title: '🔥 Güçlendirme',
          onLogout: () async {
            await ref.read(authProvider.notifier).logout();
            ref.read(playerProvider.notifier).clear();
          },
        ),
        bottomNavigationBar: const GameBottomBar(
          currentRoute: AppRoutes.enhancement,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF10131D),
                Color(0xFF171E2C),
                Color(0xFF10131D),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ─── THREE SLOT PANEL ─────────────────────────────────────
                _buildThreeSlotPanel(currentLevel, previewLevel),

                const SizedBox(height: _EnhancementDesignSystem.spaceLg),

                // ─── INFO PANEL ───────────────────────────────────────────
                _buildInfoPanel(
                  requiredScrollLabel,
                  successChance,
                  nextCost,
                  gold,
                  currentLevel,
                ),

                const SizedBox(height: _EnhancementDesignSystem.spaceLg),

                // ─── ACTION BUTTONS ───────────────────────────────────────
                Row(
                  children: <Widget>[
                    Expanded(
                      child: GestureDetector(
                        onTap: _isEnhancing
                            ? null
                            : () {
                                setState(() {
                                  _selectedItem = null;
                                  _selectedScrollSlots.fillRange(
                                    0,
                                    _maxScrollSlots,
                                    null,
                                  );
                                  _selectedRune = 'none';
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: _EnhancementDesignSystem.spaceMd,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            borderRadius: BorderRadius.circular(
                              _EnhancementDesignSystem.radiusMd,
                            ),
                          ),
                          child: const Text(
                            'İptal',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _EnhancementDesignSystem.spaceMd),
                    Expanded(
                      child: GestureDetector(
                        onTap: canEnhance ? _enhance : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: _EnhancementDesignSystem.spaceMd,
                          ),
                          decoration: BoxDecoration(
                            gradient: canEnhance
                                ? LinearGradient(
                                    colors: [
                                      Color(0xFF5296FF).withValues(alpha: 0.3),
                                      Color(0xFF5296FF).withValues(alpha: 0.15),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.03),
                                      Colors.white.withValues(alpha: 0.01),
                                    ],
                                  ),
                            border: Border.all(
                              color: canEnhance
                                  ? Color(0xFF5296FF).withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                            borderRadius: BorderRadius.circular(
                              _EnhancementDesignSystem.radiusMd,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              if (_isEnhancing)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF5296FF),
                                    ),
                                  ),
                                )
                              else
                                const Text(
                                  '⚒️',
                                  style: TextStyle(fontSize: 16),
                                ),
                              const SizedBox(
                                width: _EnhancementDesignSystem.spaceSm,
                              ),
                              Text(
                                _isEnhancing
                                    ? 'Güçlendiriliyor...'
                                    : 'Güçlendir',
                                style: TextStyle(
                                  color: canEnhance
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: _EnhancementDesignSystem.spaceLg),
                // ─── INVENTORY GRID ────────────────────────────────────
                _buildInventoryGrid(),

                const SizedBox(height: _EnhancementDesignSystem.spaceLg),
                // ─── UPGRADE TABLE ────────────────────────────────────────
                _buildUpgradeTable(currentLevel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreeSlotPanel(int currentLevel, int previewLevel) {
    return Container(
      padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceMd),
      decoration: BoxDecoration(
        gradient: _EnhancementDesignSystem.gradientBgPanel,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(_EnhancementDesignSystem.radiusLg),
        boxShadow: _EnhancementDesignSystem.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Güçlendirme Yuvaları',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: _EnhancementDesignSystem.spaceMd),
          Row(
            children: <Widget>[
              // Item slot
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      'Eşya',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                    const SizedBox(height: _EnhancementDesignSystem.spaceSm),
                    _buildItemSlot(),
                  ],
                ),
              ),
              const SizedBox(width: _EnhancementDesignSystem.spaceSm),
              Text('+', style: TextStyle(color: Colors.white38, fontSize: 16)),
              const SizedBox(width: _EnhancementDesignSystem.spaceSm),

              // Rune slot
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      'Rune',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                    const SizedBox(height: _EnhancementDesignSystem.spaceSm),
                    _buildRuneSlot(),
                  ],
                ),
              ),
              const SizedBox(width: _EnhancementDesignSystem.spaceSm),
              Text('+', style: TextStyle(color: Colors.white38, fontSize: 16)),
              const SizedBox(width: _EnhancementDesignSystem.spaceSm),

              // Scroll slots
              Expanded(
                flex: 2,
                child: Column(
                  children: <Widget>[
                    Text(
                      'Parşömen (9)',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                    const SizedBox(height: _EnhancementDesignSystem.spaceSm),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      children: List.generate(
                        _maxScrollSlots,
                        (int i) => _buildScrollSlot(i),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _EnhancementDesignSystem.spaceSm),
              Text('→', style: TextStyle(color: Colors.white38, fontSize: 16)),
              const SizedBox(width: _EnhancementDesignSystem.spaceSm),

              // Preview slot
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      'Önizleme',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                    const SizedBox(height: _EnhancementDesignSystem.spaceSm),
                    _buildPreviewSlot(previewLevel),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemSlot() {
    return DragTarget<InventoryItem>(
      onWillAcceptWithDetails: (DragTargetDetails<InventoryItem> details) {
        return _isEnhanceable(details.data);
      },
      onAcceptWithDetails: (DragTargetDetails<InventoryItem> details) {
        setState(() {
          _selectedItem = details.data;
          _lastResult = null;
        });
      },
      builder:
          (
            BuildContext context,
            List<InventoryItem?> candidateData,
            List<dynamic> rejectedData,
          ) => Stack(
            children: <Widget>[
              Container(
                height: 60,
                padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceSm),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedItem != null
                        ? _rarityColor(
                            _selectedItem!.rarity,
                          ).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(
                    _EnhancementDesignSystem.radiusMd,
                  ),
                  color: _selectedItem != null
                      ? _rarityColor(
                          _selectedItem!.rarity,
                        ).withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.02),
                ),
                child: _selectedItem != null
                    ? Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '+${_selectedItem!.enhancementLevel} ${_selectedItem!.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _rarityColor(_selectedItem!.rarity),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Text(
                          'Bırak',
                          style: TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ),
              ),
              if (_selectedItem != null)
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedItem = null),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildRuneSlot() {
    return DragTarget<InventoryItem>(
      onWillAcceptWithDetails: (DragTargetDetails<InventoryItem> details) {
        return _isRuneItem(details.data);
      },
      onAcceptWithDetails: (DragTargetDetails<InventoryItem> details) {
        setState(() {
          _selectedRune = details.data.itemId.replaceFirst('rune_', '');
        });
      },
      builder:
          (
            BuildContext context,
            List<InventoryItem?> candidateData,
            List<dynamic> rejectedData,
          ) => Stack(
            children: <Widget>[
              Container(
                height: 60,
                padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceSm),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedRune != 'none'
                        ? Color(0xFFA855F7).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(
                    _EnhancementDesignSystem.radiusMd,
                  ),
                  color: _selectedRune != 'none'
                      ? Color(0xFFA855F7).withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.02),
                ),
                child: _selectedRune != 'none'
                    ? Row(
                        children: <Widget>[
                          Text('🔮', style: TextStyle(fontSize: 16)),
                          const SizedBox(
                            width: _EnhancementDesignSystem.spaceSm,
                          ),
                          Expanded(
                            child: Text(
                              _kRuneLabels[_selectedRune] ?? _selectedRune,
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFA855F7),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Text(
                          'Bırak',
                          style: TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ),
              ),
              if (_selectedRune != 'none')
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRune = 'none'),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildScrollSlot(int index) {
    final InventoryItem? scroll = _selectedScrollSlots[index];
    final String requiredId = _selectedItem != null
        ? _scrollIdForRarity(_selectedItem!.rarity)
        : '';
    final bool isCompatible = scroll != null && scroll.itemId == requiredId;

    return DragTarget<InventoryItem>(
      onWillAcceptWithDetails: (DragTargetDetails<InventoryItem> details) {
        return _isScrollItem(details.data);
      },
      onAcceptWithDetails: (DragTargetDetails<InventoryItem> details) {
        final InventoryItem dragged = details.data;
        final int sourceIndex = _selectedScrollSlots.indexWhere(
          (InventoryItem? s) => s?.rowId == dragged.rowId,
        );

        setState(() {
          if (sourceIndex == index) {
            return;
          }

          if (sourceIndex >= 0) {
            final InventoryItem? target = _selectedScrollSlots[index];
            _selectedScrollSlots[index] = _selectedScrollSlots[sourceIndex];
            _selectedScrollSlots[sourceIndex] = target;
            return;
          }

          _selectedScrollSlots[index] = dragged;
        });
      },
      builder:
          (
            BuildContext context,
            List<InventoryItem?> candidateData,
            List<dynamic> rejectedData,
          ) => Stack(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: scroll != null && isCompatible
                        ? Colors.amber.withValues(alpha: 0.5)
                        : scroll != null && !isCompatible
                        ? Colors.red.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(
                    _EnhancementDesignSystem.radiusMd,
                  ),
                  color: scroll != null && isCompatible
                      ? Colors.amber.withValues(alpha: 0.08)
                      : scroll != null && !isCompatible
                      ? Colors.red.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.02),
                ),
                child: scroll != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text('📜', style: TextStyle(fontSize: 12)),
                          Text(
                            scroll.name,
                            style: TextStyle(
                              fontSize: 7,
                              color: Colors.white70,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isCompatible)
                            Text(
                              '✗',
                              style: TextStyle(fontSize: 8, color: Colors.red),
                            ),
                        ],
                      )
                    : Center(
                        child: Text(
                          '+',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
              ),
              if (scroll != null)
                Positioned(
                  right: 1,
                  top: 1,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedScrollSlots[index] = null),
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 9,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildPreviewSlot(int previewLevel) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceSm),
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedItem != null
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(_EnhancementDesignSystem.radiusMd),
        color: _selectedItem != null
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.02),
      ),
      child: _selectedItem != null
          ? Opacity(
              opacity: 0.6,
              child: Row(
                children: <Widget>[
                  Text(
                    '+$previewLevel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _selectedItem!.name,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white54,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Text(
                '✨',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoPanel(
    String requiredScrollLabel,
    int successChance,
    int nextCost,
    int gold,
    int currentLevel,
  ) {
    final bool hasEnoughGold = gold >= nextCost;
    final bool hasIncompatibleScroll = _selectedScrollSlots.any(
      (s) => s != null && _findCompatibleScroll() == null,
    );

    return Container(
      padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceMd),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(_EnhancementDesignSystem.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Güçlendirme Bilgisi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: _EnhancementDesignSystem.spaceMd),
          _buildInfoRow('Gerekli Parşömen', requiredScrollLabel, Colors.amber),
          _buildInfoRow(
            'Başarı Şansı',
            '$successChance%',
            _getSuccessColor(successChance),
          ),
          _buildInfoRow(
            'Maliyet',
            _formatGold(nextCost),
            _EnhancementDesignSystem.colorGold,
          ),
          _buildInfoRow(
            'Altın Bakiyesi',
            _formatGold(gold),
            hasEnoughGold ? Colors.green : Colors.red,
          ),
          _buildInfoRow(
            'Risk',
            _riskLabel(currentLevel),
            _riskColor(currentLevel),
          ),

          // Compatibility warning
          if (hasIncompatibleScroll && _selectedItem != null)
            Padding(
              padding: const EdgeInsets.only(
                top: _EnhancementDesignSystem.spaceMd,
              ),
              child: Container(
                padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceMd),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(
                    _EnhancementDesignSystem.radiusMd,
                  ),
                ),
                child: Text(
                  '❌ Slotlardaki parşömenler seçili eşyayla uyumlu değil. Gereken: $requiredScrollLabel',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _EnhancementDesignSystem.spaceMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white70)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSuccessColor(int chance) {
    if (chance >= 70) return Colors.green;
    if (chance >= 35) return Colors.yellow;
    if (chance >= 20) return Colors.orange;
    return Colors.red;
  }

  Widget _buildUpgradeTable(int currentLevel) {
    return Container(
      padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceMd),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(_EnhancementDesignSystem.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Güçlendirme Tablosu',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: _EnhancementDesignSystem.spaceMd),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              columnWidths: const <int, TableColumnWidth>{
                0: FixedColumnWidth(40),
                1: FixedColumnWidth(80),
                2: FixedColumnWidth(60),
                3: FixedColumnWidth(80),
              },
              children: <TableRow>[
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  children: <Widget>[
                    _tableHeader('Sev'),
                    _tableHeader('Maliyet'),
                    _tableHeader('Şans'),
                    _tableHeader('Risk'),
                  ],
                ),
                for (int lvl = 0; lvl <= 10; lvl++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: lvl == currentLevel
                          ? Color(0xFF5296FF).withValues(alpha: 0.08)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    children: <Widget>[
                      _tableCell(
                        '+$lvl',
                        lvl == currentLevel,
                        Color(0xFF5296FF),
                      ),
                      _tableCell(
                        _formatGold(_kUpgradeCosts[lvl] ?? 0),
                        false,
                        _EnhancementDesignSystem.colorGold,
                        small: true,
                      ),
                      _tableCell(
                        '${_kUpgradeChances[lvl] ?? 0}%',
                        false,
                        Colors.white70,
                        small: true,
                      ),
                      _tableCell(
                        _riskLabel(lvl),
                        false,
                        _riskColor(lvl),
                        small: true,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: Colors.white38,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _tableCell(
    String text,
    bool bold,
    Color color, {
    bool small = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Text(
      text,
      style: TextStyle(
        fontSize: small ? 9 : 11,
        color: color,
        fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
      ),
    ),
  );

  // ─── INVENTORY GRID ──────────────────────────────────────────────────
  Widget _buildInventoryGrid() {
    const int gridColCount = 5;
    const int maxSlots = 20;
    final inventoryState = ref.watch(inventoryProvider);
    final List<InventoryItem> items = inventoryState.items;

    return Container(
      padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceMd),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(_EnhancementDesignSystem.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Envanter Izgarası',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
              Text(
                'Sürükle-bırak aktif',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white30,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: _EnhancementDesignSystem.spaceMd),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridColCount,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: maxSlots,
            itemBuilder: (_, int idx) {
              InventoryItem? item;
              for (final InventoryItem inventoryItem in items) {
                if (inventoryItem.slotPosition == idx) {
                  item = inventoryItem;
                  break;
                }
              }

              if (item == null) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    borderRadius: BorderRadius.circular(
                      _EnhancementDesignSystem.radiusMd,
                    ),
                    color: Colors.white.withValues(alpha: 0.02),
                  ),
                  child: Center(
                    child: Text(
                      '📭',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                );
              }

              final InventoryItem selectedInventoryItem = item;
              final bool isSelected =
                  (_selectedItem?.rowId == selectedInventoryItem.rowId) ||
                  (_selectedRune != 'none' &&
                      selectedInventoryItem.itemId == 'rune_$_selectedRune') ||
                  (_selectedScrollSlots.any(
                    (s) => s?.rowId == selectedInventoryItem.rowId,
                  ));

              final Widget itemTile = GestureDetector(
                onTap: () => _handleInventoryItemTap(selectedInventoryItem),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? _rarityColor(
                              selectedInventoryItem.rarity,
                            ).withValues(alpha: 0.8)
                          : _rarityColor(
                              selectedInventoryItem.rarity,
                            ).withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(
                      _EnhancementDesignSystem.radiusMd,
                    ),
                    color: _rarityColor(
                      selectedInventoryItem.rarity,
                    ).withValues(alpha: isSelected ? 0.15 : 0.05),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              _getItemEmoji(selectedInventoryItem),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Flexible(
                              child: Text(
                                selectedInventoryItem.name,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: _rarityColor(
                                    selectedInventoryItem.rarity,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                              ),
                            ),
                            if (selectedInventoryItem.enhancementLevel > 0)
                              Text(
                                '+${selectedInventoryItem.enhancementLevel}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (selectedInventoryItem.quantity > 1)
                              Text(
                                'x${selectedInventoryItem.quantity}',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _rarityColor(item.rarity),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );

              return Draggable<InventoryItem>(
                data: selectedInventoryItem,
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Opacity(opacity: 0.9, child: itemTile),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: itemTile),
                child: itemTile,
              );
            },
          ),
          if (inventoryState.status == InventoryStatus.loading && items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: _EnhancementDesignSystem.spaceMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const <Widget>[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Envanter yükleniyor...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _handleInventoryItemTap(InventoryItem item) {
    if (_isEnhanceable(item)) {
      setState(() {
        _selectedItem = item;
        _lastResult = null;
      });
    } else if (_isScrollItem(item)) {
      // Add to first empty scroll slot
      if (_selectedScrollSlots.any(
        (InventoryItem? s) => s?.rowId == item.rowId,
      )) {
        return;
      }
      for (int i = 0; i < _maxScrollSlots; i++) {
        if (_selectedScrollSlots[i] == null) {
          setState(() => _selectedScrollSlots[i] = item);
          break;
        }
      }
    } else if (_isRuneItem(item)) {
      setState(() => _selectedRune = item.itemId.replaceFirst('rune_', ''));
    }
  }

  String _getItemEmoji(InventoryItem item) {
    if (item.itemType == ItemType.weapon) {
      return '⚔️';
    }
    if (item.itemType == ItemType.armor) {
      return '🛡️';
    }
    if (_isScrollItem(item)) {
      return '📜';
    }
    if (_isRuneItem(item)) {
      return '🔮';
    }
    if (item.itemType == ItemType.potion) {
      return '🧪';
    }
    return '📦';
  }
}

// ============================================================================
// ITEM PICKER SHEET
// ============================================================================
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
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(_EnhancementDesignSystem.spaceMd),
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Öğe bulunamadı',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, int i) {
                      final InventoryItem item = items[i];
                      return GestureDetector(
                        onTap: () => onSelected(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _EnhancementDesignSystem.spaceMd,
                            vertical: _EnhancementDesignSystem.spaceSm,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(
                              _EnhancementDesignSystem.spaceMd,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              borderRadius: BorderRadius.circular(
                                _EnhancementDesignSystem.radiusMd,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  '${item.enhancementLevel > 0 ? '+${item.enhancementLevel}' : ''} ${item.name}',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  getRarityLabel(item.rarity),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
