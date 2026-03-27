import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/errors/app_exception.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/repositories/inventory_repository.dart';

class FakeInventoryRepository implements InventoryRepository {
  FakeInventoryRepository({
    this.snapshot,
    this.error,
    this.equipResult = true,
    this.unequipResult = true,
  });

  final InventorySnapshot? snapshot;
  final AppException? error;
  final bool equipResult;
  final bool unequipResult;
  String? lastEquipRowId;
  String? lastEquipSlot;
  String? lastUnequipSlot;
  int? lastFromSlot;
  int? lastToSlot;

  @override
  Future<InventorySnapshot> fetchInventory() async {
    if (error != null) throw error!;
    if (snapshot != null) return snapshot!;
    throw AppException('No snapshot', code: 'NO_SNAPSHOT');
  }

  @override
  Future<bool> equipItem({required String rowId, required String slot}) async {
    if (error != null) throw error!;
    lastEquipRowId = rowId;
    lastEquipSlot = slot;
    return equipResult;
  }

  @override
  Future<bool> unequipItem({required String slot}) async {
    if (error != null) throw error!;
    lastUnequipSlot = slot;
    return unequipResult;
  }

  @override
  Future<bool> swapSlots({required int fromSlot, required int toSlot}) async {
    if (error != null) throw error!;
    lastFromSlot = fromSlot;
    lastToSlot = toSlot;
    return true;
  }
}

InventoryItem _item({
  required String rowId,
  required int slot,
  bool equipped = false,
}) {
  return InventoryItem(
    rowId: rowId,
    itemId: 'itm_$rowId',
    quantity: 1,
    slotPosition: slot,
    isEquipped: equipped,
    equippedSlot: equipped ? 'weapon' : '',
    enhancementLevel: 0,
    isFavorite: false,
    pendingSync: false,
    name: 'Item $rowId',
    description: 'desc',
    icon: 'icon',
    itemType: ItemType.weapon,
    rarity: Rarity.common,
    facilityType: null,
    basePrice: 10,
    vendorSellPrice: 5,
    attack: 1,
    defense: 1,
    health: 1,
    power: 1,
    luck: 1,
    mana: 1,
    equipSlot: EquipSlot.weapon,
    weaponType: WeaponType.sword,
    armorType: ArmorType.none,
    subType: SubType.sword,
    requiredLevel: 1,
    canEnhance: true,
    maxEnhancement: 10,
    isStackable: false,
    maxStack: 1,
    isTradeable: true,
    isHanOnly: false,
    isMarketTradeable: true,
    isDirectTradeable: true,
    potionType: PotionType.none,
    energyRestore: 0,
    healthRestore: 0,
    toleranceIncrease: 0,
  );
}

void main() {
  test('loadInventory sets ready and exposes helpers', () async {
    final snapshot = InventorySnapshot(
      items: <InventoryItem>[
        _item(rowId: '1', slot: 0),
        _item(rowId: '2', slot: 2),
      ],
      equippedItems: <String, InventoryItem?>{
        'weapon': _item(rowId: '3', slot: 0, equipped: true),
      },
    );

    final container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(
          FakeInventoryRepository(snapshot: snapshot),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(inventoryProvider.notifier).loadInventory();

    final state = container.read(inventoryProvider);
    expect(state.status, InventoryStatus.ready);
    expect(state.items.length, 2);
    expect(container.read(inventoryProvider.notifier).getItemBySlot(2)?.rowId, '2');
    expect(container.read(inventoryProvider.notifier).getEquippedItem('weapon')?.rowId, '3');
    expect(container.read(inventoryProvider.notifier).findFirstEmptySlot(), 1);
  });

  test('loadInventory sets error on AppException', () async {
    final container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(
          FakeInventoryRepository(
            error: AppException('Envanter yok', code: 'INVENTORY_FETCH_FAILED'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(inventoryProvider.notifier).loadInventory();

    final state = container.read(inventoryProvider);
    expect(state.status, InventoryStatus.error);
    expect(state.errorMessage, 'Envanter yok');
  });

  test('equipItem calls repository and refreshes inventory', () async {
    final fake = FakeInventoryRepository(
      snapshot: InventorySnapshot(
        items: <InventoryItem>[_item(rowId: '1', slot: 0)],
        equippedItems: const <String, InventoryItem?>{},
      ),
    );

    final container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(inventoryProvider.notifier).loadInventory();
    final ok = await container.read(inventoryProvider.notifier).equipItem(
          rowId: '1',
          slot: 'weapon',
        );

    expect(ok, isTrue);
    expect(fake.lastEquipRowId, '1');
    expect(fake.lastEquipSlot, 'weapon');
  });

  test('unequipItem calls repository and refreshes inventory', () async {
    final fake = FakeInventoryRepository(
      snapshot: InventorySnapshot(
        items: <InventoryItem>[_item(rowId: '1', slot: 0)],
        equippedItems: const <String, InventoryItem?>{},
      ),
    );

    final container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(inventoryProvider.notifier).loadInventory();
    final ok = await container.read(inventoryProvider.notifier).unequipItem(slot: 'weapon');

    expect(ok, isTrue);
    expect(fake.lastUnequipSlot, 'weapon');
  });

  test('swapSlots calls repository and refreshes inventory', () async {
    final fake = FakeInventoryRepository(
      snapshot: InventorySnapshot(
        items: <InventoryItem>[
          _item(rowId: '1', slot: 0),
          _item(rowId: '2', slot: 3),
        ],
        equippedItems: const <String, InventoryItem?>{},
      ),
    );

    final container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(inventoryProvider.notifier).loadInventory();
    final ok = await container.read(inventoryProvider.notifier).swapSlots(
          fromSlot: 0,
          toSlot: 3,
        );

    expect(ok, isTrue);
    expect(fake.lastFromSlot, 0);
    expect(fake.lastToSlot, 3);
  });
}
