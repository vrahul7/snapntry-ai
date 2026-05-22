import 'package:flutter_test/flutter_test.dart';

import 'package:b2b_gena2z/app.dart';

void main() {
  testWidgets('SnapnTry AI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SnapnTryApp());

    // Verify that login page is shown.
    expect(find.text('SnapnTry AI'), findsOneWidget);
    expect(find.text('Enter Partner Portal'), findsOneWidget);
  });
}

