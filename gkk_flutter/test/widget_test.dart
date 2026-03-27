import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/main.dart';

void main() {
  testWidgets('App routes from splash to login', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GkkMobileApp()));

    await tester.pumpAndSettle();

    expect(find.text('E-posta'), findsOneWidget);
  });
}
