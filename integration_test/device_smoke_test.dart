import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uparjon/core/media/video_player_playback.dart';
import 'package:uparjon/features/earn/presentation/widgets/task_overview_dialog.dart';

/// Checks that only a real device can answer.
///
/// Widget tests swap the player for a clock and render at a fixed surface
/// size, so neither the platform video pipeline nor the device's own text
/// metrics are ever exercised. Both are where the reported bugs lived.
///
///     flutter test integration_test -d <device-id>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// One of the sample URLs the staging ad feed serves. The bucket now
  /// answers 403 to anonymous callers, which is what the viewer hits.
  const deadUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  /// A reachable sample of the same shape.
  const liveUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  group('video playback on the device', () {
    testWidgets('plays a reachable video', (tester) async {
      final playback = VideoPlayerPlayback.network(Uri.parse(liveUrl));
      addTearDown(playback.dispose);

      await playback.initialize();
      await tester.pumpAndSettle();

      final state = playback.state.value;
      expect(state.error, isNull, reason: 'a reachable URL must load');
      expect(state.ready, isTrue);
      expect(state.duration, greaterThan(Duration.zero));
    });

    testWidgets('calls an access-denied ad unavailable, not offline', (
      tester,
    ) async {
      final playback = VideoPlayerPlayback.network(Uri.parse(deadUrl));
      addTearDown(playback.dispose);

      await playback.initialize();
      await tester.pumpAndSettle();

      final error = playback.state.value.error;
      expect(error, isNotNull, reason: 'a 403 URL cannot play');
      expect(error, 'This video is unavailable. Please try another ad.');
      // The device is plainly online — the previous copy sent the user off to
      // check a connection that was never the problem.
      expect(error, isNot(contains('connection')));
    });
  });

  group('overview popup on the device', () {
    testWidgets('keeps the close button out of the title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskOverviewDialog(child: SizedBox(height: 120)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.getRect(find.text('Overview'));
      final close = tester.getRect(find.byIcon(Icons.close));

      expect(title.overlaps(close), isFalse);
      expect(close.left, greaterThan(title.right));
    });
  });
}
