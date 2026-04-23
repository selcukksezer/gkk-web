import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/inventory_model.dart';

class InventorySnapshot {
  const InventorySnapshot({
    required this.items,
    required this.equippedItems,
  });

  final List<InventoryItem> items;
  final Map<String, InventoryItem?> equippedItems;
}

class SellItemResult {
  const SellItemResult({
    required this.success,
    this.goldEarned = 0,
    this.error,
  });

  final bool success;
  final int goldEarned;
  final String? error;
}

abstract class InventoryRepository {
  Future<InventorySnapshot> fetchInventory();
  Future<bool> addItemToServer({required String itemId, required int quantity, int? slotPosition});
  Future<bool> equipItem({required String rowId, required String slot});
  Future<bool> unequipItem({required String slot});
  Future<bool> swapSlots({required int fromSlot, required int toSlot});
  Future<bool> moveItemToSlot({required String rowId, required int targetSlot});
  Future<bool> unequipItemToSlot({required String rowId, required String slot, required int targetSlot});
  Future<bool> swapEquipWithSlot({required String equipSlot, required int targetSlot});
  Future<bool> usePotion({required String rowId});
  Future<bool> useDetox({required String rowId});
  Future<bool> splitStack({required String rowId, required int splitQuantity, required int targetSlot});
  Future<SellItemResult> sellItemByRow({required String rowId, required int quantity});
  Future<bool> trashItem({required String rowId});
  Future<bool> toggleFavorite({required String rowId, required bool isFavorite});
}

