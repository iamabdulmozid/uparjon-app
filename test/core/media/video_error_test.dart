import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/core/media/video_player_playback.dart';

/// The ad feed hands the player whatever URL the advertiser configured, and a
/// dead or access-denied URL is not the viewer's network. Telling them to
/// "check your connection" sends them chasing a problem they cannot fix.
void main() {
  group('VideoPlayerPlayback.describeError', () {
    test('calls an access-denied source unavailable, not a network fault', () {
      const raw =
          'PlatformException(VideoError, Video player had error '
          'androidx.media3.exoplayer.ExoPlaybackException: Source error, '
          'InvalidResponseCodeException: Response code: 403, null)';

      expect(
        VideoPlayerPlayback.describeError(raw),
        'This video is unavailable. Please try another ad.',
      );
    });

    test('treats a missing file the same way', () {
      expect(
        VideoPlayerPlayback.describeError('Response code: 404'),
        'This video is unavailable. Please try another ad.',
      );
    });

    test('still blames the connection when nothing says otherwise', () {
      expect(
        VideoPlayerPlayback.describeError('Connection reset by peer'),
        'Could not load this video. Check your connection and retry.',
      );
      expect(
        VideoPlayerPlayback.describeError(null),
        'Could not load this video. Check your connection and retry.',
      );
    });

    test('never leaks raw player text to the screen', () {
      const raw = 'UnrecognizedInputFormatException: None of the available '
          'extractors could read the stream.';

      expect(VideoPlayerPlayback.describeError(raw), isNot(contains(raw)));
      expect(
        VideoPlayerPlayback.describeError(raw),
        'This video is unavailable. Please try another ad.',
      );
    });
  });
}
