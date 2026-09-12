import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/earn/presentation/campaign_screen.dart';
import 'package:uparjon/features/earn/presentation/task_list_screen.dart';
import 'package:uparjon/features/earn/presentation/watch_ad_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

/// A page of items, shaped like Spring's `Page`.
Map<String, dynamic> springPage(List<Map<String, dynamic>> items) => {
  'content': items,
  'number': 0,
  'size': 20,
  'totalElements': items.length,
  'totalPages': items.isEmpty ? 0 : 1,
  'first': true,
  'last': true,
  'empty': items.isEmpty,
};

/// Everything the earning screens read on the way to a task, so a flow test
/// only has to add the endpoints it is about.
Map<String, FakeReply> earnRoutes({
  List<Map<String, dynamic>> ads = const [],
  List<Map<String, dynamic>> campaigns = const [],
}) => {
  'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi'}),
  'GET /mobile/ads/feed': rawJson(ads),
  'GET /mobile/quizzes': rawJson([]),
  'GET /mobile/surveys': rawJson([]),
  'GET /mobile/campaigns': ok(springPage(campaigns)),
  'GET /mobile/rewards/history': ok(springPage([])),
  'GET /mobile/tasks/daily': ok([]),
  'GET /mobile/wallet/earnings-summary': ok({'today': 0}),
};

