/// Build-time environment configuration.
///
/// Values are injected with `--dart-define`, e.g.:
/// `flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://api.dev.uparjon.com`
abstract final class AppEnv {
  static const String name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// Staging is the default; pass `--dart-define=API_BASE_URL=...` to point at
  /// a local backend (`http://10.0.2.2:8080/api/v1` from an Android emulator).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.avytor.com/api/v1',
  );

  static bool get isProd => name == 'prod';
  static bool get isDev => name == 'dev';
}
