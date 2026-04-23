import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/crafting_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crafting_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ---------------------------------------------------------------------------
// Tab configuration
// ---------------------------------------------------------------------------
const List<(String, String)> _kTabs = <(String, String)>[
  ('tumu', 'Tümü'),
  ('weapon', '🗡️ Silahlar'),
  ('armor', '🛡️ Zırhlar'),
  ('potion', '⚗️ İksirler'),
  ('accessory', '💍 Mücevherler'),
  ('rune', '✨ Runlar'),
  ('scroll', '📜 Yazıtlar'),
];

Color _rarityColor(String rarity) {
  switch (rarity) {
    case 'uncommon':
      return Colors.green;
    case 'rare':
      return Colors.blue;
    case 'epic':
      return Colors.purple;
    case 'legendary':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

String _formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) return 'Hazır';
  final int h = totalSeconds ~/ 3600;
  final int m = (totalSeconds % 3600) ~/ 60;
  final int s = totalSeconds % 60;
  if (h > 0) return '${h}s ${m}d ${s}sn';
  if (m > 0) return '${m}d ${s}sn';
  return '${s}sn';
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class CraftingScreen extends ConsumerStatefulWidget {
  const CraftingScreen({super.key});

  @override
  ConsumerState<CraftingScreen> createState() => _CraftingScreenState();
}

class _CraftingScreenState extends ConsumerState<CraftingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _queueTimer;
  final Set<String> _pendingFinalizations = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(inventoryProvider.notifier).loadInventory();
      final int level = ref.read(playerProvider).profile?.level ?? 1;
      await ref.read(craftingProvider.notifier).loadRecipes(level);
      await ref.read(craftingProvider.notifier).loadQueue();
      _startQueueTimer();
    });
  }

  void _startQueueTimer() {
    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _autoFinalizeCompletedItems();
      setState(() {});
    });
  }

  void _autoFinalizeCompletedItems() {
    final queue = ref.read(craftingProvider).queue;
    for (final item in queue) {
      if (item.isCompleted || item.claimed || (item.failed == true)) continue;
      if (_pendingFinalizations.contains(item.id)) continue;

      final DateTime? completesAt = DateTime.tryParse(item.completesAt);
      if (completesAt == null) continue;
      if (completesAt.isAfter(DateTime.now())) continue;

      // Timer has passed – finalize on the server
      _pendingFinalizations.add(item.id);
      ref.read(craftingProvider.notifier).finalizeCraftedItem(item.id).then((
        _,
      ) {
        _pendingFinalizations.remove(item.id);
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final String tab = _kTabs[_tabController.index].$1;
    ref.read(craftingProvider.notifier).setSelectedTab(tab);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _queueTimer?.cancel();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<bool> _craft() async {
    final craftState = ref.read(craftingProvider);
    final authState = ref.read(authProvider);
    final authId =
        authState.user?.id ?? SupabaseService.client.auth.currentUser?.id ?? '';
    if (authId.isEmpty || craftState.selectedRecipeId == null) return false;

    // Refresh inventory before crafting to validate materials are still available
    await ref.read(inventoryProvider.notifier).loadInventory();

    final bool ok = await ref
        .read(craftingProvider.notifier)
        .craftItem(
          authId: authId,
          recipeId: craftState.selectedRecipeId!,
          batchCount: craftState.selectedBatchCount,
          inventoryItems: ref.read(inventoryProvider).items,
        );

    if (ok) {
      _showSnack('Üretim başlatıldı!');
      ref.read(craftingProvider.notifier).selectRecipe(null);
      ref.read(craftingProvider.notifier).setBatchCount(1);
      await ref.read(inventoryProvider.notifier).loadInventory();
      return true;
    } else {
      final err = ref.read(craftingProvider).error;
      if (err != null) _showSnack(err);
      return false;
    }
  }

  Future<void> _openRecipePreview(CraftRecipe recipe) async {
    ref.read(craftingProvider.notifier).selectRecipe(recipe.id);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final craftState = ref.watch(craftingProvider);
              final playerState = ref.watch(playerProvider);
              final hasMaterials = ref.watch(hasMaterialsProvider);

              final CraftRecipe? selectedRecipe =
                  craftState.selectedRecipeId == null
                  ? null
                  : craftState.recipes.cast<CraftRecipe?>().firstWhere(
                      (r) => r?.id == craftState.selectedRecipeId,
                      orElse: () => null,
                    );

              if (selectedRecipe == null) {
                return const SizedBox.shrink();
              }

              final int playerGems = playerState.profile?.gems ?? 0;
              final int gemCost = (craftState.selectedBatchCount - 1).clamp(
                0,
                craftingBatchLimit,
              );
              final bool canAffordGems = playerGems >= gemCost;
              final bool hasEnoughMaterials = hasMaterials(
                selectedRecipe,
                batchCount: craftState.selectedBatchCount,
              );
              final bool canCraft =
                  hasEnoughMaterials &&
                  canAffordGems &&
                  !craftState.isCrafting &&
                  craftState.queue.length < craftingQueueLimit;

              final Map<String, int> ownedQuantities = <String, int>{};
              for (final item in ref.read(inventoryProvider).items) {
                ownedQuantities[item.itemId] =
                    (ownedQuantities[item.itemId] ?? 0) + item.quantity;
              }

              return _PreviewPanel(
                recipe: selectedRecipe,
                batchCount: craftState.selectedBatchCount,
                gemCost: gemCost,
                canCraft: canCraft,
                isCrafting: craftState.isCrafting,
                hasEnoughMaterials: hasEnoughMaterials,
                canAffordGems: canAffordGems,
                ownedQuantities: ownedQuantities,
                onCraft: () async {
                  final bool ok = await _craft();
                  if (ok && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                onClose: () => Navigator.of(dialogContext).pop(),
                onBatchDecrement: () => ref
                    .read(craftingProvider.notifier)
                    .setBatchCount(craftState.selectedBatchCount - 1),
                onBatchIncrement: () => ref
                    .read(craftingProvider.notifier)
                    .setBatchCount(craftState.selectedBatchCount + 1),
              );
            },
          ),
        );
      },
    );

    ref.read(craftingProvider.notifier).selectRecipe(null);
    ref.read(craftingProvider.notifier).setBatchCount(1);
  }

  Future<void> _claim(String id) async {
    final ok = await ref.read(craftingProvider.notifier).claimItem(id);
    if (ok) {
      _showSnack('Ürün alındı!');
      await ref.read(inventoryProvider.notifier).loadInventory();
    } else {
      final err = ref.read(craftingProvider).error;
      if (err != null && err != 'Üretim başarısız') _showSnack(err);
    }
  }

  Future<void> _acknowledge(String id) async {
    await ref.read(craftingProvider.notifier).acknowledgeItem(id);
  }

  Future<void> _cancel(String id) async {
    final ok = await ref.read(craftingProvider.notifier).cancelItem(id);
    if (!ok) {
      final err = ref.read(craftingProvider).error;
      if (err != null) _showSnack(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final craftState = ref.watch(craftingProvider);
    final playerState = ref.watch(playerProvider);
    final hasMaterials = ref.watch(hasMaterialsProvider);

    Future<void> onLogout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    // Filtered recipes
    final List<CraftRecipe> filtered = craftState.selectedTab == 'tumu'
        ? craftState.recipes
        : craftState.recipes
              .where((r) => r.recipeType == craftState.selectedTab)
              .toList();

    final int playerGems = playerState.profile?.gems ?? 0;

    return Scaffold(
      drawer: GameDrawer(onLogout: onLogout),
      appBar: GameTopBar(title: 'Zanaat', onLogout: onLogout),
      bottomNavigationBar: const GameBottomBar(
        currentRoute: AppRoutes.crafting,
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
        child: craftState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: Row(
                            children: <Widget>[
                              const Text(
                                '🔨 Üretim Atölyesi',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                              const Spacer(),
                              if (playerGems > 0)
                                Text(
                                  '💎 $playerGems',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFCC44FF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // ── Tab bar ────────────────────────────────────────────
                        Container(
                          color: const Color(0xFF10131D),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            unselectedLabelStyle: const TextStyle(fontSize: 12),
                            tabs: _kTabs.map((t) => Tab(text: t.$2)).toList(),
                          ),
                        ),
                        // ── Recipe grid ────────────────────────────────────────
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Bu kategoride tarif bulunamadı.',
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 180,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        childAspectRatio: 0.85,
                                      ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final CraftRecipe recipe = filtered[index];
                                    final bool isSelected =
                                        craftState.selectedRecipeId ==
                                        recipe.id;
                                    return _RecipeCard(
                                      recipe: recipe,
                                      isSelected: isSelected,
                                      hasMaterials: hasMaterials(
                                        recipe,
                                        batchCount:
                                            craftState.selectedBatchCount,
                                      ),
                                      onTap: () {
                                        if (isSelected) {
                                          ref
                                              .read(craftingProvider.notifier)
                                              .selectRecipe(null);
                                          return;
                                        }
                                        _openRecipePreview(recipe);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                    if (craftState.queue.isNotEmpty)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _QueueSection(
                              queue: craftState.queue,
                              isCancelling: craftState.isCancelling,
                              onClaim: _claim,
                              onAcknowledge: _acknowledge,
                              onCancel: _cancel,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview panel
// ---------------------------------------------------------------------------
class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.recipe,
    required this.batchCount,
    required this.gemCost,
    required this.canCraft,
    required this.isCrafting,
    required this.hasEnoughMaterials,
    required this.canAffordGems,
    required this.ownedQuantities,
    required this.onCraft,
    required this.onClose,
    required this.onBatchDecrement,
    required this.onBatchIncrement,
  });

  final CraftRecipe? recipe;
  final int batchCount;
  final int gemCost;
  final bool canCraft;
  final bool isCrafting;
  final bool hasEnoughMaterials;
  final bool canAffordGems;
  final Map<String, int> ownedQuantities;
  final VoidCallback onCraft;
  final VoidCallback onClose;
  final VoidCallback onBatchDecrement;
  final VoidCallback onBatchIncrement;

  static double _parseRate(double value) {
    if (value <= 0) return 0.8;
    return value > 1 ? value / 100 : value;
  }

  @override
  Widget build(BuildContext context) {
    if (recipe == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: Colors.white38, size: 18),
            SizedBox(width: 10),
            Text('Bir tarif seçin', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    final Color rarityColor = _rarityColor(recipe!.outputRarity);
    final int? timeSec = recipe!.productionTimeSeconds;
    final String timeLabel = timeSec == null
        ? '—'
        : _formatDuration(timeSec * batchCount);
    final int totalOutput = recipe!.outputQuantity * batchCount;
    final int totalXp = (recipe!.xpReward ?? 0) * batchCount;
    final double successRate = _parseRate(recipe!.successRate);

    final bool showGemError = !canAffordGems && gemCost > 0;
    final bool showMatError = !hasEnoughMaterials;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x33202A44), Color(0x140E1426)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recipe!.outputName?.isNotEmpty == true
                          ? recipe!.outputName!
                          : recipe!.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: rarityColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Üretim Ön İzlemesi',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: 'Kapat',
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Üretilecek Malzeme',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white60,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.cyan.withValues(alpha: 0.5),
                width: 1.4,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.cyan.withValues(alpha: 0.20),
                  Colors.blue.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    recipe!.outputItemId.isNotEmpty ? '📦' : '❔',
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        recipe!.outputName?.isNotEmpty == true
                            ? recipe!.outputName!
                            : recipe!.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: rarityColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Miktar: x$totalOutput',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Text(
            'Gerekli Malzemeler',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white60,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recipe!.ingredients.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.84,
            ),
            itemBuilder: (BuildContext context, int index) {
              final ing = recipe!.ingredients[index];
              final int owned = ownedQuantities[ing.itemId] ?? 0;
              final int required = ing.quantity * batchCount;
              final bool enough = owned >= required;
              final String ingredientName = ing.itemName.trim().isNotEmpty
                  ? ing.itemName
                  : (ing.itemId.isNotEmpty ? ing.itemId : 'Bilinmiyor');
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: enough
                        ? Colors.green.withValues(alpha: 0.55)
                        : Colors.red.withValues(alpha: 0.55),
                    width: 1.3,
                  ),
                  color: enough
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                ),
                child: Column(
                  children: <Widget>[
                    const Text('📦', style: TextStyle(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(
                      ingredientName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$owned / $required',
                      style: TextStyle(
                        fontSize: 10,
                        color: enough ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              _InfoChip(
                icon: Icons.military_tech_rounded,
                label: 'Sv${recipe!.requiredLevel}',
              ),
              _InfoChip(
                icon: Icons.percent_rounded,
                label: '${(successRate * 100).round()}% Başarı',
                color: const Color(0xFFFCD34D),
              ),
              _InfoChip(icon: Icons.timer_rounded, label: timeLabel),
              _InfoChip(
                icon: Icons.diamond_rounded,
                label: '$gemCost 💎',
                color: showGemError
                    ? Colors.redAccent
                    : const Color(0xFFD8B4FE),
              ),
              if (recipe!.goldCost > 0)
                _InfoChip(
                  icon: Icons.paid_rounded,
                  label: '${recipe!.goldCost} 🪙',
                  color: const Color(0xFFFDE68A),
                ),
              _InfoChip(
                icon: Icons.auto_awesome_rounded,
                label: '+$totalXp XP',
                color: const Color(0xFFFCD34D),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: Column(
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Batch Sayısı',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white60,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: TextButton(
                        onPressed: batchCount > 1 ? onBatchDecrement : null,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          '−',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$batchCount',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: TextButton(
                        onPressed: batchCount < craftingBatchLimit
                            ? onBatchIncrement
                            : null,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          '+',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Max: 5',
                  style: TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ),

          if (showGemError) _buildErrorBox('⚠️ Elmas yetersiz'),
          if (showMatError) _buildErrorBox('⚠️ Malzeme yetersiz'),

          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: onClose,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.30),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: canCraft ? onCraft : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    isCrafting
                        ? 'Üretiliyor...'
                        : '🔨 Üretimi Başlat (${batchCount}x)',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.14),
          border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recipe card
// ---------------------------------------------------------------------------
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.isSelected,
    required this.hasMaterials,
    required this.onTap,
  });

  final CraftRecipe recipe;
  final bool isSelected;
  final bool hasMaterials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = _rarityColor(recipe.outputRarity);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? rarityColor.withValues(alpha: 0.15)
              : Colors.black26,
          border: Border.all(
            color: isSelected ? rarityColor : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: rarityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Lv. ${recipe.requiredLevel}',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
            const SizedBox(height: 2),
            Text(
              '${(recipe.successRate * 100).toStringAsFixed(0)}% başarı',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
            if (recipe.gemCost > 0)
              Text(
                '💎 ${recipe.gemCost}',
                style: TextStyle(fontSize: 10, color: Colors.purple.shade200),
              ),
            const SizedBox(height: 4),
            if (!hasMaterials)
              const Text(
                '⚠ Malzeme yok',
                style: TextStyle(fontSize: 9, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Queue section
// ---------------------------------------------------------------------------
class _QueueSection extends StatefulWidget {
  const _QueueSection({
    required this.queue,
    required this.isCancelling,
    required this.onClaim,
    required this.onAcknowledge,
    required this.onCancel,
  });

  final List<CraftQueueItem> queue;
  final bool isCancelling;
  final Future<void> Function(String) onClaim;
  final Future<void> Function(String) onAcknowledge;
  final Future<void> Function(String) onCancel;

  @override
  State<_QueueSection> createState() => _QueueSectionState();
}

class _QueueSectionState extends State<_QueueSection> {
  bool _expanded = false;
  final Set<String> _pendingClaims = <String>{};
  final Set<String> _pendingAcks = <String>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x33202A44), Color(0x140E1426)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  Text(
                    '📦 Üretim Kuyruğu (${widget.queue.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Text(
                      '▼',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              constraints: const BoxConstraints(maxHeight: 390),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.queue.length,
                separatorBuilder: (_, separatorIndex) =>
                    const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final CraftQueueItem item = widget.queue[index];
                  final bool claimPending = _pendingClaims.contains(item.id);
                  final bool ackPending = _pendingAcks.contains(item.id);
                  return _QueueItemTile(
                    item: item,
                    isCancelling: widget.isCancelling,
                    claimPending: claimPending,
                    ackPending: ackPending,
                    onClaim: () async {
                      if (claimPending) return;
                      setState(() => _pendingClaims.add(item.id));
                      try {
                        await widget.onClaim(item.id);
                      } finally {
                        if (mounted) {
                          setState(() => _pendingClaims.remove(item.id));
                        }
                      }
                    },
                    onAcknowledge: () async {
                      if (ackPending) return;
                      setState(() => _pendingAcks.add(item.id));
                      try {
                        await widget.onAcknowledge(item.id);
                      } finally {
                        if (mounted) {
                          setState(() => _pendingAcks.remove(item.id));
                        }
                      }
                    },
                    onCancel: () async {
                      final bool? ok = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext c) => AlertDialog(
                          backgroundColor: const Color(0xFF111827),
                          title: const Text('⚠️ Üretim İptal Et?'),
                          content: const Text(
                            'Bu işlem geri alınamaz. Ödül geri verilmeyecektir!',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Vazgeç'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Evet, İptal Et'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await widget.onCancel(item.id);
                      }
                    },
                  );
                },
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({
    required this.item,
    required this.isCancelling,
    required this.claimPending,
    required this.ackPending,
    required this.onClaim,
    required this.onAcknowledge,
    required this.onCancel,
  });

  final CraftQueueItem item;
  final bool isCancelling;
  final bool claimPending;
  final bool ackPending;
  final VoidCallback onClaim;
  final VoidCallback onAcknowledge;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bool isFailed = item.failed == true;
    final bool isClaimed = item.claimed;
    final bool isReady = item.isCompleted && !isClaimed && !isFailed;

    // Remaining seconds
    int remainSec = 0;
    if (!item.isCompleted && !isFailed) {
      final DateTime? completesAt = DateTime.tryParse(item.completesAt);
      if (completesAt != null) {
        remainSec = completesAt.difference(DateTime.now()).inSeconds;
        if (remainSec < 0) remainSec = 0;
      }
    }

    final DateTime? startsAt = DateTime.tryParse(item.startedAt);
    final DateTime? completesAt = DateTime.tryParse(item.completesAt);
    final DateTime now = DateTime.now();
    double progress = 0;
    if (startsAt != null && completesAt != null) {
      final int totalMs = completesAt.difference(startsAt).inMilliseconds;
      final int doneMs = now.difference(startsAt).inMilliseconds;
      if (totalMs <= 0) {
        progress = 1;
      } else {
        progress = (doneMs / totalMs).clamp(0, 1);
      }
    }

    final bool awaitingFinalize =
        !item.isCompleted && remainSec == 0 && !isFailed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isFailed
            ? Colors.red.withValues(alpha: 0.12)
            : isReady
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFailed
              ? Colors.red.withValues(alpha: 0.4)
              : isReady
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.recipeIcon?.isNotEmpty == true ? item.recipeIcon! : '📦',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.outputName?.isNotEmpty == true
                          ? item.outputName!
                          : item.recipeName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: <Widget>[
                        Text(
                          'x${item.batchCount} adet',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white60,
                          ),
                        ),
                        if (item.isCompleted &&
                            !isFailed &&
                            (item.xpReward ?? 0) > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0x33D97706),
                            ),
                            child: Text(
                              '+${(item.xpReward ?? 0) * item.batchCount} XP',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFFDE68A),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isFailed && !isClaimed)
                Text(
                  item.isCompleted ? 'Hazır!' : _formatDuration(remainSec),
                  style: TextStyle(
                    fontSize: 10,
                    color: item.isCompleted
                        ? Colors.greenAccent
                        : Colors.yellowAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (!item.isCompleted && !isFailed) ...<Widget>[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF6366F1),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (isReady)
            FilledButton(
              onPressed: claimPending ? null : onClaim,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                minimumSize: const Size.fromHeight(32),
              ),
              child: Text(claimPending ? 'Talep Ediliyor...' : '✓ Talep Et'),
            )
          else if (isFailed)
            FilledButton(
              onPressed: ackPending ? null : onAcknowledge,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                minimumSize: const Size.fromHeight(32),
              ),
              child: Text(ackPending ? 'İşleniyor...' : 'Tamam'),
            )
          else if (isClaimed)
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.10),
              ),
              child: const Text(
                '✓ Talep Edildi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else if (awaitingFinalize)
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.10),
              ),
              child: const Text(
                'Tamamlanıyor...',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else if (!isClaimed)
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    child: const Text(
                      'Üretiliyor...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    onPressed: isCancelling ? null : onCancel,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0x7FD32F2F),
                    ),
                    child: const Text('✕'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Colors.white60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}
