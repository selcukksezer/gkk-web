import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/crafting_model.dart';
import '../models/inventory_model.dart';
import 'inventory_provider.dart';

const int craftingBatchLimit = 5;
const int craftingQueueLimit = 10;

class CraftingState {
  const CraftingState({
    required this.recipes,
    required this.queue,
    required this.isLoading,
    required this.isCrafting,
    required this.isCancelling,
    this.error,
    this.selectedRecipeId,
    required this.selectedBatchCount,
    required this.selectedTab,
  });

  final List<CraftRecipe> recipes;
  final List<CraftQueueItem> queue;
  final bool isLoading;
  final bool isCrafting;
  final bool isCancelling;
  final String? error;
  final String? selectedRecipeId;
  final int selectedBatchCount;
  final String selectedTab;

  factory CraftingState.initial() => const CraftingState(
        recipes: <CraftRecipe>[],
        queue: <CraftQueueItem>[],
        isLoading: false,
        isCrafting: false,
        isCancelling: false,
        selectedBatchCount: 1,
        selectedTab: 'tumu',
      );

  CraftingState copyWith({
    List<CraftRecipe>? recipes,
    List<CraftQueueItem>? queue,
    bool? isLoading,
    bool? isCrafting,
    bool? isCancelling,
    String? error,
    String? selectedRecipeId,
    int? selectedBatchCount,
    String? selectedTab,
    bool clearError = false,
    bool clearSelectedRecipe = false,
  }) {
    return CraftingState(
      recipes: recipes ?? this.recipes,
      queue: queue ?? this.queue,
      isLoading: isLoading ?? this.isLoading,
      isCrafting: isCrafting ?? this.isCrafting,
      isCancelling: isCancelling ?? this.isCancelling,
      error: clearError ? null : (error ?? this.error),
      selectedRecipeId:
          clearSelectedRecipe ? null : (selectedRecipeId ?? this.selectedRecipeId),
      selectedBatchCount: selectedBatchCount ?? this.selectedBatchCount,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

class CraftingNotifier extends Notifier<CraftingState> {
  @override
  CraftingState build() => CraftingState.initial();

  Future<void> loadRecipes(int playerLevel) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await SupabaseService.client
          .rpc('get_craft_recipes', params: <String, dynamic>{
        'p_user_level': playerLevel,
      });

      final List<CraftRecipe> recipes = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CraftRecipe.fromJson)
          .toList();

      state = state.copyWith(isLoading: false, recipes: recipes);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Tarifler yuklenirken bir hata olustu: ${e.toString()}',
      );
    }
  }

  Future<void> loadQueue() async {
    try {
      final response =
          await SupabaseService.client.rpc('get_craft_queue');

      final List<CraftQueueItem> queue = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CraftQueueItem.fromJson)
          .toList();

      state = state.copyWith(queue: queue);
    } catch (e) {
      state = state.copyWith(
        error: 'Uretim kuyrugu yuklenirken bir hata olustu: ${e.toString()}',
      );
    }
  }

  bool hasMaterials({
    required CraftRecipe recipe,
    required List<InventoryItem> inventoryItems,
    int batchCount = 1,
  }) {
    for (final ingredient in recipe.ingredients) {
      int available = 0;
      for (final item in inventoryItems) {
        if (item.itemId == ingredient.itemId) {
          available += item.quantity;
        }
      }
      if (available < ingredient.quantity * batchCount) {
        return false;
      }
    }
    return true;
  }

  Future<bool> craftItem({
    required String authId,
    required String recipeId,
    required int batchCount,
    required List<InventoryItem> inventoryItems,
  }) async {
    if (state.isCrafting) return false;
    if (state.queue.length >= craftingQueueLimit) {
      state = state.copyWith(
        error: 'Uretim kuyrugu dolu (maksimum $craftingQueueLimit).',
      );
      return false;
    }

    final int clampedBatch = batchCount.clamp(1, craftingBatchLimit);

    CraftRecipe? recipe;
    for (final r in state.recipes) {
      if (r.id == recipeId) {
        recipe = r;
        break;
      }
    }

    if (recipe == null) {
      state = state.copyWith(error: 'Tarif bulunamadi.');
      return false;
    }

    if (!hasMaterials(
      recipe: recipe,
      inventoryItems: inventoryItems,
      batchCount: clampedBatch,
    )) {
      state = state.copyWith(error: 'Yeterli malzeme yok.');
      return false;
    }

    // gem cost = max(0, batchCount - 1)
    final int gemCost = (clampedBatch - 1).clamp(0, craftingBatchLimit);

    state = state.copyWith(isCrafting: true, clearError: true);
    try {
      await SupabaseService.client
          .rpc('start_crafting', params: <String, dynamic>{
        'p_user_id': authId,
        'p_recipe_id': recipeId,
        'p_quantity': clampedBatch,
        'p_gem_cost': gemCost,
      });

      await loadQueue();
      state = state.copyWith(isCrafting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isCrafting: false,
        error: 'Uretim baslatilirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> finalizeCraftedItem(String queueItemId) async {
    try {
      await SupabaseService.client
          .rpc('finalize_crafted_item', params: <String, dynamic>{
        'p_queue_item_id': queueItemId,
      });

      await loadQueue();
      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Uretim sonuclandirilirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> claimItem(String queueItemId) async {
    try {
      await SupabaseService.client
          .rpc('claim_crafted_item', params: <String, dynamic>{
        'p_queue_item_id': queueItemId,
      });

      await loadQueue();
      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Urun alinirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> acknowledgeItem(String queueItemId) async {
    try {
      await SupabaseService.client
          .rpc('acknowledge_crafted_item', params: <String, dynamic>{
        'p_queue_item_id': queueItemId,
      });

      await loadQueue();
      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Urun onaylanirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> cancelItem(String queueItemId) async {
    if (state.isCancelling) return false;
    state = state.copyWith(isCancelling: true, clearError: true);
    try {
      await SupabaseService.client
          .rpc('cancel_craft_item', params: <String, dynamic>{
        'p_queue_item_id': queueItemId,
      });

      await loadQueue();
      state = state.copyWith(isCancelling: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isCancelling: false,
        error: 'Uretim iptal edilirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  void selectRecipe(String? recipeId) {
    if (recipeId == null) {
      state = state.copyWith(clearSelectedRecipe: true);
    } else {
      state = state.copyWith(selectedRecipeId: recipeId);
    }
  }

  void setBatchCount(int count) {
    state = state.copyWith(
      selectedBatchCount: count.clamp(1, craftingBatchLimit),
    );
  }

  void setSelectedTab(String tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clear() {
    state = CraftingState.initial();
  }
}

final NotifierProvider<CraftingNotifier, CraftingState> craftingProvider =
    NotifierProvider<CraftingNotifier, CraftingState>(CraftingNotifier.new);

// Convenience provider: watches inventory for hasMaterials checks
final Provider<bool Function(CraftRecipe, {int batchCount})>
    hasMaterialsProvider = Provider<bool Function(CraftRecipe, {int batchCount})>(
  (Ref ref) {
    final inventoryItems = ref.watch(inventoryProvider).items;
    final notifier = ref.read(craftingProvider.notifier);
    return (CraftRecipe recipe, {int batchCount = 1}) =>
        notifier.hasMaterials(
          recipe: recipe,
          inventoryItems: inventoryItems,
          batchCount: batchCount,
        );
  },
);
