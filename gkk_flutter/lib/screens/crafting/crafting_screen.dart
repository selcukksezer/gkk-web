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
      ref.read(craftingProvider.notifier).finalizeCraftedItem(item.id).then((_) {
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

  Future<void> _craft() async {
    final craftState = ref.read(craftingProvider);
    final authState = ref.read(authProvider);
    final authId = authState.user?.id ??
        SupabaseService.client.auth.currentUser?.id ?? '';
    if (authId.isEmpty || craftState.selectedRecipeId == null) return;

    // Refresh inventory before crafting to validate materials are still available
    await ref.read(inventoryProvider.notifier).loadInventory();

    final bool ok = await ref.read(craftingProvider.notifier).craftItem(
          authId: authId,
          recipeId: craftState.selectedRecipeId!,
          batchCount: craftState.selectedBatchCount,
          inventoryItems: ref.read(inventoryProvider).items,
        );

    if (ok) {
      _showSnack('Üretim başlatıldı!');
      await ref.read(inventoryProvider.notifier).loadInventory();
    } else {
      final err = ref.read(craftingProvider).error;
      if (err != null) _showSnack(err);
    }
  }

  Future<void> _claim(String id) async {
    final ok = await ref.read(craftingProvider.notifier).claimItem(id);
    if (ok) {
      _showSnack('Ürün alındı!');
      await ref.read(inventoryProvider.notifier).loadInventory();
    } else {
      final err = ref.read(craftingProvider).error;
      if (err != null) _showSnack(err);
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

    // Selected recipe
    final CraftRecipe? selectedRecipe = craftState.selectedRecipeId == null
        ? null
        : craftState.recipes.cast<CraftRecipe?>().firstWhere(
              (r) => r?.id == craftState.selectedRecipeId,
              orElse: () => null,
            );

    final int playerGems = playerState.profile?.gems ?? 0;
    final int gemCost = selectedRecipe == null
        ? 0
        : (craftState.selectedBatchCount - 1).clamp(0, craftingBatchLimit);
    final bool canAffordGems = playerGems >= gemCost;
    final bool hasEnoughMaterials = selectedRecipe == null
        ? false
        : hasMaterials(selectedRecipe, batchCount: craftState.selectedBatchCount);
    final bool canCraft = selectedRecipe != null &&
        hasEnoughMaterials &&
        canAffordGems &&
        !craftState.isCrafting &&
        craftState.queue.length < craftingQueueLimit;

    return Scaffold(
      drawer: GameDrawer(onLogout: onLogout),
      appBar: GameTopBar(title: 'El Sanatları', onLogout: onLogout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.crafting),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: craftState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: <Widget>[
                    // ── Craft preview ──────────────────────────────────────
                    _PreviewPanel(
                      recipe: selectedRecipe,
                      batchCount: craftState.selectedBatchCount,
                      gemCost: gemCost,
                      canCraft: canCraft,
                      isCrafting: craftState.isCrafting,
                      hasEnoughMaterials: hasEnoughMaterials,
                      canAffordGems: canAffordGems,
                      onCraft: _craft,
                      onBatchDecrement: () => ref
                          .read(craftingProvider.notifier)
                          .setBatchCount(craftState.selectedBatchCount - 1),
                      onBatchIncrement: () => ref
                          .read(craftingProvider.notifier)
                          .setBatchCount(craftState.selectedBatchCount + 1),
                    ),
                    // ── Tab bar ────────────────────────────────────────────
                    Container(
                      color: const Color(0xFF10131D),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        unselectedLabelStyle: const TextStyle(fontSize: 12),
                        tabs: _kTabs
                            .map((t) => Tab(text: t.$2))
                            .toList(),
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
                                    craftState.selectedRecipeId == recipe.id;
                                return _RecipeCard(
                                  recipe: recipe,
                                  isSelected: isSelected,
                                  hasMaterials: hasMaterials(
                                    recipe,
                                    batchCount: craftState.selectedBatchCount,
                                  ),
                                  onTap: () {
                                    ref
                                        .read(craftingProvider.notifier)
                                        .selectRecipe(
                                          isSelected ? null : recipe.id,
                                        );
                                  },
                                );
                              },
                            ),
                    ),
                    // ── Queue section ──────────────────────────────────────
                    if (craftState.queue.isNotEmpty)
                      _QueueSection(
                        queue: craftState.queue,
                        isCancelling: craftState.isCancelling,
                        onClaim: _claim,
                        onAcknowledge: _acknowledge,
                        onCancel: _cancel,
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
    required this.onCraft,
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
  final VoidCallback onCraft;
  final VoidCallback onBatchDecrement;
  final VoidCallback onBatchIncrement;

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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
      ),
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recipe!.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: <Widget>[
              _InfoChip(
                icon: Icons.military_tech_rounded,
                label: 'Seviye ${recipe!.requiredLevel}',
              ),
              _InfoChip(
                icon: Icons.percent_rounded,
                label: '${(recipe!.successRate * 100).toStringAsFixed(0)}% Başarı',
              ),
              _InfoChip(icon: Icons.timer_rounded, label: timeLabel),
              if (gemCost > 0)
                _InfoChip(
                  icon: Icons.diamond_rounded,
                  label: '$gemCost 💎',
                  color: const Color(0xFFCC44FF),
                ),
              if (recipe!.goldCost > 0)
                _InfoChip(
                  icon: Icons.paid_rounded,
                  label: '${recipe!.goldCost} 🪙',
                  color: const Color(0xFFDDAA00),
                ),
            ],
          ),
          if (recipe!.ingredients.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: recipe!.ingredients.map((ing) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${ing.itemName} x${ing.quantity * batchCount}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              // Batch selector
              Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      onPressed: batchCount > 1 ? onBatchDecrement : null,
                      icon: const Icon(Icons.remove, size: 16),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      '$batchCount',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    IconButton(
                      onPressed:
                          batchCount < craftingBatchLimit ? onBatchIncrement : null,
                      icon: const Icon(Icons.add, size: 16),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canCraft ? onCraft : null,
                  icon: isCrafting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.construction_rounded, size: 16),
                  label: Text(
                    !hasEnoughMaterials
                        ? 'Malzeme Yetersiz'
                        : !canAffordGems
                            ? 'Taş Yetersiz'
                            : isCrafting
                                ? 'Üretiliyor...'
                                : 'Üret',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: canCraft
                        ? const Color(0xFF4B6FFF)
                        : Colors.white12,
                  ),
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
          color: isSelected ? rarityColor.withValues(alpha: 0.15) : Colors.black26,
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
                        fontSize: 12, fontWeight: FontWeight.w700),
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
                style: TextStyle(
                    fontSize: 10, color: Colors.purple.shade200),
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
class _QueueSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.black38,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              'Üretim Kuyruğu (${queue.length}/$craftingQueueLimit)',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final CraftQueueItem item = queue[index];
                return _QueueItemTile(
                  item: item,
                  isCancelling: isCancelling,
                  onClaim: () => onClaim(item.id),
                  onAcknowledge: () => onAcknowledge(item.id),
                  onCancel: () => onCancel(item.id),
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

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({
    required this.item,
    required this.isCancelling,
    required this.onClaim,
    required this.onAcknowledge,
    required this.onCancel,
  });

  final CraftQueueItem item;
  final bool isCancelling;
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
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.recipeName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (isClaimed)
                  const Text(
                    '✅ Teslim alındı',
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  )
                else if (isFailed)
                  const Text(
                    '❌ Başarısız',
                    style: TextStyle(fontSize: 11, color: Colors.red),
                  )
                else if (isReady)
                  const Text(
                    '✅ Hazır!',
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  )
                else
                  Text(
                    '⏳ ${_formatDuration(remainSec)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isReady)
            FilledButton(
              onPressed: onClaim,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Talep Et'),
            )
          else if (isFailed)
            FilledButton(
              onPressed: onAcknowledge,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Kabul Et'),
            )
          else if (!isClaimed)
            IconButton(
              onPressed: isCancelling ? null : onCancel,
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: 'İptal',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
