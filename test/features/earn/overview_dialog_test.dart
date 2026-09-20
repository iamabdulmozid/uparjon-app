import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/features/earn/presentation/widgets/task_overview_dialog.dart';

import '../../support/pump_app.dart';

/// The overview popup's header is a [Stack]: a centred title with the close
/// button pinned to the right. A [Stack] under loose constraints shrink-wraps
/// its largest non-positioned child, so without an explicit width the header
/// collapsed to the width of the word "Overview" and the close button was
/// drawn on top of the title.
void main() {
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaskOverviewDialog(child: SizedBox(height: 120)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TaskOverviewDialog header', () {
    testWidgets('keeps the close button clear of the title', (tester) async {
      await pumpDialog(tester);

      final title = tester.getRect(find.text('Overview'));
      final close = tester.getRect(find.byIcon(Icons.close));

      expect(
        title.overlaps(close),
        isFalse,
        reason: 'the close button must not sit on top of the title',
      );
      expect(close.left, greaterThan(title.right));
    });

    testWidgets('pins the close button to the dialog edge', (tester) async {
      await pumpDialog(tester);

      final title = tester.getRect(find.text('Overview'));
      final close = tester.getRect(find.byIcon(Icons.close));

      // A collapsed header puts the button a few pixels past the text. At the
      // dialog's edge the gap is most of the popup's width.
      expect(close.left - title.right, greaterThan(50));

      // ...and the title stays centred on the dialog, not pushed aside.
      expect(title.center.dx, closeTo(kDesignSize.width / 2, 1));
    });
  });
}