/// Drives the reward-producing flows end to end against the fake transport,
/// checking the request bodies the API actually requires.
void main() {
  /// Pushes a runner screen directly, skipping the list and its overview.
  Future<void> open(
    WidgetTester tester,
    FakeApi api,
    String route,
    String id,
  ) async {
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
    router(tester).pushNamed(route, pathParameters: {'id': id});
    await tester.pumpAndSettle();
  }

  /// Opens a category list, the screen the user starts tasks from.
  Future<void> openList(WidgetTester tester, FakeApi api, String kind) async {
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
    router(tester).pushNamed(Routes.earnList, pathParameters: {'kind': kind});
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
  }

  group('watch ad', () {
    const regalAd = {
      'adId': 'ad-1',
      'title': 'Regal Furniture',
      'videoUrl': 'https://cdn.test/regal.mp4',
      'duration': 3,
      'reward': 10,
    };

    FakeApi adApi({Map<String, dynamic> ad = regalAd, FakeReply? view}) =>
        FakeApi({
          ...earnRoutes(ads: [ad]),
          'POST /mobile/ads/ad-1/view':
              view ??
              ok({
                'status': 'REWARDED',
                'rewardEligible': true,
                'watchedDurationSeconds': 3,
              }),
        });

    testWidgets('overview → watch → verify → congratulation', (tester) async {
      final api = adApi();
      await openList(tester, api, 'ads');

      await tester.tap(find.text('Regal Furniture'));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byType(WatchAdScreen), findsOneWidget);
      expect(find.text('Watch till the end'), findsOneWidget);
      expect(api.bodyOf('POST /mobile/ads/ad-1/view'), isNull);

      // The clock only runs once the user presses play, and nothing is
      // reported until the video has actually ended.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(api.bodyOf('POST /mobile/ads/ad-1/view'), isNull);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final body = api.bodyOf('POST /mobile/ads/ad-1/view')!;
      expect(body['watchedDurationSeconds'], 3);
      expect(body['deviceId'], isNotEmpty);
      expect(
        api.headersOf('POST /mobile/ads/ad-1/view')!['Idempotency-Key'],
        isNotNull,
      );
      expect(find.text('Congratulation!'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(WatchAdScreen), findsNothing);
      expect(find.text('On going Ad'), findsOneWidget);
    });

    testWidgets('a failed view is reported as not rewarded', (tester) async {
      final api = adApi(
        view: ok({'status': 'FAILED', 'rewardEligible': false}),
      );
      await open(tester, api, Routes.watchAd, 'ad-1');

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Not rewarded'), findsOneWidget);
    });

    testWidgets('an ad without a video still runs a clock for its duration', (
      tester,
    ) async {
      final api = adApi(
        ad: {
          'adId': 'ad-1',
          'title': 'Regal Furniture',
          'duration': 3,
          'reward': 10,
        },
      );
      await open(tester, api, Routes.watchAd, 'ad-1');

      expect(find.text('Watch till the end'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final body = api.bodyOf('POST /mobile/ads/ad-1/view')!;
      expect(body['watchedDurationSeconds'], 3);
      expect(find.text('Congratulation!'), findsOneWidget);
    });
  });

  group('campaign', () {
    const tryOurApp = {
      'id': 'c-1',
      'title': 'Try our app',
      'campaignType': 'INSTALL',
      'rewardAmount': 50,
    };

    FakeApi campaignApi({bool eligible = true, FakeReply? start}) => FakeApi({
      ...earnRoutes(campaigns: [tryOurApp]),
      'GET /mobile/campaigns/c-1': ok({
        'id': 'c-1',
        'title': 'Try our app',
        'description': 'Install and open it once.',
        'instructions': '1. Install the app\n2. Open it once',
        'rewardAmount': 50,
        'eligible': eligible,
      }),
      'POST /mobile/campaigns/c-1/start': start ?? ok({'sessionId': 'sess-1'}),
      'POST /mobile/campaigns/c-1/complete': ok({'sessionId': 'sess-1'}),
    });

    testWidgets('overview → start → complete leaves the reward pending', (
      tester,
    ) async {
      final api = campaignApi();
      await openList(tester, api, 'campaigns');

      await tester.tap(find.text('Try our app'));
      await tester.pumpAndSettle();
      expect(find.text('About this campaign'), findsOneWidget);
      expect(find.text('Install and open it once.'), findsOneWidget);
      expect(find.text('Install the app'), findsOneWidget);
      expect(find.textContaining('৳50.00'), findsWidgets);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(api.callCount('POST /mobile/campaigns/c-1/start'), 1);
      expect(find.byType(CampaignScreen), findsOneWidget);
      await tester.tap(find.text('Mark as Complete'));
      await tester.pumpAndSettle();

      expect(api.callCount('POST /mobile/campaigns/c-1/complete'), 1);
      expect(
        api.headersOf(
          'POST /mobile/campaigns/c-1/complete',
        )!['Idempotency-Key'],
        isNotNull,
      );
      expect(find.text('Completed!'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(CampaignScreen), findsNothing);
    });

    testWidgets('an ineligible campaign is dropped from the feed', (
      tester,
    ) async {
      final api = campaignApi(
        start: apiError(
          'CAMPAIGN_NOT_ELIGIBLE',
          status: 403,
          message: 'You are not eligible',
        ),
      );
      await open(tester, api, Routes.campaign, 'c-1');

      // Bounced back rather than left on a campaign that cannot be run.
      expect(find.byType(CampaignScreen), findsNothing);
      expect(find.textContaining('You are not eligible'), findsOneWidget);
    });

    testWidgets('the overview keeps Start disabled when not eligible', (
      tester,
    ) async {
      await openList(tester, campaignApi(eligible: false), 'campaigns');

      await tester.tap(find.text('Try our app'));
      await tester.pumpAndSettle();
      expect(
        find.text('You are not eligible for this campaign right now.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      // Still on the overview: nothing was started.
      expect(find.text('Overview'), findsOneWidget);
      expect(find.byType(CampaignScreen), findsNothing);
    });
  });

  group('quiz', () {
    testWidgets('walks the questions and reports the score', (tester) async {
      final api = FakeApi({
        'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi'}),
        'GET /mobile/quizzes/q-1': ok({
          'id': 'q-1',
          'title': 'General knowledge',
          'rewardAmount': 20,
          'questions': [
            {
              'id': 'q1',
              'questionText': 'Capital of Bangladesh?',
              'options': [
                {'id': 'o1', 'optionText': 'Dhaka'},
                {'id': 'o2', 'optionText': 'Chittagong'},
              ],
            },
            {
              'id': 'q2',
              'questionText': 'National flower?',
              'options': [
                {'id': 'o3', 'optionText': 'Shapla'},
                {'id': 'o4', 'optionText': 'Rose'},
              ],
            },
          ],
        }),
        'POST /mobile/quizzes/q-1/submit': ok({
          'score': 2,
          'totalQuestions': 2,
          'passed': true,
          'reward': 20,
        }),
      });

      await open(tester, api, Routes.quiz, 'q-1');

      expect(find.text('Capital of Bangladesh?'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.text('Dhaka'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('National flower?'), findsOneWidget);
      await tester.tap(find.text('Shapla'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Submit'));
      await tester.pumpAndSettle();

      final body = api.bodyOf('POST /mobile/quizzes/q-1/submit')!;
      expect(body['answers'], [
        {'questionId': 'q1', 'optionId': 'o1'},
        {'questionId': 'q2', 'optionId': 'o3'},
      ]);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Earned ৳20.00'), findsOneWidget);
    });
  });

  group('survey', () {
    FakeApi surveyApi() => FakeApi({
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi'}),
      'POST /mobile/surveys/s-1/heartbeat': ok({
        'surveyId': 's-1',
        'status': 'ACTIVE',
      }),
      'POST /mobile/surveys/s-1/discard': ok(null),
      'POST /mobile/surveys/s-1/submit': ok(null),
      'GET /mobile/surveys/s-1': ok({
        'id': 's-1',
        'title': 'Popular foods',
        'rewardAmount': 25,
        'questions': [
          {
            'id': 'q1',
            'questionText': 'Favourite drink?',
            'questionType': 'SINGLE_CHOICE',
            'required': true,
            'options': [
              {'id': 'o1', 'optionText': 'Borhani'},
              {'id': 'o2', 'optionText': 'Firni'},
            ],
          },
          {
            'id': 'q2',
            'questionText': 'Rate the taste',
            'questionType': 'RATING',
            'required': true,
            'minVal': 1,
            'maxVal': 5,
            'options': [],
          },
          {
            'id': 'q3',
            'questionText': 'Anything else?',
            'questionType': 'TEXT',
            'required': false,
            'options': [],
          },
        ],
      }),
    });

    testWidgets('reserves a slot, answers every question type, and submits', (
      tester,
    ) async {
      final api = surveyApi();
      await open(tester, api, Routes.survey, 's-1');

      // The slot is held from the moment the survey opens.
      expect(api.callCount('POST /mobile/surveys/s-1/heartbeat'), 1);

      await tester.tap(find.text('Borhani'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Next'));
      await tester.pumpAndSettle();

      // RATING renders the min..max range.
      expect(find.text('Rate the taste'), findsOneWidget);
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Next'));
      await tester.pumpAndSettle();

      // The last question is optional, so Submit is enabled without an answer.
      expect(find.text('Anything else?'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Tasty');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Submit'));
      await tester.pumpAndSettle();

      final body = api.bodyOf('POST /mobile/surveys/s-1/submit')!;
      expect(body['answers'], [
        {'questionId': 'q1', 'optionId': 'o1'},
        {'questionId': 'q2', 'textAnswer': '4'},
        {'questionId': 'q3', 'textAnswer': 'Tasty'},
      ]);
      expect(find.text('Survey submitted'), findsOneWidget);
    });

    testWidgets('releases the slot when the user backs out', (tester) async {
      final api = surveyApi();
      await open(tester, api, Routes.survey, 's-1');

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      // Someone else can now take the slot.
      expect(api.callCount('POST /mobile/surveys/s-1/discard'), 1);
    });
  });
}
