import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden with a real instance in `main.dart` during bootstrap.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden'),
);

/// Wrapper around key-value storage for non-sensitive preferences.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kOnboardingDone = 'onboarding_done';
  static const _kLocale = 'locale';
  static const _kDeviceId = 'device_id';

  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;

  Future<void> setOnboardingDone() => _prefs.setBool(_kOnboardingDone, true);

  String? get locale => _prefs.getString(_kLocale);

  Future<void> setLocale(String code) => _prefs.setString(_kLocale, code);

  /// Stable per-install device id sent to the auth endpoints.
  String? get deviceId => _prefs.getString(_kDeviceId);

  Future<void> setDeviceId(String id) => _prefs.setString(_kDeviceId, id);
}
