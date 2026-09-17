// Verifies the DailyPostScreen keyboard-overflow fix: simulates the
// keyboard opening (MediaQuery.viewInsets.bottom > 0, exactly what
// Scaffold's resizeToAvoidBottomInset reacts to) on a small screen size,
// and asserts no RenderFlex overflow occurs and the Share button is still
// reachable.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cadence/features/community/screens/daily_post_screen.dart';

void main() {
  testWidgets('DailyPostScreen does not overflow when the keyboard is open',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            // A typical iOS/Android soft-keyboard height.
            data: MediaQueryData(
              size: Size(390, 640),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: DailyPostScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'expected no overflow/render exception with keyboard open');

    // The Share button must still be reachable (scrollable into view and
    // hit-testable), not pushed off past the bottom edge.
    final shareButton = find.widgetWithText(ElevatedButton, 'Share');
    await tester.scrollUntilVisible(shareButton, 100,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.getRect(shareButton).bottom,
        lessThanOrEqualTo(640 - 300 + 0.01),
        reason: 'Share button should be above the (simulated) keyboard');
    expect(tester.takeException(), isNull);
  });

  testWidgets('DailyPostScreen renders fine with keyboard closed too',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DailyPostScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(ElevatedButton, 'Share'), findsOneWidget);
  });
}
