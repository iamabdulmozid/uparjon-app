import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uparjon/core/config/app_env.dart';
import 'package:uparjon/core/storage/local_store.dart';
import 'package:uparjon/features/auth/data/auth_models.dart';
import 'package:uparjon/features/auth/data/auth_repository.dart';
import 'package:uparjon/features/earn/data/earn_repository.dart';
import 'package:uparjon/features/wallet/data/wallet_models.dart';
import 'package:uparjon/features/wallet/data/wallet_repository.dart';

/// Drives the real repositories against the real backend.
///
/// Widget tests answer "does the screen render what the repository returned";
/// only this answers "is that what the server actually sends". It logs in for
/// real, so it needs an account:
///
///     flutter test integration_test/live_api_test.dart -d <device-id> \
///       --dart-define=UPARJON_TEST_MOBILE=017xxxxxxxx \
///       --dart-define=UPARJON_TEST_PASSWORD=xxxxxxxx
///
/// Credentials are passed in, never committed. Without them every test here
/// skips, so the suite stays green on a machine that has none.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const mobile = String.fromEnvironment('UPARJON_TEST_MOBILE');
  const password = String.fromEnvironment('UPARJON_TEST_PASSWORD');
  // `testWidgets` takes a bool, so the reason goes in its own reported test
  // rather than in a skip message.
  final skip = mobile.isEmpty || password.isEmpty;

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          LocalStore(await SharedPreferences.getInstance()),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<AuthSession> signIn() => container
      .read(authRepositoryProvider)
      .login(identifier: mobile, password: password);

  group('live API', () {
    testWidgets('logs in and reads the wallet the home card shows', (
      tester,
    ) async {
      final session = await signIn();
      expect(session.accessToken, isNotEmpty);

      final overview = await container.read(walletRepositoryProvider).overview();

      // The figures belong to a live account, so assert the shape and the
      // invariants rather than amounts that move between runs.
      expect(overview.availableBalance, isA<num>());
      expect(overview.availableBalance, greaterThanOrEqualTo(0));
      expect(overview.pendingBalance, greaterThanOrEqualTo(0));
      expect(
        overview.lifetimeEarnings,
        greaterThanOrEqualTo(overview.availableBalance),
        reason: 'lifetime earnings cannot be below the current balance',
      );
    }, skip: skip);

    testWidgets('reads the ledger behind Recent Activity', (tester) async {
      await signIn();

      final page = await container
          .read(walletRepositoryProvider)
          .transactions();

      expect(page.totalElements, greaterThanOrEqualTo(page.items.length));
      for (final row in page.items) {
        expect(row.id, isNotEmpty, reason: 'every row needs a key');
        expect(row.type, isNotEmpty);
        // A row the app cannot classify falls back rather than throwing.
        expect(WalletActivityKind.values, contains(row.kind));
      }
    }, skip: skip);

    testWidgets('reads the earnings totals the task lists show', (
      tester,
    ) async {
      await signIn();

      final summary = await container
          .read(walletRepositoryProvider)
          .earningsSummary();

      expect(summary.today, greaterThanOrEqualTo(0));
      expect(summary.lifetime, greaterThanOrEqualTo(summary.thisMonth));
      expect(summary.thisMonth, greaterThanOrEqualTo(summary.thisWeek));
      expect(summary.thisWeek, greaterThanOrEqualTo(summary.today));
    }, skip: skip);

    testWidgets('every earning feed answers with a reward amount', (
      tester,
    ) async {
      await signIn();
      final earn = container.read(earnRepositoryProvider);

      final ads = await earn.adsFeed();
      final surveys = await earn.surveys();
      final quizzes = await earn.quizzes();
      final campaigns = await earn.campaigns();

      // Staging seeds ads and surveys; quizzes and campaigns are empty, so
      // those only assert that the call parses.
      expect(ads, isNotEmpty, reason: 'the ad feed is seeded on staging');
      expect(surveys, isNotEmpty, reason: 'surveys are seeded on staging');

      for (final ad in ads) {
        expect(ad.adId, isNotEmpty);
        expect(ad.reward, isNotNull, reason: 'an ad with no reward is unusable');
        expect(ad.reward!, greaterThan(0));
      }
      for (final survey in surveys) {
        expect(survey.id, isNotEmpty);
        expect(survey.rewardAmount, isNotNull);
        expect(survey.rewardAmount!, greaterThan(0));
      }
      for (final quiz in quizzes) {
        expect(quiz.id, isNotEmpty);
      }
      for (final campaign in campaigns.items) {
        expect(campaign.id, isNotEmpty);
      }
    }, skip: skip);

    testWidgets('points at the environment it was built for', (tester) async {
      expect(AppEnv.apiBaseUrl, contains('/api/v1'));
    });

    testWidgets('has credentials to sign in with', (tester) async {
      expect(
        skip,
        isFalse,
        reason:
            'Pass --dart-define=UPARJON_TEST_MOBILE and '
            '--dart-define=UPARJON_TEST_PASSWORD; the live tests were skipped.',
      );
    }, skip: !skip);
  });
}
