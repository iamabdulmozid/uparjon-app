import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';
import '../utils/ids.dart';

final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(ref.watch(localStoreProvider)),
);

/// Stable per-install identity sent with every login.
///
/// The backend ties a session to `deviceId`, so it must survive app restarts —
/// it is generated once and persisted. A random id (rather than a hardware
/// identifier) keeps us clear of Play Store restrictions on persistent
/// device IDs and needs no extra dependency.
class DeviceIdentity {
  DeviceIdentity(this._store);

  final LocalStore _store;

  String get id {
    final existing = _store.deviceId;
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = Ids.newId();
    // Fire-and-forget: the value is already returned, persistence just makes
    // it stable for the next launch.
    unawaited(_store.setDeviceId(generated));
    return generated;
  }

  String get name {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android device';
    if (Platform.isIOS) return 'iPhone';
    return Platform.operatingSystem;
  }

  String get platform {
    if (kIsWeb) return 'WEB';
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return Platform.operatingSystem.toUpperCase();
  }
}
