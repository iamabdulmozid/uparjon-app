import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/earn/presentation/earn_screen.dart';
import 'package:uparjon/features/earn/presentation/task_list_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

const regalAd = {
  'adId': 'ad-1',
  'title': 'Regal Furniture Up to 15% Off',
  'duration': 180,
  'reward': 10,
};

const regalReward = {
  'rewardId': 'r-1',
  'campaignName': 'Regal Furniture',
  'rewardAmount': 10,
  'status': 'REWARDED',
  'rewardedAt': '2026-07-11T10:10:00',
};

FakeApi earnApi({
  List<Map<String, dynamic>> ads = const [],
  List<Map<String, dynamic>> surveys = const [],
  List<Map<String, dynamic>> quizzes = const [],
  List<Map<String, dynamic>> campaigns = const [],
  List<Map<String, dynamic>> rewards = const [],
  List<Map<String, dynamic>> dailyTasks = const [],
  num today = 0,
}) => FakeApi({
  'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
  // The ads, quiz and survey feeds answer with a bare array, not the envelope.
  'GET /mobile/ads/feed': rawJson(ads),
  'GET /mobile/quizzes': rawJson(quizzes),
  'GET /mobile/surveys': rawJson(surveys),
  'GET /mobile/campaigns': ok(springPage(campaigns)),
  'GET /mobile/rewards/history': ok(springPage(rewards)),
  'GET /mobile/tasks/daily': ok(dailyTasks),
  'GET /mobile/wallet/earnings-summary': ok({
    'today': today,
    'thisWeek': today,
    'thisMonth': today,
    'lifetime': today,
  }),
});

void main() {
  Future<void> openEarn(WidgetTester tester, FakeApi api) async {
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
    await tester.tap(find.text('Uparjon').last);
    await tester.pumpAndSettle();
    expect(find.byType(EarnScreen), findsOneWidget);
  }

  Future<void> openList(WidgetTester tester, FakeApi api, String kind) async {
    await openEarn(tester, api);
    router(tester).pushNamed(Routes.earnList, pathParameters: {'kind': kind});
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
  }

  group('landing', () {
    testWidgets('shows a tile per category with what is pending', (
      tester,
    ) async {
      await openEarn(tester, earnApi(ads: [regalAd]));

      expect(find.text('Ads'), findsOneWidget);
      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Survey'), findsOneWidget);
      expect(find.text('Campaigns'), findsOneWidget);
      // One ad waiting; the other three feeds are empty.
      expect(find.text('Pending:'), findsOneWidget);
      expect(find.text('No task for today!'), findsNWidgets(3));
    });

    testWidgets('the rings come from the daily checklist and the feeds', (
      tester,
    ) async {
      await openEarn(
        tester,
        earnApi(
          ads: [regalAd],
          surveys: [
            {'id': 's-1', 'title': 'Foods', 'rewardAmount': 25},
          ],
          campaigns: [
            {'id': 'c-1', 'title': 'Try our app'},
          ],
          dailyTasks: [
            {'title': 'Watch 5 Video Ads', 'target': 5, 'progress': 2},
            {'title': 'Complete Daily Quiz', 'target': 1, 'progress': 1},
          ],
        ),
      );

      // 3 of 6 daily targets hit; ads + surveys + campaigns still open.
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Task Completed'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Remaining Task'), findsOneWidget);
    });

    testWidgets('recent activity lists reward history', (tester) async {
      await openEarn(tester, earnApi(rewards: [regalReward]));

      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Regal Furniture'), findsOneWidget);
      expect(find.text('+ ৳10.00'), findsOneWidget);
      expect(find.text('11 Jul 26 | 10:10 am'), findsOneWidget);
    });

    testWidgets('a failing feed only marks its own tile', (tester) async {
      final api = earnApi(
        surveys: [
          {'id': 's-1', 'title': 'Foods'},
        ],
      );
      api.routes['GET /mobile/ads/feed'] = apiError(
        'INTERNAL_SERVER_ERROR',
        status: 500,
      );
      await openEarn(tester, api);

      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Pending:'), findsOneWidget);
    });
  });

  group('list', () {
    testWidgets("shows today's earning, open ads and completed rewards", (
      tester,
    ) async {
      await openList(
        tester,
        earnApi(ads: [regalAd], rewards: [regalReward], today: 60),
        'ads',
      );

      expect(find.text("Today's Earning"), findsOneWidget);
      expect(find.text('৳ 60'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('Remaining Ad'), findsOneWidget);
      expect(find.text('On going Ad'), findsOneWidget);
      expect(find.text('Regal Furniture Up to 15% Off'), findsOneWidget);
      expect(find.text('Takes approximate 3 min'), findsOneWidget);
      expect(find.text('+ ৳10.00'), findsOneWidget);
      expect(
        find.text('Completed this ad successfully! and earned ৳10.00'),
        findsOneWidget,
      );
    });

    testWidgets('an empty feed explains itself instead of showing nothing', (
      tester,
    ) async {
      await openList(tester, earnApi(), 'ads');

      expect(find.textContaining('No ads available right now'), findsOneWidget);
    });

    testWidgets('campaigns come from the paged endpoint', (tester) async {
      await openList(
        tester,
        earnApi(
          campaigns: [
            {
              'id': 'c-1',
              'title': 'Install and try our app',
              'campaignType': 'INSTALL',
              'rewardAmount': 50,
              'estimatedSeconds': 120,
            },
          ],
        ),
        'campaigns',
      );

      expect(find.text('Install and try our app'), findsOneWidget);
      expect(find.text('INSTALL · 2 min'), findsOneWidget);
      expect(find.text('+ ৳50.00'), findsOneWidget);
    });

    testWidgets('tapping a task opens its overview, and Back dismisses it', (
      tester,
    ) async {
      await openList(tester, earnApi(ads: [regalAd]), 'ads');

      await tester.tap(find.text('Regal Furniture Up to 15% Off'));
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Before you start'), findsOneWidget);
      expect(find.text('Watch the video till the end'), findsOneWidget);
      expect(find.textContaining('৳10.00'), findsWidgets);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsNothing);
    });
  });
}
