import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/features/earn/data/earn_models.dart';

/// Parsing of `AdResponse` (`GET /ads/{id}`) and the answer-submission
/// replies, whose shapes the OpenAPI leaves untyped.
void main() {
  group('VideoAd from AdResponse', () {
    Map<String, dynamic> question(String id, {int? order}) => {
      'id': id,
      'questionText': 'Question $id',
      'questionType': 'SINGLE_CHOICE',
      'orderIndex': ?order,
      'options': [
        {'id': '$id-a', 'optionText': 'A', 'correct': true},
      ],
    };

    test('reads the detail fields and orders questions by orderIndex', () {
      final ad = VideoAd.fromJson({
        'id': 'ad-1',
        'title': 'Aarong Dairy Promo',
        'adType': 'QUIZ',
        'status': 'ACTIVE',
        'mediaUrl': 'https://cdn.test/aarong.mp4',
        'durationSeconds': 15,
        'rewardAmount': 10.0,
        'passingScore': 100,
        'maxAttempts': 3,
        'questions': [question('b', order: 2), question('a', order: 1)],
      });

      expect(ad.adId, 'ad-1');
      expect(ad.videoUrl, 'https://cdn.test/aarong.mp4');
      expect(ad.duration, 15);
      expect(ad.adType, AdType.quiz);
      expect(ad.isSurvey, isFalse);
      expect(ad.isActive, isTrue);
      expect(ad.maxAttempts, 3);
      expect(ad.questions.map((q) => q.id), ['a', 'b']);
    });

    test('questions without orderIndex keep their arrival order', () {
      final ad = VideoAd.fromJson({
        'id': 'ad-1',
        'questions': [
          for (final id in ['c', 'a', 'b', 'd']) question(id),
        ],
      });
      expect(ad.questions.map((q) => q.id), ['c', 'a', 'b', 'd']);
    });

    test('reads isRequired, which surveys call required', () {
      final required = SurveyQuestion.fromJson({'id': 'q', 'isRequired': true});
      final legacy = SurveyQuestion.fromJson({'id': 'q', 'required': true});
      expect(required.isRequired, isTrue);
      expect(legacy.isRequired, isTrue);
    });

    test('a feed card is a plain video ad with no questions', () {
      final card = VideoAd.fromJson({
        'adId': 'ad-1',
        'title': 'Regal',
        'videoUrl': 'https://cdn.test/regal.mp4',
        'duration': 30,
        'reward': 5,
      });
      expect(card.adType, AdType.video);
      expect(card.hasQuestions, isFalse);
      expect(card.isImage, isFalse);
      expect(card.isActive, isTrue);
    });

    test('recognises image creatives by type or by extension', () {
      expect(VideoAd.fromJson({'id': 'x', 'adType': 'IMAGE'}).isImage, isTrue);
      expect(
        VideoAd.fromJson({
          'id': 'x',
          'mediaUrl': 'https://cdn.test/promo.GIF?v=2',
        }).isImage,
        isTrue,
      );
      expect(
        VideoAd.fromJson({'id': 'x', 'mediaUrl': 'https://cdn.test/a.m3u8'})
            .isImage,
        isFalse,
      );
    });

    test('details borrow what they lack from the feed card', () {
      final details = VideoAd.fromJson({
        'id': 'ad-1',
        'adType': 'SURVEY',
        'questions': [question('a')],
      });
      final card = VideoAd.fromJson({
        'adId': 'ad-1',
        'title': 'Regal',
        'videoUrl': 'https://cdn.test/regal.mp4',
        'duration': 30,
      });

      final merged = details.withFallback(card);
      expect(merged.title, 'Regal');
      expect(merged.videoUrl, 'https://cdn.test/regal.mp4');
      expect(merged.duration, 30);
      expect(merged.isSurvey, isTrue);
      expect(merged.questions, hasLength(1));
    });

    test('an ad off sale is not active', () {
      expect(VideoAd.fromJson({'id': 'x', 'status': 'PAUSED'}).isActive, false);
    });
  });

  group('AdAssessment', () {
    test('a quiz reply without passed is a fail', () {
      final result = AdAssessment.fromJson(const {});
      expect(result.passed, isFalse);
      expect(result.rewardTriggered, isFalse);
    });

    test('a survey reply without passed is accepted feedback', () {
      final result = AdAssessment.fromJson(const {}, passedByDefault: true);
      expect(result.passed, isTrue);
      expect(result.rewardTriggered, isTrue);
    });

    test('reads the graded fields', () {
      final result = AdAssessment.fromJson(const {
        'passed': true,
        'score': 2,
        'totalQuestions': 2,
        'pointsEarned': 20,
        'rewardTriggered': true,
      });
      expect(result.score, 2);
      expect(result.totalQuestions, 2);
      expect(result.pointsEarned, 20);
    });
  });
  // Spec field names next to the deployed DTO names, 2026-09-28.
  group('spec vs deployed field names', () {
    test('a claimed feed item is completed, by either flag', () {
      expect(
        VideoAd.fromJson({'adId': 'a', 'viewed': true}).isCompleted,
        isTrue,
      );
      expect(
        VideoAd.fromJson({'adId': 'a', 'status': 'completed'}).isCompleted,
        isTrue,
      );
      expect(
        VideoAd.fromJson({'adId': 'a', 'viewed': false, 'status': 'ACTIVE'})
            .isCompleted,
        isFalse,
      );
    });

    test('the claim survives merging with the ad details', () {
      final card = VideoAd.fromJson({'adId': 'a', 'viewed': true});
      final details = VideoAd.fromJson({'id': 'a', 'status': 'ACTIVE'});
      expect(details.withFallback(card).viewed, isTrue);
    });

    test('a view that earned money is a reward, whatever its status', () {
      expect(
        AdView.fromJson({'status': 'COMPLETED', 'rewardEarned': 15}).isRewarded,
        isTrue,
      );
      expect(
        AdView.fromJson({'status': 'COMPLETED', 'rewardEligible': true})
            .isRewarded,
        isTrue,
      );
      expect(
        AdView.fromJson({'status': 'COMPLETED', 'rewardEarned': 0}).isRewarded,
        isFalse,
      );
    });

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

    test('quiz card and result read either name', () {
      expect(
        QuizCard.fromJson({'id': 'q', 'totalQuestions': 3}).questionCount,
        3,
      );
      expect(
        QuizCard.fromJson({'id': 'q', 'questionCount': 4}).questionCount,
        4,
      );
      expect(
        QuizResult.fromJson({'passed': true, 'rewardAmount': 15}).reward,
        15,
      );
      expect(QuizResult.fromJson({'passed': true, 'reward': 12}).reward, 12);
    });
  });
}