class SupabaseInventoryRepository implements InventoryRepository {
  @override
  Future<bool> addItemToServer({required String itemId, required int quantity, int? slotPosition}) async {
    if (quantity <= 0) {
      // DB check constraint (inventory_quantity_check) requires quantity > 0.
      // Zero/negative deltas are treated as no-op on client.
      return true;
    }

    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('add_inventory_item_v2', params: <String, dynamic>{
        'item_data': <String, dynamic>{
          'item_id': itemId,
          'quantity': quantity,
        },
        'p_slot_position': slotPosition,
      });
      return true;
    } catch (_) {
      throw AppException('Oge envantere eklenemedi.', code: 'INVENTORY_ADD_ITEM_FAILED');
    }
  }

  @override
  Future<InventorySnapshot> fetchInventory() async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      final dynamic inventoryPayload = await SupabaseService.client.rpc('get_inventory');
      dynamic equippedPayload;
      try {
        equippedPayload = await SupabaseService.client.rpc('get_equipped_items');
      } catch (_) {
        // Eski DB migration durumlarinda equipped RPC olmayabilir; bu durumda ana envanteri gostermeye devam ederiz.
        equippedPayload = null;
      }

      final List<InventoryItem> rawItems = _extractItems(inventoryPayload);
      final List<InventoryItem> equippedRows = _extractItems(equippedPayload, assumeEquipped: true);

      final Map<String, InventoryItem?> equipped = <String, InventoryItem?>{};
      for (final item in equippedRows) {
        final String rawSlot = item.equipSlot.name != 'none'
            ? item.equipSlot.name
            : item.equippedSlot;
        if (rawSlot.isEmpty) continue;
        equipped[rawSlot.toLowerCase()] = item.copyWith(isEquipped: true);
      }

      final Set<String> equippedRowIds = equippedRows.map((e) => e.rowId).toSet();
      final List<InventoryItem> filtered = rawItems
          .where((item) => !item.isEquipped)
          .where((item) => !equippedRowIds.contains(item.rowId))
          .toList();

      return InventorySnapshot(
        items: _ensureSlotPositions(filtered),
        equippedItems: equipped,
      );
    } catch (_) {
      throw AppException('Envanter yuklenemedi.', code: 'INVENTORY_FETCH_FAILED');
    }
  }

  @override
  Future<bool> equipItem({required String rowId, required String slot}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('equip_item', params: <String, dynamic>{
        'p_row_id': rowId,
        'p_slot': slot.toLowerCase(),
      });
      return true;
    } catch (_) {
      throw AppException('Kusanma islemi basarisiz.', code: 'INVENTORY_EQUIP_FAILED');
    }
  }

  @override
  Future<bool> unequipItem({required String slot}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('unequip_item', params: <String, dynamic>{
        'p_slot': slot.toLowerCase(),
      });
      return true;
    } catch (_) {
      throw AppException('Kusani cikarma islemi basarisiz.', code: 'INVENTORY_UNEQUIP_FAILED');
    }
  }

  @override
  Future<bool> swapSlots({required int fromSlot, required int toSlot}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      final dynamic response = await SupabaseService.client.rpc(
        'swap_slots',
        params: <String, dynamic>{
          'p_from_slot': fromSlot,
          'p_to_slot': toSlot,
        },
      );

      if (response is Map) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response);
        final dynamic successValue = data['success'];
        if (successValue is bool && successValue == false) {
          throw AppException(
            (data['error'] as String?) ?? 'Slot degistirme islemi basarisiz.',
            code: 'INVENTORY_SWAP_FAILED',
          );
        }
      }
      return true;
    } catch (e) {
      final bool fallback = await _swapSlotsFallback(fromSlot: fromSlot, toSlot: toSlot);
      if (fallback) return true;
      if (e is AppException) rethrow;
      throw AppException('Slot degistirme islemi basarisiz.', code: 'INVENTORY_SWAP_FAILED');
    }
  }

  @override
  Future<bool> moveItemToSlot({required String rowId, required int targetSlot}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('update_item_positions', params: <String, dynamic>{
        'p_updates': <Map<String, dynamic>>[
          <String, dynamic>{'row_id': rowId, 'slot_position': targetSlot},
        ],
      });
      return true;
    } catch (_) {
      throw AppException('Item tasima basarisiz.', code: 'INVENTORY_MOVE_FAILED');
    }
  }

  @override
  Future<bool> unequipItemToSlot({required String rowId, required String slot, required int targetSlot}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('unequip_item', params: <String, dynamic>{
        'p_slot': slot.toLowerCase(),
      });
      await SupabaseService.client.rpc('update_item_positions', params: <String, dynamic>{
        'p_updates': <Map<String, dynamic>>[
          <String, dynamic>{'row_id': rowId, 'slot_position': targetSlot},
        ],
      });
      return true;
    } catch (_) {
      throw AppException('Kusani hedef slota birakma basarisiz.', code: 'INVENTORY_UNEQUIP_TO_SLOT_FAILED');
    }
  }

  @override
  Future<bool> swapEquipWithSlot({required String equipSlot, required int targetSlot}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('swap_equip_with_slot', params: <String, dynamic>{
        'p_equip_slot': equipSlot.toLowerCase(),
        'p_target_slot': targetSlot,
      });
      return true;
    } catch (_) {
      throw AppException('Kusanilan item swap basarisiz.', code: 'INVENTORY_SWAP_EQUIP_FAILED');
    }
  }

  @override
  Future<bool> usePotion({required String rowId}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('use_potion', params: <String, dynamic>{
        'p_row_id': rowId,
      });
      return true;
    } catch (_) {
      throw AppException('Iksir kullanimi basarisiz.', code: 'INVENTORY_USE_POTION_FAILED');
    }
  }

  @override
  Future<bool> useDetox({required String rowId}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('use_detox', params: <String, dynamic>{
        'p_row_id': rowId,
      });
      return true;
    } catch (_) {
      throw AppException('Detox kullanimi basarisiz.', code: 'INVENTORY_USE_DETOX_FAILED');
    }
  }

  @override
  Future<bool> splitStack({required String rowId, required int splitQuantity, required int targetSlot}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('split_stack_item', params: <String, dynamic>{
        'p_row_id': rowId,
        'p_split_quantity': splitQuantity,
        'p_target_slot': targetSlot,
      });
      return true;
    } catch (_) {
      throw AppException('Stack bolme basarisiz.', code: 'INVENTORY_SPLIT_FAILED');
    }
  }

  @override
  Future<SellItemResult> sellItemByRow({required String rowId, required int quantity}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      final dynamic response = await SupabaseService.client.rpc(
        'sell_inventory_item_by_row',
        params: <String, dynamic>{
          'p_row_id': rowId,
          'p_quantity': quantity,
        },
      );

      if (response is Map) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response);
        final bool success = data['success'] != false;
        if (!success) {
          return SellItemResult(
            success: false,
            error: (data['error'] as String?) ?? 'Satis basarisiz.',
          );
        }

        return SellItemResult(
          success: true,
          goldEarned: _asInt(data['gold_earned']),
        );
      }

      return const SellItemResult(success: true, goldEarned: 0);
    } catch (_) {
      throw AppException('Satis islemi basarisiz.', code: 'INVENTORY_SELL_FAILED');
    }
  }

  @override
  Future<bool> trashItem({required String rowId}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('trash_item', params: <String, dynamic>{
        'p_row_id': rowId,
      });
      return true;
    } catch (_) {
      throw AppException('Item silme basarisiz.', code: 'INVENTORY_TRASH_FAILED');
    }
  }

  @override
  Future<bool> toggleFavorite({required String rowId, required bool isFavorite}) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    try {
      await SupabaseService.client.rpc('toggle_item_favorite', params: <String, dynamic>{
        'p_row_id': rowId,
        'p_is_favorite': isFavorite,
      });
      return true;
    } catch (_) {
      throw AppException('Favori islemi basarisiz.', code: 'INVENTORY_FAVORITE_FAILED');
    }
  }

  List<InventoryItem> _extractItems(dynamic payload, {bool assumeEquipped = false}) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((row) => _safeParseItem(Map<String, dynamic>.from(row), assumeEquipped: assumeEquipped))
          .whereType<InventoryItem>()
          .toList();
    }

    if (payload is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(payload);

      final dynamic directItems = map['items'];
      if (directItems is List) {
        return directItems
            .whereType<Map>()
        .map((row) => _safeParseItem(Map<String, dynamic>.from(row), assumeEquipped: assumeEquipped))
        .whereType<InventoryItem>()
            .toList();
      }

      final dynamic nested = map['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
        .map((row) => _safeParseItem(Map<String, dynamic>.from(row), assumeEquipped: assumeEquipped))
        .whereType<InventoryItem>()
            .toList();
      }

      if (nested is Map) {
        final dynamic nestedItems = nested['items'];
        if (nestedItems is List) {
          return nestedItems
              .whereType<Map>()
              .map((row) => _safeParseItem(Map<String, dynamic>.from(row), assumeEquipped: assumeEquipped))
              .whereType<InventoryItem>()
              .toList();
        }
      }
    }

    return <InventoryItem>[];
  }

  InventoryItem? _safeParseItem(Map<String, dynamic> row, {required bool assumeEquipped}) {
    try {
      final Map<String, dynamic> normalized = _normalizeItemRow(row, assumeEquipped: assumeEquipped);
      return InventoryItem.fromJson(normalized);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalizeItemRow(Map<String, dynamic> row, {required bool assumeEquipped}) {
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(row);

    normalized['row_id'] = (normalized['row_id'] ?? normalized['id'] ?? '').toString();
    normalized['item_id'] = (normalized['item_id'] ?? '').toString();
    normalized['quantity'] = _asInt(normalized['quantity'], fallback: 1);
    normalized['slot_position'] = _asInt(normalized['slot_position'], fallback: -1);
    normalized['is_equipped'] = _asBool(normalized['is_equipped'], fallback: assumeEquipped);
    normalized['equipped_slot'] =
        (normalized['equipped_slot'] ?? normalized['equip_slot'] ?? '').toString();
    normalized['enhancement_level'] = _asInt(normalized['enhancement_level']);
    normalized['is_favorite'] = _asBool(normalized['is_favorite']);
    normalized['pending_sync'] = _asBool(normalized['pending_sync']);
    normalized['name'] = (normalized['name'] ?? 'Unknown Item').toString();
    normalized['description'] = (normalized['description'] ?? '').toString();
    normalized['icon'] = (normalized['icon'] ?? '').toString();
    normalized['item_type'] = (normalized['item_type'] ?? normalized['type'] ?? 'material').toString();
    normalized['rarity'] = (normalized['rarity'] ?? 'common').toString();
    normalized['facility_type'] = normalized['facility_type']?.toString();
    normalized['base_price'] = _asInt(normalized['base_price']);
    normalized['vendor_sell_price'] = _asInt(normalized['vendor_sell_price']);
    normalized['attack'] = _asInt(normalized['attack']);
    normalized['defense'] = _asInt(normalized['defense']);
    normalized['health'] = _asInt(normalized['health']);
    normalized['power'] = _asInt(normalized['power']);
    normalized['luck'] = _asInt(normalized['luck']);
    normalized['mana'] = _asInt(normalized['mana']);
    normalized['equip_slot'] = (normalized['equip_slot'] ?? normalized['equipped_slot'] ?? 'none').toString();
    normalized['weapon_type'] = (normalized['weapon_type'] ?? 'none').toString();
    normalized['armor_type'] = (normalized['armor_type'] ?? 'none').toString();
    normalized['sub_type'] = normalized['sub_type']?.toString();
    normalized['required_level'] = _asInt(normalized['required_level'], fallback: 1);
    normalized['can_enhance'] = _asBool(normalized['can_enhance']);
    normalized['max_enhancement'] = _asInt(normalized['max_enhancement']);
    normalized['is_stackable'] = _asBool(normalized['is_stackable']);
    normalized['max_stack'] = _asInt(normalized['max_stack'], fallback: 1);
    normalized['is_tradeable'] = _asBool(normalized['is_tradeable'], fallback: true);
    normalized['is_han_only'] = normalized['is_han_only'] == null ? null : _asBool(normalized['is_han_only']);
    normalized['is_market_tradeable'] = normalized['is_market_tradeable'] == null
        ? null
        : _asBool(normalized['is_market_tradeable']);
    normalized['is_direct_tradeable'] = normalized['is_direct_tradeable'] == null
        ? null
        : _asBool(normalized['is_direct_tradeable']);
    normalized['potion_type'] = (normalized['potion_type'] ?? 'none').toString();
    normalized['energy_restore'] = _asInt(normalized['energy_restore']);
    normalized['health_restore'] = _asInt(normalized['health_restore']);
    normalized['tolerance_increase'] = _asInt(normalized['tolerance_increase']);

    return normalized;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String lower = value.toLowerCase();
      if (lower == 'true' || lower == 't' || lower == '1') return true;
      if (lower == 'false' || lower == 'f' || lower == '0') return false;
    }
    return fallback;
  }

  Future<bool> _swapSlotsFallback({required int fromSlot, required int toSlot}) async {
    try {
      final dynamic inventoryPayload = await SupabaseService.client.rpc('get_inventory');
      final List<InventoryItem> items = _extractItems(inventoryPayload);
      final InventoryItem? fromItem = items.where((it) => it.slotPosition == fromSlot).cast<InventoryItem?>().firstWhere(
            (it) => it != null,
            orElse: () => null,
          );
      final InventoryItem? toItem = items.where((it) => it.slotPosition == toSlot).cast<InventoryItem?>().firstWhere(
            (it) => it != null,
            orElse: () => null,
          );

      final List<Map<String, dynamic>> updates = <Map<String, dynamic>>[];
      if (fromItem != null) {
        updates.add(<String, dynamic>{'row_id': fromItem.rowId, 'slot_position': toSlot});
      }
      if (toItem != null) {
        updates.add(<String, dynamic>{'row_id': toItem.rowId, 'slot_position': fromSlot});
      }

      if (updates.isEmpty) return false;

      await SupabaseService.client.rpc('update_item_positions', params: <String, dynamic>{
        'p_updates': updates,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  List<InventoryItem> _ensureSlotPositions(List<InventoryItem> items) {
    final Set<int> used = <int>{};
    final List<InventoryItem> normalized = <InventoryItem>[];

    for (final item in items) {
      int slot = item.slotPosition;
      if (slot >= 0 && slot < inventoryCapacity && !used.contains(slot)) {
        used.add(slot);
        normalized.add(item.copyWith(slotPosition: slot));
      } else {
        final int nextFree = _findFirstEmptySlot(used);
        if (nextFree >= 0) {
          used.add(nextFree);
          normalized.add(item.copyWith(slotPosition: nextFree));
        }
      }
    }

    normalized.sort((a, b) => a.slotPosition.compareTo(b.slotPosition));
    return normalized;
  }

  int _findFirstEmptySlot(Set<int> used) {
    for (int i = 0; i < inventoryCapacity; i++) {
      if (!used.contains(i)) return i;
    }
    return -1;
  }
}
