import 'dart:math';

/// Random identifiers for client-generated keys.
abstract final class Ids {
  static final Random _random = Random.secure();

  /// A 32-character hex id, used for `Idempotency-Key` headers and the
  /// per-install device id.
  static String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
