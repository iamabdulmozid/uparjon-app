import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/core/ui/app_button.dart';
import 'package:uparjon/features/earn/presentation/campaign_screen.dart';
import 'package:uparjon/features/earn/presentation/content_item_screen.dart';
import 'package:uparjon/features/earn/presentation/quiz_screen.dart';
import 'package:uparjon/features/earn/presentation/task_list_screen.dart';

import '../../support/earn_fixtures.dart';
import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

// The ad-view flow (Mobile API changes 2026-11-11 §1). The fake server
// always opens view `v-1`.
const _start = 'POST /ad-views/start';
const _complete = 'POST /ad-views/v-1/complete';
const _answers = 'POST /ad-views/v-1/answers';

/// `POST /ad-views/start`: the view is open.
FakeReply started() => ok({
  'adViewId': 'v-1',
  'startedAt': '2026-11-11T14:30:00',
}, message: 'Ad view started');

/// `POST /ad-views/{id}/complete`, enveloped like every other reply now.
FakeReply completed({
  String status = 'COMPLETED',
  num earned = 0,
  bool awaitingAnswers = false,
}) => ok({
  'id': 'v-1',
  'adId': 'ad-1',
  'status': status,
  'watchedDurationSeconds': 3,
  'rewardEarned': earned,
  'awaitingAnswers': awaitingAnswers,
}, message: 'Ad completed');

