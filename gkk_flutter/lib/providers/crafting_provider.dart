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

  bool _isStartCraftingSchemaDriftError(Object error) {
    final String msg = error.toString().toLowerCase();
    return msg.contains('42p01') ||
        msg.contains('42703') ||
        msg.contains('craft_recipes') ||
        msg.contains('column cr.name') ||
        msg.contains('column items.item_id');
  }

  bool _isQueueSchemaDriftError(Object error) {
    final String msg = error.toString().toLowerCase();
    return msg.contains('42703') ||
        msg.contains('42p01') ||
        msg.contains('column cr.name does not exist') ||
        msg.contains('column cr.output_quantity does not exist') ||
        msg.contains('relation "public.craft_recipes" does not exist');
  }

  Future<List<CraftQueueItem>> _loadQueueFromTableFallback() async {
    final String? authId = SupabaseService.client.auth.currentUser?.id;
    if (authId == null || authId.isEmpty) return <CraftQueueItem>[];

    final dynamic rows = await SupabaseService.client
        .from('craft_queue')
        .select(
          'id,recipe_id,batch_count,started_at,completes_at,is_completed,claimed,failed,crafting_recipes(output_item_id,xp_reward)',
        )
        .eq('user_id', authId)
        .order('started_at', ascending: false);

    final List<Map<String, dynamic>> queueRows = (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    final Set<String> outputItemIds = <String>{};
    for (final row in queueRows) {
      final dynamic recipeRaw = row['crafting_recipes'];
      final Map<String, dynamic> recipe = recipeRaw is Map<String, dynamic>
          ? recipeRaw
          : <String, dynamic>{};
      final String outputItemId = (recipe['output_item_id'] ?? '').toString();
      if (outputItemId.isNotEmpty) {
        outputItemIds.add(outputItemId);
      }
    }

    final Map<String, String> itemNameById = <String, String>{};
    final Map<String, String> itemIconById = <String, String>{};

    if (outputItemIds.isNotEmpty) {
      final dynamic itemRows = await SupabaseService.client
          .from('items')
          .select('id,name,icon')
          .inFilter('id', outputItemIds.toList());

      for (final dynamic item in (itemRows as List<dynamic>)) {
        if (item is! Map) continue;
        final String id = (item['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final String name = (item['name'] ?? '').toString();
        final String icon = (item['icon'] ?? '').toString();
        if (name.isNotEmpty) itemNameById[id] = name;
        if (icon.isNotEmpty) itemIconById[id] = icon;
      }
    }

    final DateTime now = DateTime.now().toUtc();

    return queueRows.map((row) {
      final dynamic recipeRaw = row['crafting_recipes'];
      final Map<String, dynamic> recipe = recipeRaw is Map<String, dynamic>
          ? recipeRaw
          : <String, dynamic>{};

      final String outputItemId = (recipe['output_item_id'] ?? '').toString();
      final int xpReward = (recipe['xp_reward'] as num?)?.toInt() ?? 0;
      final String recipeName = itemNameById[outputItemId] ?? outputItemId;
      final String recipeIcon = itemIconById[outputItemId] ?? '';

      final DateTime? completesAt = DateTime.tryParse(
        (row['completes_at'] ?? '').toString(),
      )?.toUtc();
      final bool completedByTime =
          completesAt != null && !completesAt.isAfter(now);

      return CraftQueueItem.fromJson(<String, dynamic>{
        'id': row['id'],
        'recipe_id': row['recipe_id'],
        'recipe_name': recipeName,
        'recipe_icon': recipeIcon,
        'batch_count': row['batch_count'] ?? 1,
        'started_at': row['started_at'],
        'completes_at': row['completes_at'],
        'is_completed': row['is_completed'] == true || completedByTime,
        'claimed': row['claimed'] == true,
        'failed': row['failed'] == true,
        'xp_reward': xpReward,
        'output_item_id': outputItemId,
        'output_quantity': 1,
        'output_name': itemNameById[outputItemId] ?? outputItemId,
      });
    }).toList(growable: false);
  }

  bool _craftItemAsyncSucceeded(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final dynamic first = response.first;
      if (first is Map) {
        return first['success'] == true;
      }
    }
    if (response is Map) {
      return response['success'] == true;
    }
    return false;
  }

  bool? _readRpcSuccess(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final dynamic first = response.first;
      if (first is Map && first['success'] is bool) {
        return first['success'] as bool;
      }
    }
    if (response is Map && response['success'] is bool) {
      return response['success'] as bool;
    }
    if (response is bool) {
      return response;
    }
    return null;
  }

  String? _readRpcMessage(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final dynamic first = response.first;
      if (first is Map) {
        final dynamic message = first['message'] ?? first['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
    }
    if (response is Map) {
      final dynamic message = response['message'] ?? response['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }
    return null;
  }

  String? _craftItemAsyncMessage(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final dynamic first = response.first;
      if (first is Map && first['message'] != null) {
        return first['message'].toString();
      }
    }
    if (response is Map && response['message'] != null) {
      return response['message'].toString();
    }
    return null;
  }

  Future<List<CraftRecipe>> _hydrateMissingIngredientNames(
    List<CraftRecipe> recipes,
  ) async {
    try {
      final Set<String> missingItemIds = <String>{};
      for (final recipe in recipes) {
        for (final ing in recipe.ingredients) {
          if (ing.itemId.isNotEmpty && ing.itemName.trim().isEmpty) {
            missingItemIds.add(ing.itemId);
          }
        }
      }

      if (missingItemIds.isEmpty) return recipes;

      final dynamic rows = await SupabaseService.client
          .from('items')
          .select('id,name')
          .inFilter('id', missingItemIds.toList());

      final Map<String, String> nameByItemId = <String, String>{};
      if (rows is List) {
        for (final row in rows) {
          if (row is! Map) continue;
          final String itemId = (row['id'] ?? '').toString();
          final String name = (row['name'] ?? '').toString().trim();
          if (itemId.isNotEmpty && name.isNotEmpty) {
            nameByItemId[itemId] = name;
          }
        }
      }

      if (nameByItemId.isEmpty) return recipes;

      return recipes.map((recipe) {
        bool changed = false;
        final List<CraftIngredient> hydratedIngredients = recipe.ingredients.map((ing) {
          final String currentName = ing.itemName.trim();
          if (currentName.isNotEmpty) return ing;

          final String fallbackName = nameByItemId[ing.itemId]?.trim() ?? '';
          if (fallbackName.isEmpty) return ing;

          changed = true;
          return CraftIngredient(
            itemId: ing.itemId,
            itemName: fallbackName,
            quantity: ing.quantity,
          );
        }).toList(growable: false);

        if (!changed) return recipe;

        return CraftRecipe(
          id: recipe.id,
          recipeId: recipe.recipeId,
          name: recipe.name,
          outputName: recipe.outputName,
          description: recipe.description,
          recipeType: recipe.recipeType,
          itemType: recipe.itemType,
          outputItemId: recipe.outputItemId,
          outputQuantity: recipe.outputQuantity,
          outputRarity: recipe.outputRarity,
          requiredLevel: recipe.requiredLevel,
          requiredFacility: recipe.requiredFacility,
          requiredFacilityLevel: recipe.requiredFacilityLevel,
          productionTimeSeconds: recipe.productionTimeSeconds,
          successRate: recipe.successRate,
          ingredients: hydratedIngredients,
          gemCost: recipe.gemCost,
          goldCost: recipe.goldCost,
          xpReward: recipe.xpReward,
        );
      }).toList(growable: false);
    } catch (_) {
      // Name hydration is optional; recipe loading must not fail because of this step.
      return recipes;
    }
  }

  Future<void> loadRecipes(int playerLevel) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await SupabaseService.client
          .rpc('get_craft_recipes', params: <String, dynamic>{
        'p_user_level': playerLevel,
      });

        final dynamic rows = response is Map<String, dynamic>
          ? (response['data'] ?? const <dynamic>[])
          : response;

        final List<CraftRecipe> recipes = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CraftRecipe.fromJson)
          .toList();

      final List<CraftRecipe> hydratedRecipes =
          await _hydrateMissingIngredientNames(recipes);

      state = state.copyWith(isLoading: false, recipes: hydratedRecipes);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Tarifler yuklenirken bir hata olustu: ${e.toString()}',
      );
    }
  }

  Future<void> loadQueue() async {
    try {
      final dynamic response = await SupabaseService.client.rpc('get_craft_queue');

      final dynamic rows = response is Map<String, dynamic>
        ? (response['data'] ?? const <dynamic>[])
        : response;

      final List<CraftQueueItem> queue = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CraftQueueItem.fromJson)
          .toList();

      state = state.copyWith(queue: queue);
    } catch (e) {
      if (_isQueueSchemaDriftError(e)) {
        try {
          final List<CraftQueueItem> fallbackQueue =
              await _loadQueueFromTableFallback();
          state = state.copyWith(queue: fallbackQueue, clearError: true);
          return;
        } catch (_) {
          // Fall through to normal error assignment below.
        }
      }
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

    state = state.copyWith(isCrafting: true, clearError: true);
    try {
      try {
        final dynamic startResponse = await SupabaseService.client
            .rpc('start_crafting', params: <String, dynamic>{
          'p_user_id': authId,
          'p_recipe_id': recipeId,
          'p_quantity': clampedBatch,
        });

        final bool? startSuccess = _readRpcSuccess(startResponse);
        if (startSuccess == false) {
          state = state.copyWith(
            isCrafting: false,
            error: _readRpcMessage(startResponse) ?? 'Uretim baslatilamadi.',
          );
          return false;
        }
      } catch (startErr) {
        if (!_isStartCraftingSchemaDriftError(startErr)) {
          rethrow;
        }

        final dynamic fallbackResponse = await SupabaseService.client
            .rpc('craft_item_async', params: <String, dynamic>{
          'p_recipe_id': recipeId,
          'p_batch_count': clampedBatch,
        });

        if (!_craftItemAsyncSucceeded(fallbackResponse)) {
          final String fallbackMessage =
              _craftItemAsyncMessage(fallbackResponse) ??
              'Uretim baslatilamadi (fallback).';
          state = state.copyWith(
            isCrafting: false,
            error: fallbackMessage,
          );
          return false;
        }
      }

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
      final dynamic response = await SupabaseService.client
          .rpc('claim_crafted_item', params: <String, dynamic>{
        'p_queue_item_id': queueItemId,
      });

      final bool? success = _readRpcSuccess(response);
      if (success == false) {
        await loadQueue();
        state = state.copyWith(
          error: _readRpcMessage(response) ?? 'Urun alinamadi.',
        );
        return false;
      }

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
      final dynamic response = await SupabaseService.client
          .rpc('acknowledge_crafted_item', params: <String, dynamic>{
        'p_queue_item_id': queueItemId,
      });

      final bool? success = _readRpcSuccess(response);
      if (success == false) {
        state = state.copyWith(
          error: _readRpcMessage(response) ?? 'Kuyruk ogesi kaldirilamadi.',
        );
        return false;
      }

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
      final dynamic response = await SupabaseService.client
          .rpc('cancel_craft_item', params: <String, dynamic>{
        'p_queue_item_id': queueItemId,
      });

      final bool? success = _readRpcSuccess(response);
      if (success == false) {
        state = state.copyWith(
          isCancelling: false,
          error: _readRpcMessage(response) ?? 'Uretim iptal edilemedi.',
        );
        return false;
      }

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
