import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../error/failure.dart';

/// Global snackbar access without a BuildContext.
///
/// [messengerKey] is registered on the root [MaterialApp], so any layer
/// (controllers, interceptors) can surface feedback from anywhere.
abstract final class SnackbarService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Guards against the same message being raised twice for one event — e.g.
  /// two widgets listening to the same failing provider.
  static const Duration _dedupeWindow = Duration(seconds: 2);
  static String? _lastMessage;
  static DateTime? _lastShownAt;

  static void showSuccess(String message) => _show(
    message,
    background: AppColors.success,
    foreground: AppColors.white,
  );

  static void showInfo(String message) => _show(message);

  static void showError(String message) =>
      _show(message, background: AppColors.error, foreground: AppColors.white);

  static void showFailure(Failure failure) => showError(failure.message);

  /// Test seam: forget the last message so dedupe cannot leak between tests.
  @visibleForTesting
  static void reset() {
    _lastMessage = null;
    _lastShownAt = null;
  }

  static void _show(String message, {Color? background, Color? foreground}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    final now = DateTime.now();
    final isRepeat =
        message == _lastMessage &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < _dedupeWindow;
    if (isRepeat) return;
    _lastMessage = message;
    _lastShownAt = now;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: foreground == null ? null : TextStyle(color: foreground),
          ),
          backgroundColor: background,
        ),
      );
  }
}
