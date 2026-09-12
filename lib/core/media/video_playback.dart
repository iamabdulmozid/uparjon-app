import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'video_player_playback.dart';

/// Snapshot of a playback session, published through [VideoPlayback.state].
@immutable
class VideoPlaybackState {
  const VideoPlaybackState({
    this.ready = false,
    this.playing = false,
    this.completed = false,
    this.muted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.aspectRatio = 16 / 9,
    this.error,
  });

  /// The media has loaded and can be played.
  final bool ready;
  final bool playing;

  /// Playback reached the end at least once. Sticky: a later seek does not
  /// clear it, because the ad flow rewards the first full watch.
  final bool completed;
  final bool muted;
  final Duration position;
  final Duration duration;
  final double aspectRatio;

  /// Why the media could not be loaded or played, if it could not.
  final String? error;

  /// 0..1 progress through the media, or 0 while the length is unknown.
  double get progress => duration <= Duration.zero
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  VideoPlaybackState copyWith({
    bool? ready,
    bool? playing,
    bool? completed,
    bool? muted,
    Duration? position,
    Duration? duration,
    double? aspectRatio,
    String? error,
  }) => VideoPlaybackState(
    ready: ready ?? this.ready,
    playing: playing ?? this.playing,
    completed: completed ?? this.completed,
    muted: muted ?? this.muted,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    error: error ?? this.error,
  );
}

/// A playback session for one piece of media.
///
/// Screens and tests only ever see this interface. The media library lives
/// behind [VideoPlayerPlayback], so it can be swapped without touching
/// features — the same rule the app applies to dio and storage.
abstract class VideoPlayback {
  ValueListenable<VideoPlaybackState> get state;

  /// Loads the media. Failures surface as [VideoPlaybackState.error] rather
  /// than being thrown, so the screen can show them in place.
  Future<void> initialize();

  Future<void> play();
  Future<void> pause();
  Future<void> setMuted(bool muted);

  /// The rendered frames. Only meaningful once [VideoPlaybackState.ready].
  Widget buildSurface(BuildContext context);

  Future<void> dispose();
}

/// Creates a playback session for a media URL.
typedef VideoPlaybackFactory = VideoPlayback Function(Uri url);

/// Production wiring — the Flutter team's `video_player` package. Tests
/// override this with a timed fake, since widget tests have no platform
/// player to drive.
final videoPlaybackFactoryProvider = Provider<VideoPlaybackFactory>(
  (ref) => VideoPlayerPlayback.network,
);
