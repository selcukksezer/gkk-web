import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/item_model.dart';

void main() {
  test('ItemData fromJson/toJson round-trip', () {
    final Map<String, dynamic> source = <String, dynamic>{
      'item_id': 'itm_1',
      'name': 'Demir Kilic',
      'description': 'Baslangic silahi',
      'icon': 'sword_01',
      'item_type': 'weapon',
      'rarity': 'rare',
      'facility_type': null,
      'base_price': 120,
      'vendor_sell_price': 60,
      'attack': 10,
      'defense': 2,
      'health': 0,
      'power': 3,
      'luck': 1,
      'mana': 0,
      'equip_slot': 'weapon',
      'weapon_type': 'sword',
      'armor_type': 'none',
      'sub_type': 'sword',
      'required_level': 1,
      'can_enhance': true,
      'max_enhancement': 10,
      'enhancement_level': 2,
      'is_stackable': false,
      'max_stack': 1,
      'quantity': 1,
      'is_tradeable': true,
      'is_han_only': false,
      'is_market_tradeable': true,
      'is_direct_tradeable': true,
      'potion_type': 'none',
      'energy_restore': 0,
      'health_restore': 0,
      'mana_restore': 0,
      'tolerance_increase': 0,
      'overdose_risk': 0.0,
      'buff_duration': 0,
      'material_type': '',
      'production_building_type': '',
      'production_rate_per_hour': 0,
      'rune_enhancement_type': '',
      'rune_success_bonus': 0.0,
      'rune_destruction_reduction': 0.0,
      'cosmetic_effect': '',
      'cosmetic_bind_on_pickup': false,
    };

    final ItemData item = ItemData.fromJson(source);
    final Map<String, dynamic> encoded = item.toJson();

    expect(encoded, source);
    expect(isWeapon(item), isTrue);
    expect(isEquippable(item), isTrue);
    expect(getDisplayName(item.name, item.enhancementLevel), '+2 Demir Kilic');
    expect(getRarityHexColor(item.rarity), '#4D80FF');
    expect(getRarityLabel(item.rarity), 'Nadir');
  });
}