/// Drives the reward-producing flows end to end against the fake transport,
/// checking the request bodies the API actually requires
/// (`docs/API Docs V3/document.pdf`).
void main() {
  /// Pushes a runner screen directly, skipping the list and its overview.
  Future<void> open(
    WidgetTester tester,
    FakeApi api,
    String route,
    String id, {
    Map<String, Object> prefs = const {},
  }) async {
    await pumpApp(tester, api: api, signedIn: true, prefs: prefs);
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

  Future<void> watchToTheEnd(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(InkWell, label).last);
    await tester.pumpAndSettle();
  }

  VoidCallback? handlerOf(WidgetTester tester, String label) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, label)).onPressed;

  List<Object?> keysSentTo(FakeApi api, String key) => [
    for (final call in api.calls)
      if ('${call.method} ${call.path}' == key) call.headers['Idempotency-Key'],
  ];

  group('plain ad', () {
    FakeApi adApi({
      Map<String, dynamic>? item,
      List<FakeReply>? start,
      List<FakeReply>? complete,
    }) {
      final ad = item ?? contentItem();
      return FakeApi(
        {
          ...earnRoutes(ads: [ad]),
          'GET /mobile/content/ad-1': ok({'item': ad, 'questions': []}),
        },
        sequences: {
          _start: start ?? [started()],
          _complete: complete ?? [completed(status: 'REWARDED', earned: 10)],
        },
      );
    }

    testWidgets('starts the view on play and completes it at the end', (
      tester,
    ) async {
      final api = adApi();
      await openList(tester, api, 'ads');

      await tester.tap(find.text('Regal Furniture'));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byType(ContentItemScreen), findsOneWidget);
      expect(find.text('Watch till the end'), findsOneWidget);
      // Nothing is sent until the user presses play.
      expect(api.callCount(_start), 0);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The view was started before the media ran, and only once.
      expect(api.bodyOf(_start), {'adId': 'ad-1', 'deviceId': isNotEmpty});
      expect(api.callCount(_start), 1);
      expect(api.callCount(_complete), 0);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Completed on the view the server handed back.
      expect(api.bodyOf(_complete), {'watchedDurationSeconds': 3});
      // Two separate requests: one key each.
      final startKey = keysSentTo(api, _start).single;
      final completeKey = keysSentTo(api, _complete).single;
      expect(startKey, isNotNull);
      expect(completeKey, isNotNull);
      expect(startKey, isNot(completeKey));

      expect(find.text('Congratulation!'), findsOneWidget);
      // The reply cannot say whether the reward was held for review.
      expect(find.textContaining('You earned ৳10.00.'), findsOneWidget);
      expect(find.textContaining('show as pending'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(ContentItemScreen), findsNothing);
      expect(find.text('On going Ad'), findsOneWidget);
    });

    testWidgets('the media waits for the view to start', (tester) async {
      final api = adApi(
        start: [
          (status: 503, body: {'success': false, 'message': 'Down'}),
          started(),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Could not verify'), findsOneWidget);
      // The clock never started.
      expect(find.text('00:00 / 00:03'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(api.callCount(_start), 2);
      // A retry of the same request, so the same key.
      final keys = keysSentTo(api, _start);
      expect(keys.first, keys.last);
      expect(api.callCount(_complete), 1);
      expect(find.text('Congratulation!'), findsOneWidget);
    });

    testWidgets('a failed view is reported as not rewarded', (tester) async {
      final api = adApi(complete: [completed(status: 'FAILED')]);
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);

      expect(find.text('Not rewarded'), findsOneWidget);
    });

    // Too early leaves the view started: the completion may be sent again,
    // as a new request.
    testWidgets('a completion sent too early can be sent again', (
      tester,
    ) async {
      final api = adApi(
        complete: [
          apiError(
            'ILLEGAL_STATE',
            status: 500,
            message: 'Insufficient watch duration. Required: 24s, watched: 3s',
          ),
          completed(status: 'REWARDED', earned: 10),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);

      expect(
        find.text('Please watch the whole video to earn this reward.'),
        findsOneWidget,
      );
      expect(
        find.text('Something went wrong on our side. Please try again.'),
        findsNothing,
      );
      // The diagnostic text is matched, never shown.
      expect(find.textContaining('Required: 24s'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Congratulation!'), findsOneWidget);
      // Same view, not a new start.
      expect(api.callCount(_start), 1);
      final keys = keysSentTo(api, _complete);
      expect(keys, hasLength(2));
      expect(keys.first, isNot(keys.last));
    });

    testWidgets('says so when the ad has already paid out', (tester) async {
      final api = adApi(
        complete: [
          apiError(
            'ALREADY_CLAIMED',
            status: 409,
            message: 'You have already been rewarded for this ad',
          ),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);

      expect(
        find.text('You have already been rewarded for this one.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
    });

    for (final (code, message) in [
      ('DAILY_VIEW_CAP_REACHED', 'This ad has had all its views for today.'),
      ('OUTSIDE_DELIVERY_SCHEDULE', 'This ad is not shown at this hour.'),
    ]) {
      testWidgets('$code shows the server reason and is final', (tester) async {
        final api = adApi(
          start: [apiError(code, status: 409, message: message)],
        );
        await open(tester, api, Routes.contentItem, 'ad-1');

        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
      });
    }

    // A 403 that is a campaign rule, not an expired session.
    testWidgets('an audience refusal shows the reason and keeps the session', (
      tester,
    ) async {
      final api = adApi(
        start: [
          apiError(
            'NOT_IN_TARGET_AUDIENCE',
            status: 403,
            message: 'This campaign is not available in your area.',
          ),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text('This campaign is not available in your area.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.byType(ContentItemScreen), findsOneWidget);
      expect(api.callCount('POST /auth/refresh'), 0);
    });

    testWidgets('an ad without media still runs a clock for its duration', (
      tester,
    ) async {
      final api = adApi(item: contentItem(mediaUrl: null, mediaType: null));
      await open(tester, api, Routes.contentItem, 'ad-1');

      expect(find.text('Watch till the end'), findsOneWidget);
      await watchToTheEnd(tester);

      expect(api.bodyOf(_complete), {'watchedDurationSeconds': 3});
      expect(find.text('Congratulation!'), findsOneWidget);
    });

    testWidgets('a completed item is not played again', (tester) async {
      final api = adApi(
        item: contentItem(progress: 'COMPLETED', available: false),
      );
      await open(tester, api, Routes.contentItem, 'ad-1');

      expect(find.text('You have already completed this one.'), findsOneWidget);
      expect(find.text('Watch till the end'), findsNothing);
      expect(api.callCount(_start), 0);
    });

    testWidgets('an unavailable item shows the server reason', (tester) async {
      final api = adApi(
        item: contentItem(
          available: false,
          unavailableCode: 'CAMPAIGN_BUDGET_EXHAUSTED',
          unavailableMessage: 'This campaign has run out of budget.',
        ),
      );
      await open(tester, api, Routes.contentItem, 'ad-1');

      expect(find.text('This campaign has run out of budget.'), findsOneWidget);
      expect(api.callCount(_start), 0);
    });
  });

  // Quizzes and surveys of a campaign: the media first, its view started and
  // completed, then the questions, submitted once to the same view's
  // `/answers`.
  group('with questions', () {
    const discount = {
      'id': 'q1',
      'questionText': 'What was the percentage of discount on the Ad?',
      'questionType': 'SINGLE_CHOICE',
      'isRequired': true,
      'orderIndex': 1,
      'options': [
        {'id': 'p10', 'optionText': '10%'},
        {'id': 'p15', 'optionText': '15%'},
      ],
    };
    const brand = {
      'id': 'q2',
      'questionText': 'Which brand was featured?',
      'questionType': 'SINGLE_CHOICE',
      'isRequired': true,
      'orderIndex': 2,
      'options': [
        {'id': 'regal', 'optionText': 'Regal'},
        {'id': 'hatil', 'optionText': 'Hatil'},
      ],
    };

    FakeApi questionApi({
      String kind = 'QUIZ',
      String progress = 'NOT_STARTED',
      List<Map<String, dynamic>> questions = const [discount],
      List<FakeReply>? complete,
      List<FakeReply>? answers,
    }) {
      final item = contentItem(
        kind: kind,
        questionCount: questions.length,
        progress: progress,
      );
      return FakeApi(
        {
          ...earnRoutes(quizzes: [item]),
          'GET /mobile/content/ad-1': ok({
            'item': item,
            'questions': questions,
          }),
        },
        sequences: {
          _start: [started()],
          _complete: complete ?? [completed(awaitingAnswers: true)],
          _answers:
              answers ??
              [
                ok({
                  'passed': true,
                  'score': questions.length,
                  'totalQuestions': questions.length,
                  'rewardEarned': 10,
                  'cashbackPromised': 0,
                  'cashback': [],
                }, message: 'Answers submitted'),
              ],
        },
      );
    }

    Future<void> answerOne(WidgetTester tester, String option) async {
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
      await press(tester, 'Submit');
    }

    testWidgets('completes the view, walks the questions, submits once', (
      tester,
    ) async {
      final api = questionApi(questions: [brand, discount]);
      await open(tester, api, Routes.contentItem, 'ad-1');

      expect(find.text('Quiz'), findsOneWidget);
      expect(
        find.textContaining('After the video, 2 questions will appear'),
        findsOneWidget,
      );
      await watchToTheEnd(tester);

      // The view was started and completed first, with no answer in it.
      expect(api.callCount(_start), 1);
      expect(api.bodyOf(_complete), {'watchedDurationSeconds': 3});
      expect(api.callCount(_answers), 0);

      // Ordered by orderIndex, not by arrival; every question is required.
      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(
        find.text('What was the percentage of discount on the Ad?'),
        findsOneWidget,
      );
      expect(handlerOf(tester, 'Next'), isNull);

      await tester.tap(find.text('15%'));
      await tester.pumpAndSettle();
      await press(tester, 'Next');
      expect(find.text('Question 2 of 2'), findsOneWidget);

      // Back keeps the earlier answer.
      await press(tester, 'Back');
      expect(handlerOf(tester, 'Next'), isNotNull);
      await press(tester, 'Next');

      await answerOne(tester, 'Regal');

      // The view names the ad, so the body carries no adId.
      expect(api.bodyOf(_answers), {
        'answers': [
          {'questionId': 'q1', 'optionId': 'p15'},
          {'questionId': 'q2', 'optionId': 'regal'},
        ],
      });
      expect(keysSentTo(api, _answers).single, isNotNull);
      expect(find.text('Congratulation!'), findsOneWidget);
      expect(find.textContaining('Your answers are correct'), findsOneWidget);
      expect(find.textContaining('You earned ৳10.00.'), findsOneWidget);
    });

    // One submission per item: a failed quiz is done for good.
    testWidgets('a wrong answer ends the quiz without a retry', (tester) async {
      final api = questionApi(
        answers: [
          ok({'passed': false, 'score': 0, 'rewardEarned': 0}),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);
      await answerOne(tester, '10%');

      expect(find.text('Wrong Answer!'), findsOneWidget);
      expect(find.textContaining('the reward this time'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(ContentItemScreen), findsNothing);
    });

    testWidgets('a dropped submission is retried with the same key', (
      tester,
    ) async {
      final api = questionApi(
        answers: [
          (status: 503, body: {'success': false, 'message': 'Down'}),
          ok({'passed': true, 'score': 1, 'rewardEarned': 10}),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);
      await answerOne(tester, '15%');

      expect(find.text('Could not verify'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Congratulation!'), findsOneWidget);
      final keys = keysSentTo(api, _answers);
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
    });

    testWidgets('an item done elsewhere says so and is final', (tester) async {
      final api = questionApi(
        answers: [
          apiError(
            'DUPLICATE_PARTICIPATION',
            status: 409,
            message: 'You already took part in this item',
          ),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);
      await answerOne(tester, '15%');

      expect(find.text('You have already completed this one.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a refused answer goes back to the questions', (tester) async {
      final api = questionApi(
        answers: [
          apiError(
            'INVALID_ANSWER',
            message: 'Question q1 has an option that is not one of its own',
          ),
          ok({'passed': true, 'score': 1, 'rewardEarned': 10}),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);
      await answerOne(tester, '15%');

      expect(find.text('Check your answers'), findsOneWidget);
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();

      // The answer is kept, so Submit works straight away.
      expect(
        find.text('What was the percentage of discount on the Ad?'),
        findsOneWidget,
      );
      expect(handlerOf(tester, 'Submit'), isNotNull);
      await press(tester, 'Submit');

      expect(find.text('Congratulation!'), findsOneWidget);
      final keys = keysSentTo(api, _answers);
      expect(keys.first, isNot(keys.last));
      // The view is not started or completed again.
      expect(api.callCount(_start), 1);
      expect(api.callCount(_complete), 1);
    });

    testWidgets('a refused view never reaches the questions', (tester) async {
      final api = questionApi(complete: [completed(status: 'FAILED')]);
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);

      expect(find.text('Not rewarded'), findsOneWidget);
      expect(
        find.text('What was the percentage of discount on the Ad?'),
        findsNothing,
      );
      expect(api.callCount(_answers), 0);
    });

    // Answers go to the view they belong to, which only this device knows.
    testWidgets('keeps the view until its answers are in', (tester) async {
      final api = questionApi();
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_ad_view.ad-1'), 'v-1');

      await answerOne(tester, '15%');
      expect(find.text('Congratulation!'), findsOneWidget);
      expect(prefs.getString('pending_ad_view.ad-1'), isNull);
    });

    testWidgets('answers pending opens straight on the kept view', (
      tester,
    ) async {
      final api = questionApi(progress: 'ANSWERS_PENDING');
      await open(
        tester,
        api,
        Routes.contentItem,
        'ad-1',
        prefs: {'pending_ad_view.ad-1': 'v-1'},
      );

      expect(find.text('Watch till the end'), findsNothing);
      expect(
        find.text('What was the percentage of discount on the Ad?'),
        findsOneWidget,
      );
      await answerOne(tester, '15%');

      expect(api.callCount(_start), 0);
      expect(api.callCount(_complete), 0);
      expect(api.callCount(_answers), 1);
      expect(find.text('Congratulation!'), findsOneWidget);
    });

    testWidgets('answers pending without a kept view watches again', (
      tester,
    ) async {
      final api = questionApi(progress: 'ANSWERS_PENDING');
      await open(tester, api, Routes.contentItem, 'ad-1');

      expect(find.text('Watch till the end'), findsOneWidget);
      await watchToTheEnd(tester);
      expect(api.callCount(_start), 1);
      expect(
        find.text('What was the percentage of discount on the Ad?'),
        findsOneWidget,
      );
    });

    testWidgets('an answer refused for good forgets the kept view', (
      tester,
    ) async {
      final api = questionApi(
        progress: 'ANSWERS_PENDING',
        answers: [
          apiError(
            'ILLEGAL_STATE',
            status: 500,
            message: 'Ad view does not belong to the caller',
          ),
        ],
      );
      await open(
        tester,
        api,
        Routes.contentItem,
        'ad-1',
        prefs: {'pending_ad_view.ad-1': 'v-1'},
      );
      await answerOne(tester, '15%');

      expect(find.text('Try again'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_ad_view.ad-1'), isNull);
    });

    testWidgets('a survey sends every answer to the view', (tester) async {
      final api = questionApi(
        kind: 'SURVEY',
        questions: [
          {
            'id': 's1',
            'questionText': 'Rate the ad',
            'questionType': 'RATING',
            'isRequired': true,
            'minVal': 1,
            'maxVal': 5,
          },
          {
            'id': 's2',
            'questionText': 'Anything else?',
            'questionType': 'TEXT',
            // Every question is mandatory now, whatever the flag says.
            'isRequired': false,
          },
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await press(tester, 'Next');

      expect(handlerOf(tester, 'Submit'), isNull);
      await tester.enterText(find.byType(TextFormField), 'Clear and short');
      await tester.pumpAndSettle();
      await press(tester, 'Submit');

      expect(api.bodyOf(_answers), {
        'answers': [
          {'questionId': 's1', 'textAnswer': '4'},
          {'questionId': 's2', 'textAnswer': 'Clear and short'},
        ],
      });
      expect(find.text('Congratulation!'), findsOneWidget);
      expect(find.textContaining('Thanks for your feedback'), findsOneWidget);
    });

    // Cashback is promised, not paid: it must not read as earned.
    testWidgets('a cashback question promises cashback after purchase', (
      tester,
    ) async {
      final api = questionApi(
        questions: [
          {
            ...discount,
            'rewardMode': 'PURCHASE_CASHBACK',
            'rewardAmount': 50,
            'productUrl': 'https://store.test/rice-cooker',
            'purchaseWindowDays': 7,
          },
        ],
        answers: [
          ok({
            'passed': true,
            'rewardEarned': 0,
            'cashbackPromised': 50,
            'cashback': [
              {
                'cashbackId': 'cb-1',
                'questionId': 'q1',
                'amount': 50,
                'status': 'AWAITING_PURCHASE',
                'purchaseDeadline': '2026-11-08T23:59:00',
              },
            ],
          }),
        ],
      );
      await open(tester, api, Routes.contentItem, 'ad-1');
      await watchToTheEnd(tester);

      expect(
        find.text(
          'Buy this product from the store within 7 days to get ৳50.00 '
          'cashback.',
        ),
        findsOneWidget,
      );
      expect(find.text('https://store.test/rice-cooker'), findsOneWidget);
      await answerOne(tester, '15%');

      expect(find.text('Cashback reserved'), findsOneWidget);
      expect(
        find.textContaining('Buy the product from the store by'),
        findsOneWidget,
      );
      expect(find.text('Congratulation!'), findsNothing);
    });
  });

  group('campaign', () {
    const card = {
      'id': 'c-1',
      'title': 'Kitchen week',
      'contentType': 'QUIZ',
      'contentTypeLabel': 'Quiz',
      'rewardAmount': 50,
      'status': 'ACTIVE',
    };

    final ad = contentItem(title: 'New rice cooker');
    final quiz = contentItem(
      id: 'q-ad',
      kind: 'QUIZ',
      title: 'Logo colours',
      questionCount: 2,
      progress: 'COMPLETED',
      available: false,
      unavailableCode: 'DUPLICATE_PARTICIPATION',
    );
    final survey = contentItem(
      id: 's-ad',
      kind: 'SURVEY',
      title: 'Kitchen habits',
      questionCount: 3,
      available: false,
      unavailableCode: 'PARTICIPANT_TARGET_REACHED',
      unavailableMessage: 'This campaign is full.',
    );

    Map<String, dynamic> items({int completed = 1}) => {
      'id': 'c-1',
      'title': 'Kitchen week',
      'description': 'Cook more at home.',
      'bannerUrl': null,
      'contentTypeLabel': 'Quiz',
      'startAt': '2026-10-01T00:00:00',
      'endAt': null,
      'totalItems': 3,
      'completedItems': completed,
      'ads': [ad],
      'quizzes': [quiz],
      'surveys': [survey],
    };

    FakeApi campaignApi({FakeReply? itemsReply}) => FakeApi(
      {
        ...earnRoutes(campaigns: [card]),
        'GET /mobile/campaigns/c-1/items': itemsReply ?? ok(items()),
        'GET /mobile/content/ad-1': ok({'item': ad, 'questions': []}),
      },
      sequences: {
        _start: [started()],
        _complete: [completed(status: 'REWARDED', earned: 10)],
      },
    );

    testWidgets('lists every item with its state and runs one', (tester) async {
      final api = campaignApi();
      await openList(tester, api, 'campaigns');
      expect(find.text('Quiz'), findsOneWidget);

      await tester.tap(find.text('Kitchen week'));
      await tester.pumpAndSettle();

      expect(find.byType(CampaignScreen), findsOneWidget);
      expect(find.text('Cook more at home.'), findsOneWidget);
      expect(find.text('1 of 3 done'), findsOneWidget);
      expect(find.text('Ads'), findsOneWidget);
      expect(find.text('Quizzes'), findsOneWidget);
      expect(find.text('Surveys'), findsOneWidget);
      // Done, and closed with the server's reason.
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('This campaign is full.'), findsOneWidget);

      // A closed item explains itself instead of starting.
      await tester.tap(find.text('Kitchen habits'));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsNothing);

      await tester.tap(find.text('New rice cooker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.byType(ContentItemScreen), findsOneWidget);

      await watchToTheEnd(tester);
      expect(find.text('Congratulation!'), findsOneWidget);
      expect(api.callCount('POST /mobile/campaigns/c-1/start'), 0);

      // Back on the campaign, its items are fetched again for the new state.
      final before = api.callCount('GET /mobile/campaigns/c-1/items');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(CampaignScreen), findsOneWidget);
      expect(
        api.callCount('GET /mobile/campaigns/c-1/items'),
        greaterThan(before),
      );
    });

    testWidgets('a campaign that is no longer live says so', (tester) async {
      final api = campaignApi(
        itemsReply: apiError(
          'NOT_FOUND',
          status: 404,
          message: 'Campaign not found',
        ),
      );
      await open(tester, api, Routes.campaign, 'c-1');

      expect(
        find.text('This campaign is no longer available.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    });
  });

  // Standalone quizzes and surveys are listed with the campaign items but
  // keep their own endpoints and screens.
  testWidgets('a standalone quiz opens the quiz screen', (tester) async {
    final api = FakeApi({
      ...earnRoutes(
        quizzes: [
          contentItem(
            id: 'q-1',
            kind: 'QUIZ',
            source: 'STANDALONE',
            title: 'General knowledge',
            mediaUrl: null,
            mediaType: null,
            questionCount: 1,
          ),
        ],
      ),
      'GET /mobile/quizzes/q-1': ok({
        'id': 'q-1',
        'title': 'General knowledge',
        'questions': [
          {
            'id': 'q1',
            'questionText': 'Capital of Bangladesh?',
            'options': [
              {'id': 'o1', 'optionText': 'Dhaka'},
            ],
          },
        ],
      }),
    });
    await openList(tester, api, 'quizzes');

    await tester.tap(find.text('General knowledge'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Score at least 60%'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('Capital of Bangladesh?'), findsOneWidget);
    expect(api.callCount('GET /mobile/content/q-1'), 0);
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
      expect(find.text('Success'), findsOneWidget);
      expect(
        find.textContaining('successfully completed the quiz'),
        findsOneWidget,
      );
    });

    testWidgets('Finish Now asks before abandoning the quiz', (tester) async {
      final api = FakeApi({
        'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi'}),
        'GET /mobile/quizzes/q-1': ok({
          'id': 'q-1',
          'title': 'General knowledge',
          'questions': [
            {
              'id': 'q1',
              'questionText': 'Capital of Bangladesh?',
              'options': [
                {'id': 'o1', 'optionText': 'Dhaka'},
              ],
            },
          ],
        }),
      });
      await open(tester, api, Routes.quiz, 'q-1');

      await tester.tap(find.text('Finish Now'));
      await tester.pumpAndSettle();
      expect(find.text('Alert'), findsOneWidget);

      // Back keeps the user in the quiz.
      await tester.tap(find.widgetWithText(InkWell, 'Back').last);
      await tester.pumpAndSettle();
      expect(find.text('Alert'), findsNothing);
      expect(find.text('Capital of Bangladesh?'), findsOneWidget);

      await tester.tap(find.text('Finish Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish Quiz'));
      await tester.pumpAndSettle();
      expect(find.text('Capital of Bangladesh?'), findsNothing);
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
      expect(find.text('Success'), findsOneWidget);
      expect(
        find.textContaining('successfully completed the survey'),
        findsOneWidget,
      );
    });

    testWidgets('releases the slot when the user backs out', (tester) async {
      final api = surveyApi();
      await open(tester, api, Routes.survey, 's-1');

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      // Leaving is confirmed first; the slot stays held until then.
      expect(find.text('Alert'), findsOneWidget);
      expect(api.callCount('POST /mobile/surveys/s-1/discard'), 0);

      await tester.tap(find.text('Finish Survey'));
      await tester.pumpAndSettle();

      // Someone else can now take the slot.
      expect(api.callCount('POST /mobile/surveys/s-1/discard'), 1);
    });
  });
}
