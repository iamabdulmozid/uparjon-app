import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uparjon/app/app.dart';
import 'package:go_router/go_router.dart';
import 'package:uparjon/app/router/app_router.dart';
import 'package:uparjon/core/media/timed_playback.dart';
import 'package:uparjon/core/media/video_playback.dart';
import 'package:uparjon/core/network/api_client.dart';
import 'package:uparjon/core/services/snackbar_service.dart';
import 'package:uparjon/core/storage/local_store.dart';

import 'fake_api.dart';

/// The Figma canvas size — tests render at the size the designs were drawn for.
const Size kDesignSize = Size(412, 917);

/// Boots the real app with an in-memory [LocalStore], mirroring `main.dart`.
Future<void> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  FakeApi? api,
  bool signedIn = false,
  bool keepSecureStorage = false,
  Duration fakeVideoLength = const Duration(seconds: 3),
}) async {
  await tester.binding.setSurfaceSize(kDesignSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SnackbarService.reset();
  _useInMemorySecureStorage(
    tester,
    seed: signedIn
        ? {'access_token': 'test-access', 'refresh_token': 'test-refresh'}
        : const {},
    // Simulates relaunching the app: whatever was written last time is
    // still on the device.
    carryOver: keepSecureStorage,
  );

  SharedPreferences.setMockInitialValues(prefs);
  final store = LocalStore(await SharedPreferences.getInstance());

  await tester.pumpWidget(
    ProviderScope(
      // Riverpod 3 retries failed providers with backoff; tests assert on the
      // first outcome, so a failure must stay a failure.
      retry: (retryCount, error) => null,
      overrides: [
        localStoreProvider.overrideWithValue(store),
        if (api != null)
          apiClientProvider.overrideWith((ref) => ApiClient(ref, dio: api.dio)),
        // No platform player in widget tests: every ad "video" is a clock.
        videoPlaybackFactoryProvider.overrideWithValue(
          (url) => TimedPlayback(fakeVideoLength),
        ),
      ],
      child: const UparjonApp(),
    ),
  );
}

/// Skips past the splash screen's minimum display time.
Future<void> settleSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2600));
  await tester.pumpAndSettle();
}

/// The running app's router, for pushing routes a test cannot reach by tapping.
GoRouter router(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(UparjonApp)),
  );
  return container.read(appRouterProvider);
}

/// Navigates the running app to a named route without walking the whole flow.
///
/// Waits out the splash timer first so no timer outlives the test.
Future<void> goTo(
  WidgetTester tester,
  String routeName, {
  Map<String, String> queryParameters = const {},
}) async {
  await settleSplash(tester);

  router(tester).goNamed(routeName, queryParameters: queryParameters);
  await tester.pumpAndSettle();
}

/// flutter_secure_storage has no implementation in the test binding, so its
/// channel is backed by a plain map for the duration of the test.
/// Survives between `pumpApp` calls so a test can model an app relaunch.
Map<String, String> _secureStorage = {};

void _useInMemorySecureStorage(
  WidgetTester tester, {
  Map<String, String> seed = const {},
  bool carryOver = false,
}) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = carryOver
      ? _secureStorage
      : (_secureStorage = <String, String>{...seed});

  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    final key = args['key'] as String?;
    return switch (call.method) {
      'read' => store[key],
      'write' => store[key!] = args['value'] as String,
      'delete' => store.remove(key),
      'deleteAll' => store.clear(),
      'readAll' => Map<String, String>.from(store),
      'containsKey' => store.containsKey(key),
      _ => null,
    };
  });

  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}
