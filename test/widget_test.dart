import 'package:flutter_test/flutter_test.dart';

import 'package:b2b_gena2z/app.dart';

void main() {
  testWidgets('GenA2Z B2B Portal smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GenA2ZApp());

    // Verify that login page is shown.
    expect(find.text('GenA2Z B2B Portal'), findsOneWidget);
    expect(find.text('Enter Partner Portal'), findsOneWidget);
  });
}

