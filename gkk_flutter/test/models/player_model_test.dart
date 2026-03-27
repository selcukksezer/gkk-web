import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/player_model.dart';

void main() {
  test('PlayerProfile fromJson/toJson round-trip for required fields', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'id': 'p1',
      'auth_id': 'a1',
      'username': 'selcuk',
      'email': 's@example.com',
      'display_name': null,
      'avatar_url': null,
      'level': 10,
      'xp': 200,
      'gold': 500,
      'gems': 20,
      'energy': 70,
      'max_energy': 100,
      'attack': 15,
      'defense': 12,
      'health': 100,
      'max_health': 120,
      'power': 30,
      'is_online': true,
      'is_banned': false,
      'tutorial_completed': true,
      'guild_id': null,
      'guild_role': null,
      'referral_code': null,
      'referred_by': null,
      'pvp_rating': 1000,
      'pvp_wins': 11,
      'pvp_losses': 8,
      'addiction_level': 2,
      'tolerance': 5,
      'last_potion_used_at': null,
      'warrior_bloodlust_until': null,
      'hospital_until': null,
      'prison_until': null,
      'prison_reason': null,
      'global_suspicion_level': 0,
      'last_bribe_at': null,
      'last_login_at': null,
      'last_login': null,
      'created_at': '2026-03-27T00:00:00Z',
      'updated_at': '2026-03-27T00:00:00Z',
      'reputation': 1,
      'guild_name': null,
      'title': null,
      'endurance': 7,
      'agility': 8,
      'intelligence': 9,
      'luck': 10,
      'character_class': 'warrior',
      'hp': 88,
    };

    final PlayerProfile model = PlayerProfile.fromJson(json);
    expect(model.characterClass, CharacterClass.warrior);
    expect(model.toJson(), json);
  });

  test('PlayerStats fromJson/toJson works', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'totalPower': 120,
      'winRate': 0.75,
      'questsCompleted': 30,
      'dungeonClears': 6,
    };

    final PlayerStats model = PlayerStats.fromJson(json);
    expect(model.winRate, 0.75);
    expect(model.toJson(), json);
  });
}
