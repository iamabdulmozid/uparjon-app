import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'video_playback.dart';

/// A [VideoPlayback] with no media: it runs a clock for [length] and reports
/// completion when it runs out.
///
/// Used when an ad arrives without a playable URL — the server still verifies
/// the watched duration, so the flow stays honest — and by widget tests,
/// which cannot drive a platform player.
class TimedPlayback implements VideoPlayback {
  TimedPlayback(this.length, {this.surface});

  /// How long the "video" runs.
  final Duration length;

  /// What to draw in place of frames.
  final Widget? surface;

  static const Duration _tick = Duration(milliseconds: 500);

  final ValueNotifier<VideoPlaybackState> _state = ValueNotifier(
    const VideoPlaybackState(),
  );
  Timer? _ticker;
  bool _disposed = false;

  @override
  ValueListenable<VideoPlaybackState> get state => _state;

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    _state.value = _state.value.copyWith(
      ready: true,
      duration: length,
      completed: length <= Duration.zero,
    );
  }

  @override
  Future<void> play() async {
    if (_disposed || _ticker != null || _state.value.completed) return;
    _state.value = _state.value.copyWith(playing: true);
    _ticker = Timer.periodic(_tick, (_) {
      final next = _state.value.position + _tick;
      if (next >= length) {
        _ticker?.cancel();
        _ticker = null;
        _state.value = _state.value.copyWith(
          position: length,
          playing: false,
          completed: true,
        );
      } else {
        _state.value = _state.value.copyWith(position: next);
      }
    });
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _ticker?.cancel();
    _ticker = null;
    _state.value = _state.value.copyWith(playing: false);
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (_disposed) return;
    _state.value = _state.value.copyWith(muted: muted);
  }

  @override
  Widget buildSurface(BuildContext context) =>
      surface ?? const SizedBox.expand();

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    _state.dispose();
  }
}
