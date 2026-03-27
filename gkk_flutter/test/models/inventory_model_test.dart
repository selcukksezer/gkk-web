import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/inventory_model.dart';

void main() {
  test('InventoryItem fromJson/toJson round-trip', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'row_id': 'row_1',
      'item_id': 'itm_1',
      'quantity': 2,
      'slot_position': 5,
      'is_equipped': false,
      'equipped_slot': '',
      'enhancement_level': 1,
      'is_favorite': true,
      'pending_sync': false,
      'name': 'Demir Kilic',
      'description': 'Baslangic',
      'icon': 'icon_1',
      'item_type': 'weapon',
      'rarity': 'common',
      'facility_type': null,
      'base_price': 100,
      'vendor_sell_price': 50,
      'attack': 1,
      'defense': 2,
      'health': 3,
      'power': 4,
      'luck': 5,
      'mana': 6,
      'equip_slot': 'weapon',
      'weapon_type': 'sword',
      'armor_type': 'none',
      'sub_type': 'sword',
      'required_level': 1,
      'can_enhance': true,
      'max_enhancement': 10,
      'is_stackable': false,
      'max_stack': 1,
      'is_tradeable': true,
      'is_han_only': false,
      'is_market_tradeable': true,
      'is_direct_tradeable': true,
      'potion_type': 'none',
      'energy_restore': 0,
      'health_restore': 0,
      'tolerance_increase': 0,
    };

    final InventoryItem model = InventoryItem.fromJson(json);
    expect(model.rowId, 'row_1');
    expect(model.toJson(), json);
    expect(inventoryCapacity, 20);
  });
}
