import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/features/earn/data/earn_models.dart';

import '../../support/earn_fixtures.dart';

/// Parsing of the content DTOs (`docs/API Docs V2/`) and the un-enveloped
/// view and submit replies, whose shapes the OpenAPI leaves untyped.
void main() {
  Map<String, dynamic> question(String id, {int? order}) => {
    'id': id,
    'questionText': 'Question $id',
    'questionType': 'SINGLE_CHOICE',
    'orderIndex': ?order,
    'options': [
      {'id': '$id-a', 'optionText': 'A'},
    ],
  };

  group('ContentItem', () {
    test('reads the item fields', () {
      final item = ContentItem.fromJson({
        ...contentItem(kind: 'QUIZ', questionCount: 2, passingScore: 80),
        'campaignEndAt': '2026-10-31T23:59:00Z',
      });

      expect(item.id, 'ad-1');
      expect(item.kind, ContentKind.quiz);
      expect(item.source, ContentSource.campaign);
      expect(item.mediaType, MediaType.video);
      expect(item.durationSeconds, 3);
      expect(item.questionCount, 2);
      expect(item.passingScore, 80);
      expect(item.hasQuestions, isTrue);
      expect(item.campaignId, 'c-1');
      // Campaign dates are the one kind sent in UTC, with a Z.
      expect(item.campaignEndAt, DateTime.utc(2026, 10, 31, 23, 59).toLocal());
    });

    test('a null end date means the campaign never ends', () {
      expect(ContentItem.fromJson(contentItem()).campaignEndAt, isNull);
    });

    test('standalone items have no campaign', () {
      final item = ContentItem.fromJson(
        contentItem(kind: 'SURVEY', source: 'STANDALONE'),
      );
      expect(item.isStandalone, isTrue);
      expect(item.isSurvey, isTrue);
      expect(item.campaignId, isNull);
    });

    test('progress decides whether it can start', () {
      ContentItem parse({String progress = 'NOT_STARTED', bool ok = true}) =>
          ContentItem.fromJson(contentItem(progress: progress, available: ok));

      expect(parse().canStart, isTrue);
      expect(parse(ok: false).canStart, isFalse);
      expect(parse(progress: 'COMPLETED', ok: false).isCompleted, isTrue);
      expect(parse(progress: 'COMPLETED').canStart, isFalse);
      // Viewed already: the answers may still be sent.
      expect(parse(progress: 'ANSWERS_PENDING', ok: false).canStart, isTrue);
    });

    test('recognises image media by type or by extension', () {
      ContentItem media(String? type, String? url) =>
          ContentItem.fromJson(contentItem(mediaType: type, mediaUrl: url));
      expect(media('IMAGE', 'https://cdn.test/a.mp4').isImage, isTrue);
      expect(media('GIF', null).isImage, isTrue);
      expect(media(null, 'https://cdn.test/promo.GIF?v=2').isImage, isTrue);
      expect(media(null, 'https://cdn.test/a.m3u8').isImage, isFalse);
      // A declared video is a video, whatever the link looks like.
      expect(media('VIDEO', 'https://cdn.test/a.png').isImage, isFalse);
    });
  });

  group('ContentDetail', () {
    test('orders questions by orderIndex', () {
      final detail = ContentDetail.fromJson({
        'item': contentItem(kind: 'QUIZ'),
        'questions': [question('b', order: 2), question('a', order: 1)],
      });
      expect(detail.item.kind, ContentKind.quiz);
      expect(detail.questions.map((q) => q.id), ['a', 'b']);
    });

    test('questions without orderIndex keep their arrival order', () {
      final detail = ContentDetail.fromJson({
        'item': contentItem(),
        'questions': [
          for (final id in ['c', 'a', 'b', 'd']) question(id),
        ],
      });
      expect(detail.questions.map((q) => q.id), ['c', 'a', 'b', 'd']);
    });

    test('reads the cashback and media fields of a question', () {
      final q = SurveyQuestion.fromJson({
        ...question('q'),
        'rewardMode': 'PURCHASE_CASHBACK',
        'rewardAmount': 50,
        'productUrl': 'https://store.test/p',
        'purchaseWindowDays': 7,
        'mediaType': 'IMAGE',
        'mediaUrl': '/api/v1/files/download/x.png',
      });
      expect(q.isCashback, isTrue);
      expect(q.rewardAmount, 50);
      expect(q.purchaseWindowDays, 7);
      expect(q.hasImage, isTrue);
      expect(SurveyQuestion.fromJson(question('p')).isCashback, isFalse);
    });

    test('reads isRequired, which surveys call required', () {
      final required = SurveyQuestion.fromJson({'id': 'q', 'isRequired': true});
      final legacy = SurveyQuestion.fromJson({'id': 'q', 'required': true});
      expect(required.isRequired, isTrue);
      expect(legacy.isRequired, isTrue);
    });
  });

  group('CampaignContent', () {
    test('groups the items and counts progress', () {
      final campaign = CampaignContent.fromJson({
        'id': 'c-1',
        'title': 'Kitchen week',
        'endAt': null,
        'totalItems': 3,
        'completedItems': 1,
        'ads': [contentItem()],
        'quizzes': [contentItem(id: 'q', kind: 'QUIZ')],
        'surveys': [],
      });
      expect(campaign.ads.single.kind, ContentKind.ad);
      expect(campaign.quizzes.single.kind, ContentKind.quiz);
      expect(campaign.surveys, isEmpty);
      expect(campaign.completedItems, 1);
      expect(campaign.totalItems, 3);
      expect(campaign.endAt, isNull);
      expect(campaign.isEmpty, isFalse);
    });
  });

  group('AdView', () {
    test('start hands back the view every later step takes', () {
      final session = AdViewSession.fromJson({
        'adViewId': 'v-1',
        'startedAt': '2026-11-11T14:30:00',
      });
      expect(session.adViewId, 'v-1');
      // Dhaka wall-clock time.
      expect(
        session.startedAt!.isAtSameMomentAs(DateTime.utc(2026, 11, 11, 8, 30)),
        isTrue,
      );
    });

    test('a started view has earned nothing', () {
      expect(AdView.fromJson({'status': 'STARTED'}).isRewarded, isFalse);
    });

    test('an item with questions waits for its answers', () {
      final view = AdView.fromJson({
        'status': 'COMPLETED',
        'awaitingAnswers': true,
        'rewardEarned': 0,
        // Set on views that pay nothing; never read.
        'rewardEligible': true,
      });
      expect(view.awaitingAnswers, isTrue);
      expect(view.isRewarded, isFalse);
    });

    test('a view that earned money is a reward', () {
      expect(AdView.fromJson({'status': 'REWARDED'}).isRewarded, isTrue);
      expect(
        AdView.fromJson({'status': 'COMPLETED', 'rewardEarned': 15}).isRewarded,
        isTrue,
      );
    });
  });

  group('AdAssessment', () {
    test('a quiz reply without passed is a fail', () {
      expect(AdAssessment.fromJson(const {}).passed, isFalse);
    });

    test('a survey reply without passed is accepted feedback', () {
      final result = AdAssessment.fromJson(const {}, passedByDefault: true);
      expect(result.passed, isTrue);
    });

    test('reads the graded fields', () {
      final result = AdAssessment.fromJson(const {
        'passed': true,
        'score': 2,
        'totalQuestions': 2,
        'rewardEarned': 4,
        'participationReference': 'CP-1',
        // A points figure that never matched the wallet credit.
        'pointsEarned': 20,
      });
      expect(result.score, 2);
      expect(result.totalQuestions, 2);
      expect(result.rewardEarned, 4);
      expect(result.earned, isTrue);
      expect(result.participationReference, 'CP-1');
    });

    test('cashback is promised, not earned', () {
      final result = AdAssessment.fromJson(const {
        'passed': true,
        'rewardEarned': 0,
        'cashbackPromised': 50,
        'cashback': [
          {
            'cashbackId': 'cb-1',
            'amount': 50,
            'status': 'AWAITING_PURCHASE',
            'purchaseDeadline': '2026-11-08T23:59:00',
          },
        ],
      });
      expect(result.earned, isFalse);
      expect(result.hasCashback, isTrue);
      expect(result.cashback.single.amount, 50);
      expect(
        result.cashback.single.purchaseDeadline,
        // No offset: Dhaka time, 6 h ahead of UTC.
        DateTime.utc(2026, 11, 8, 17, 59).toLocal(),
      );
    });
  });

  group('cards', () {
    test('campaign completion', () {
      expect(
        CampaignCard.fromJson({'id': 'c', 'status': 'COMPLETED'}).isCompleted,
        isTrue,
      );
      expect(
        CampaignCard.fromJson({'id': 'c', 'status': 'ACTIVE'}).isCompleted,
        isFalse,
      );
    });

    test('a standalone quiz result reads either reward name', () {
      expect(
        QuizResult.fromJson({'passed': true, 'rewardAmount': 15}).reward,
        15,
      );
      expect(QuizResult.fromJson({'passed': true, 'reward': 12}).reward, 12);
    });
  });
}
