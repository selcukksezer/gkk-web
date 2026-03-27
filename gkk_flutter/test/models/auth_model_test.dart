import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/auth_model.dart';

void main() {
  test('AuthResponse fromJson/toJson works', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'session': <String, dynamic>{
        'access_token': 'acc',
        'refresh_token': 'ref',
        'expires_at': 123,
      },
      'user': <String, dynamic>{
        'id': 'u1',
        'username': 'selcuk',
        'email': 'x@y.z',
        'level': 1,
        'gold': 100,
        'gems': 5,
        'energy': 50,
        'max_energy': 100,
        'attack': 10,
        'defense': 8,
        'health': 90,
        'max_health': 100,
        'power': 20,
        'guild_id': null,
        'guild_role': null,
      },
    };

    final AuthResponse parsed = AuthResponse.fromJson(payload);
    expect(parsed.user.username, 'selcuk');
    expect(parsed.session.expiresAt, 123);
    expect(parsed.toJson(), payload);
  });
}
