import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

/// Drives the reward-producing flows end to end against the fake transport,
/// checking the request bodies the API actually requires.
void main() {
  Future<void> open(
    WidgetTester tester,
    FakeApi api,
    String route,
    String id,
  ) async {
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
    final container = router(tester);
    container.pushNamed(route, pathParameters: {'id': id});
    await tester.pumpAndSettle();
  }

  group('watch ad', () {
    FakeApi adApi() => FakeApi({
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi'}),
      'GET /mobile/ads/feed': rawJson([
        {
          'adId': 'ad-1',
          'title': 'Regal Furniture',
          'duration': 3,
          'reward': 10,
        },
      ]),
      'POST /mobile/ads/ad-1/view': ok({
        'status': 'REWARDED',
        'rewardEligible': true,
        'watchedDurationSeconds': 3,
      }),
    });

    testWidgets('claims the reward only after the required watch time', (
      tester,
    ) async {
      final api = adApi();
      await open(tester, api, Routes.watchAd, 'ad-1');

      expect(find.text('Regal Furniture'), findsOneWidget);
      expect(find.text('Earn ৳10.00'), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, 'Start Watching'));
      await tester.pump();

      // Claim is disabled until the countdown finishes.
      expect(api.bodyOf('POST /mobile/ads/ad-1/view'), isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.widgetWithText(InkWell, 'Claim Reward'));
      await tester.pumpAndSettle();

      final body = api.bodyOf('POST /mobile/ads/ad-1/view')!;
      expect(body['watchedDurationSeconds'], 3);
      expect(body['deviceId'], isNotEmpty);
      expect(find.text('Reward on its way'), findsOneWidget);
    });

    testWidgets('sends an idempotency key so a retry cannot pay twice', (
      tester,
    ) async {
      final api = adApi();
      await open(tester, api, Routes.watchAd, 'ad-1');

      await tester.tap(find.widgetWithText(InkWell, 'Start Watching'));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.widgetWithText(InkWell, 'Claim Reward'));
      await tester.pumpAndSettle();

      final headers = api.headersOf('POST /mobile/ads/ad-1/view')!;
      expect(headers['Idempotency-Key'], isNotNull);
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

  group('campaign', () {
    testWidgets('start then complete leaves the reward pending', (
      tester,
    ) async {
      final api = FakeApi({
        'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi'}),
        'GET /mobile/campaigns/c-1': ok({
          'id': 'c-1',
          'title': 'Try our app',
          'description': 'Install and open it once.',
          'rewardAmount': 50,
          'eligible': true,
        }),
        'POST /mobile/campaigns/c-1/start': ok({'sessionId': 'sess-1'}),
        'POST /mobile/campaigns/c-1/complete': ok({'sessionId': 'sess-1'}),
      });

      await open(tester, api, Routes.campaign, 'c-1');

      expect(find.text('Try our app'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, 'Start'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InkWell, 'Mark as Complete'));
      await tester.pumpAndSettle();

      expect(api.callCount('POST /mobile/campaigns/c-1/start'), 1);
      expect(api.callCount('POST /mobile/campaigns/c-1/complete'), 1);
      expect(find.textContaining('Reward pending review'), findsOneWidget);
    });

    testWidgets('an ineligible campaign is dropped from the feed', (
      tester,
    ) async {
      final api = FakeApi({
        'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi'}),
        'GET /mobile/campaigns/c-1': ok({
          'id': 'c-1',
          'title': 'Try our app',
          'eligible': true,
        }),
        'POST /mobile/campaigns/c-1/start': apiError(
          'CAMPAIGN_NOT_ELIGIBLE',
          status: 403,
          message: 'You are not eligible',
        ),
      });

      await open(tester, api, Routes.campaign, 'c-1');
      await tester.tap(find.widgetWithText(InkWell, 'Start'));
      await tester.pumpAndSettle();

      // Bounced back rather than left on a campaign that cannot be run.
      expect(find.text('Try our app'), findsNothing);
    });
  });
}
