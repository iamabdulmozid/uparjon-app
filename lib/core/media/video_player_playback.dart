import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'video_playback.dart';

/// [VideoPlayback] backed by `video_player` — the one file in the app that
/// imports the package.
class VideoPlayerPlayback implements VideoPlayback {
  VideoPlayerPlayback.network(Uri url)
    : _controller = VideoPlayerController.networkUrl(url);

  final VideoPlayerController _controller;
  final ValueNotifier<VideoPlaybackState> _state = ValueNotifier(
    const VideoPlaybackState(),
  );
  bool _disposed = false;

  @override
  ValueListenable<VideoPlaybackState> get state => _state;

  /// Turns a raw player/ExoPlayer failure into something worth showing.
  ///
  /// A dead or access-denied media URL is not a connectivity problem, and
  /// telling the user to check their network sends them chasing the wrong
  /// thing. The raw text (`InvalidResponseCodeException: Response code: 403`,
  /// `UnrecognizedInputFormatException`, …) must never reach the screen.
  static String describeError(Object? error) {
    final raw = error?.toString() ?? '';
    final unavailable = [
      'Response code: 403',
      'Response code: 404',
      'Response code: 410',
      'AccessDenied',
      'Source error',
      'UnrecognizedInputFormat',
      'FileNotFound',
    ].any(raw.contains);

    return unavailable
        ? 'This video is unavailable. Please try another ad.'
        : 'Could not load this video. Check your connection and retry.';
  }

  @override
  Future<void> initialize() async {
    try {
      await _controller.initialize();
    } catch (error) {
      if (_disposed) return;
      _state.value = _state.value.copyWith(error: describeError(error));
      return;
    }
    if (_disposed) return;
    _controller.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (_disposed) return;
    final value = _controller.value;
    final reachedEnd =
        value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration;

    _state.value = VideoPlaybackState(
      ready: value.isInitialized,
      playing: value.isPlaying,
      completed: _state.value.completed || value.isCompleted || reachedEnd,
      muted: value.volume == 0,
      position: value.position,
      duration: value.duration,
      aspectRatio: value.isInitialized && value.aspectRatio > 0
          ? value.aspectRatio
          : 16 / 9,
      error: value.hasError ? describeError(value.errorDescription) : null,
    );
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> setMuted(bool muted) => _controller.setVolume(muted ? 0 : 1);

  @override
  Widget buildSurface(BuildContext context) => VideoPlayer(_controller);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(_sync);
    await _controller.dispose();
    _state.dispose();
  }
}
