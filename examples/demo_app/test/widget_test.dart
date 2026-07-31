// Smoke test for the Mosaic demo app shell.
//
// Replaces the stock `flutter create` counter test, which asserted a counter UI
// this app never had and so always failed.

import 'package:flutter_test/flutter_test.dart';

import 'package:demo_app/main.dart';

void main() {
  testWidgets('dashboard renders its title and heading',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // The sync button is behind `_isLoading`, so assert on the static chrome
    // that is present on the first frame regardless of fetch state.
    expect(find.text('Home Widget Dashboard'), findsOneWidget);
    expect(find.text('Premium Widget Dashboard'), findsOneWidget);
  });
}
