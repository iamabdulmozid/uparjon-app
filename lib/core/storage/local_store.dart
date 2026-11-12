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
  static const _kPendingAdView = 'pending_ad_view.';

  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;

  Future<void> setOnboardingDone() => _prefs.setBool(_kOnboardingDone, true);

  String? get locale => _prefs.getString(_kLocale);

  Future<void> setLocale(String code) => _prefs.setString(_kLocale, code);

  /// Stable per-install device id sent to the auth endpoints.
  String? get deviceId => _prefs.getString(_kDeviceId);

  Future<void> setDeviceId(String id) => _prefs.setString(_kDeviceId, id);

  /// The completed ad view an item's answers are still owed to, by item id.
  ///
  /// Answers go to `/ad-views/{adViewId}/answers`, and the content item
  /// does not carry that id, so an item left at `ANSWERS_PENDING` can only
  /// be finished later if the id was kept here.
  String? pendingAdView(String itemId) =>
      _prefs.getString('$_kPendingAdView$itemId');

  Future<void> setPendingAdView(String itemId, String adViewId) =>
      _prefs.setString('$_kPendingAdView$itemId', adViewId);

  Future<void> clearPendingAdView(String itemId) =>
      _prefs.remove('$_kPendingAdView$itemId');
}
