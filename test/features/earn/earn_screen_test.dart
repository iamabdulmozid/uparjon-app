import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/core/utils/formatters.dart';
import 'package:uparjon/features/earn/presentation/campaign_screen.dart';
import 'package:uparjon/features/earn/presentation/earn_screen.dart';
import 'package:uparjon/features/earn/presentation/task_list_screen.dart';

import '../../support/earn_fixtures.dart';
import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

final regalAd = contentItem(
  title: 'Regal Furniture Up to 15% Off',
  durationSeconds: 180,
);

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
}) => FakeApi(
  earnRoutes(
    ads: ads,
    surveys: surveys,
    quizzes: quizzes,
    campaigns: campaigns,
    rewards: rewards,
    dailyTasks: dailyTasks,
    today: today,
  ),
);

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
          surveys: [contentItem(id: 's-1', kind: 'SURVEY', title: 'Foods')],
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
      // The API's zone-less timestamps are Dhaka time, shown in local time.
      final local = DateTime.utc(2026, 7, 11, 4, 10).toLocal();
      expect(find.text(Formatters.activityTime(local)), findsOneWidget);
    });

    testWidgets('a failing feed only marks its own tile', (tester) async {
      final api = earnApi(
        surveys: [contentItem(id: 's-1', kind: 'SURVEY', title: 'Foods')],
      );
      api.routes['GET /mobile/content/ads'] = apiError(
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

    // Mobile API changes 2026-11-11 §5: a reward can be held for review,
    // then approved or rejected.
    testWidgets('held and rejected rewards say so, not that they paid', (
      tester,
    ) async {
      await openList(
        tester,
        earnApi(
          rewards: [
            {...regalReward, 'rewardId': 'r-1', 'status': 'PENDING'},
            {
              ...regalReward,
              'rewardId': 'r-2',
              'campaignName': 'Walton',
              'status': 'REJECTED',
            },
          ],
        ),
        'ads',
      );

      expect(find.text('Completed! ৳10.00 is under review'), findsOneWidget);
      expect(
        find.text('Completed, but the reward was not approved after review'),
        findsOneWidget,
      );
      expect(find.textContaining('and earned'), findsNothing);
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
              'contentType': 'VIDEO',
              'contentTypeLabel': 'Video',
              'rewardAmount': 50,
              'estimatedSeconds': 120,
            },
          ],
        ),
        'campaigns',
      );

      expect(find.text('Install and try our app'), findsOneWidget);
      expect(find.text('Video · 2 min'), findsOneWidget);
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

  // What the user already completed stays listed as history, with
  // `progress: COMPLETED` (API changes 2026-10-11 §1.6).
  group('claimed tasks', () {
    final claimedAd = contentItem(
      id: 'ad-2',
      title: 'Apex Footwear September Collection',
      durationSeconds: 45,
      reward: 20,
      progress: 'COMPLETED',
      available: false,
      unavailableCode: 'DUPLICATE_PARTICIPATION',
    );
    final openAd = regalAd;

    testWidgets('are badged, listed last, and not counted as remaining', (
      tester,
    ) async {
      await openList(tester, earnApi(ads: [claimedAd, openAd]), 'ads');

      expect(find.text('Completed'), findsOneWidget);
      // One open ad: the reward shows only on it.
      expect(find.text('+ ৳10.00'), findsOneWidget);
      expect(find.text('+ ৳20.00'), findsNothing);
      expect(find.text('01'), findsOneWidget);

      final open = tester.getTopLeft(find.text(openAd['title']! as String));
      final claimed = tester.getTopLeft(
        find.text(claimedAd['title']! as String),
      );
      expect(open.dy, lessThan(claimed.dy));
    });

    testWidgets('tapping one explains instead of starting it', (tester) async {
      final api = earnApi(ads: [claimedAd]);
      await openList(tester, api, 'ads');

      await tester.tap(find.text(claimedAd['title']! as String));
      await tester.pump();

      expect(
        find.text('You have already claimed your reward for this ad.'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsNothing);
      expect(api.callCount('GET /mobile/content/ad-2'), 0);
    });

    testWidgets('do not show as pending on the landing tiles', (tester) async {
      await openEarn(
        tester,
        earnApi(
          ads: [claimedAd],
          campaigns: [
            {
              'id': 'c-1',
              'title': 'Walton Smart Electronics',
              'contentTypeLabel': 'Video',
              'rewardAmount': 15,
              'status': 'COMPLETED',
            },
          ],
        ),
      );

      expect(find.text('Pending:'), findsNothing);
      expect(find.text('No task for today!'), findsNWidgets(4));
    });

    // Its items are the record of what the user did, so it still opens.
    testWidgets('a completed campaign opens on its items', (tester) async {
      final api = earnApi(
        campaigns: [
          {
            'id': 'c-1',
            'title': 'Walton Smart Electronics',
            'contentTypeLabel': 'Video',
            'rewardAmount': 15,
            'status': 'COMPLETED',
          },
        ],
      );
      api.routes['GET /mobile/campaigns/c-1/items'] = ok({
        'id': 'c-1',
        'title': 'Walton Smart Electronics',
        'totalItems': 1,
        'completedItems': 1,
        'ads': [contentItem(progress: 'COMPLETED', available: false)],
        'quizzes': [],
        'surveys': [],
      });
      await openList(tester, api, 'campaigns');

      expect(find.text('Completed'), findsOneWidget);
      await tester.tap(find.text('Walton Smart Electronics'));
      await tester.pumpAndSettle();

      expect(find.byType(CampaignScreen), findsOneWidget);
      expect(find.text('1 of 1 done'), findsOneWidget);
      expect(api.callCount('POST /mobile/campaigns/c-1/start'), 0);
    });
  });
}
