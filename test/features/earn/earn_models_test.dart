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
}
