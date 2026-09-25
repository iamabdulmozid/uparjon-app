/// Models for the earning content types: ads, quizzes, surveys and campaigns.
///
/// Field names mirror the `02 Mobile` OpenAPI DTOs, which is what the live
/// API sends. `docs/mobile-api-specification.md` names a few fields
/// differently (`thumbnailUrl`, `type`, `durationSeconds`); those are read as
/// fallbacks so either shape parses. Money arrives as a number and is kept as
/// [num] — the client never does arithmetic on it.
library;

/// `Paged` and `EarningsSummary` used to live here. They are re-exported so
/// the earning screens keep a single import: the page envelope is shared
/// infrastructure, and the earnings total belongs to the wallet whose
/// endpoint serves it.
export '../../../core/network/paged.dart';
export '../../wallet/data/wallet_models.dart' show EarningsSummary;

/// What an ad asks of the viewer (`AdResponse.adType`).
enum AdType {
  video,
  image,

  /// Questions after the media, graded against `passingScore`.
  quiz,

  /// Questions after the media, recorded as feedback and never graded.
  survey,
  other;

  static AdType parse(String? raw) => switch (raw?.toUpperCase()) {
    'VIDEO' || null => video,
    'IMAGE' || 'GIF' => image,
    'QUIZ' => quiz,
    'SURVEY' => survey,
    _ => other,
  };
}

/// A watchable ad: a feed card (`VideoAdDto`) or, with its questions, the
/// full `AdResponse` from `GET /ads/{id}`.
class VideoAd {
  const VideoAd({
    required this.adId,
    required this.title,
    this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    this.reward,
    this.adType = AdType.video,
    this.status,
    this.questions = const [],
    this.passingScore,
    this.maxAttempts,
  });

  final String adId;
  final String title;

  /// The creative — a video, or an image/GIF shown for [duration].
  final String? videoUrl;
  final String? thumbnailUrl;

  /// Required watch time in seconds.
  final int? duration;
  final num? reward;
  final AdType adType;

  /// `AdResponse.status`; the feed card carries none.
  final String? status;

  /// Asked once the media ends (Figma V3 "Watch Ad" question step). Only
  /// `GET /ads/{id}` carries them — the feed card never does. The API uses
  /// the survey `QuestionDto` for ad questions too, so the survey model and
  /// its answer widgets serve both.
  final List<SurveyQuestion> questions;
  final int? passingScore;

  /// How many graded submissions the server accepts; null means one.
  final int? maxAttempts;

  bool get hasQuestions => questions.isNotEmpty;

  /// Answers go to `/surveys/submit` (ungraded) rather than `/quizzes/submit`.
  bool get isSurvey => adType == AdType.survey;

  /// Taken off sale by the advertiser or out of budget.
  bool get isActive => status == null || status == 'ACTIVE';

  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

  /// A still or animated image rather than a video.
  bool get isImage {
    if (adType == AdType.image) return true;
    final path = Uri.tryParse(videoUrl ?? '')?.path.toLowerCase() ?? '';
    return _imageExtensions.any(path.endsWith);
  }

  /// This ad's details with anything they lack taken from [card] — the feed
  /// entry the user tapped.
  VideoAd withFallback(VideoAd? card) => card == null
      ? this
      : VideoAd(
          adId: adId,
          title: title.isEmpty ? card.title : title,
          videoUrl: videoUrl ?? card.videoUrl,
          thumbnailUrl: thumbnailUrl ?? card.thumbnailUrl,
          duration: duration ?? card.duration,
          reward: reward ?? card.reward,
          adType: adType,
          status: status,
          questions: questions,
          passingScore: passingScore,
          maxAttempts: maxAttempts,
        );

  factory VideoAd.fromJson(Map<String, dynamic> json) => VideoAd(
    adId: (json['adId'] ?? json['id'])?.toString() ?? '',
    title: json['title'] as String? ?? '',
    videoUrl: (json['videoUrl'] ?? json['mediaUrl']) as String?,
    thumbnailUrl: (json['thumbnailUrl'] ?? json['thumbnail']) as String?,
    duration: ((json['duration'] ?? json['durationSeconds']) as num?)?.toInt(),
    reward: (json['reward'] ?? json['rewardAmount']) as num?,
    adType: AdType.parse(json['adType'] as String?),
    status: json['status'] as String?,
    questions: _inOrder(json['questions']),
    passingScore: (json['passingScore'] as num?)?.toInt(),
    maxAttempts: (json['maxAttempts'] as num?)?.toInt(),
  );

  /// Questions sorted by `orderIndex`; ties and missing indexes keep the
  /// order they arrived in (`List.sort` alone is not stable).
  static List<SurveyQuestion> _inOrder(Object? raw) {
    final parsed = [
      for (final item in raw is List ? raw : const [])
        if (item is Map) SurveyQuestion.fromJson(item.cast<String, dynamic>()),
    ];
    final positions = {for (final (i, q) in parsed.indexed) q: i};
    int rank(SurveyQuestion q) => q.orderIndex ?? positions[q]!;
    return parsed..sort((a, b) {
      final byIndex = rank(a).compareTo(rank(b));
      return byIndex != 0 ? byIndex : positions[a]!.compareTo(positions[b]!);
    });
  }
}

/// Outcome of answering an ad's questions (`POST /quizzes/submit` or
/// `/surveys/submit`, both untyped maps in the OpenAPI).
class AdAssessment {
  const AdAssessment({
    required this.passed,
    required this.rewardTriggered,
    this.score,
    this.totalQuestions,
    this.pointsEarned,
  });

  final bool passed;
  final bool rewardTriggered;
  final int? score;
  final int? totalQuestions;
  final num? pointsEarned;

  /// [passedByDefault] covers a survey reply without a `passed` flag: a
  /// survey is not graded, so an accepted submission is a pass.
  factory AdAssessment.fromJson(
    Map<String, dynamic> json, {
    bool passedByDefault = false,
  }) {
    final passed = json['passed'] as bool? ?? passedByDefault;
    return AdAssessment(
      passed: passed,
      rewardTriggered: json['rewardTriggered'] as bool? ?? passed,
      score: (json['score'] as num?)?.toInt(),
      totalQuestions: (json['totalQuestions'] as num?)?.toInt(),
      pointsEarned: json['pointsEarned'] as num?,
    );
  }
}

/// Lifecycle of a recorded ad view (`AdViewResponse.status`).
enum AdViewStatus {
  started,
  completed,
  failed,
  rewarded,
  unknown;

  static AdViewStatus parse(String? raw) => switch (raw) {
    'STARTED' => started,
    'COMPLETED' => completed,
    'FAILED' => failed,
    'REWARDED' => rewarded,
    _ => unknown,
  };
}

/// Result of submitting an ad view (`AdViewResponse`).
class AdView {
  const AdView({
    required this.status,
    required this.rewardEligible,
    this.id,
    this.adId,
    this.watchedDurationSeconds,
    this.completedAt,
  });

  final AdViewStatus status;

  /// The server accepted the watch as reward-worthy. Payment may still wait
  /// on fraud validation, so this is "earned", not "credited".
  final bool rewardEligible;
  final String? id;
  final String? adId;
  final int? watchedDurationSeconds;
  final DateTime? completedAt;

  bool get isRewarded => status == AdViewStatus.rewarded || rewardEligible;

  factory AdView.fromJson(Map<String, dynamic> json) => AdView(
    status: AdViewStatus.parse(json['status'] as String?),
    rewardEligible: json['rewardEligible'] as bool? ?? false,
    id: json['id']?.toString(),
    adId: json['adId']?.toString(),
    watchedDurationSeconds: (json['watchedDurationSeconds'] as num?)?.toInt(),
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
  );
}

/// Campaign list card (`CampaignCardDto`).
class CampaignCard {
  const CampaignCard({
    required this.id,
    required this.title,
    this.thumbnail,
    this.campaignType,
    this.rewardAmount,
    this.estimatedSeconds,
    this.status,
  });

  final String id;
  final String title;
  final String? thumbnail;
  final String? campaignType;
  final num? rewardAmount;
  final int? estimatedSeconds;
  final String? status;

  factory CampaignCard.fromJson(Map<String, dynamic> json) => CampaignCard(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    thumbnail: (json['thumbnail'] ?? json['thumbnailUrl']) as String?,
    campaignType: (json['campaignType'] ?? json['type']) as String?,
    rewardAmount: json['rewardAmount'] as num?,
    estimatedSeconds:
        ((json['estimatedSeconds'] ?? json['durationSeconds']) as num?)
            ?.toInt(),
    status: json['status'] as String?,
  );
}

/// Campaign details (`CampaignDetailsResponse`).
class CampaignDetails {
  const CampaignDetails({
    required this.id,
    required this.title,
    required this.eligible,
    this.description,
    this.image,
    this.instructions,
    this.rewardAmount,
    this.estimatedDuration,
  });

  final String id;
  final String title;
  final bool eligible;
  final String? description;
  final String? image;
  final String? instructions;
  final num? rewardAmount;
  final int? estimatedDuration;

  factory CampaignDetails.fromJson(Map<String, dynamic> json) =>
      CampaignDetails(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        eligible: json['eligible'] as bool? ?? true,
        description: json['description'] as String?,
        image: (json['image'] ?? json['thumbnailUrl']) as String?,
        instructions: json['instructions'] as String?,
        rewardAmount: json['rewardAmount'] as num?,
        estimatedDuration:
            ((json['estimatedDuration'] ?? json['durationSeconds']) as num?)
                ?.toInt(),
      );
}

/// A started campaign run (`CampaignSessionResponse`).
class CampaignSession {
  const CampaignSession({required this.sessionId, this.startedAt});

  final String sessionId;
  final DateTime? startedAt;

  factory CampaignSession.fromJson(Map<String, dynamic> json) =>
      CampaignSession(
        sessionId: json['sessionId']?.toString() ?? '',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      );
}

/// Quiz list card (`QuizCardDto`).
class QuizCard {
  const QuizCard({
    required this.id,
    required this.title,
    this.questionCount,
    this.rewardAmount,
  });

  final String id;
  final String title;
  final int? questionCount;
  final num? rewardAmount;

  factory QuizCard.fromJson(Map<String, dynamic> json) => QuizCard(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    questionCount: (json['questionCount'] as num?)?.toInt(),
    rewardAmount: json['rewardAmount'] as num?,
  );
}

class QuizOption {
  const QuizOption({required this.id, required this.text});

  final String id;
  final String text;

  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
    id: json['id']?.toString() ?? '',
    text: json['optionText'] as String? ?? '',
  );
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
  });

  final String id;
  final String text;
  final List<QuizOption> options;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: json['id']?.toString() ?? '',
    text: json['questionText'] as String? ?? '',
    options: (json['options'] as List? ?? [])
        .map((e) => QuizOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// Quiz details (`QuizDetailsResponse`).
class QuizDetails {
  const QuizDetails({
    required this.id,
    required this.title,
    required this.questions,
    this.description,
    this.rewardAmount,
  });

  final String id;
  final String title;
  final List<QuizQuestion> questions;
  final String? description;
  final num? rewardAmount;

  factory QuizDetails.fromJson(Map<String, dynamic> json) => QuizDetails(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    rewardAmount: json['rewardAmount'] as num?,
    questions: (json['questions'] as List? ?? [])
        .map((e) => QuizQuestion.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// Quiz outcome (`QuizResultResponse`).
class QuizResult {
  const QuizResult({
    required this.score,
    required this.totalQuestions,
    required this.passed,
    this.reward,
  });

  final int score;
  final int totalQuestions;
  final bool passed;
  final num? reward;

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    score: (json['score'] as num?)?.toInt() ?? 0,
    totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
    passed: json['passed'] as bool? ?? false,
    reward: json['reward'] as num?,
  );
}

/// Survey list card (`SurveyCardDto`).
class SurveyCard {
  const SurveyCard({
    required this.id,
    required this.title,
    this.questionCount,
    this.rewardAmount,
    this.estimatedSeconds,
  });

  final String id;
  final String title;
  final int? questionCount;
  final num? rewardAmount;
  final int? estimatedSeconds;

  factory SurveyCard.fromJson(Map<String, dynamic> json) => SurveyCard(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    questionCount: (json['questionCount'] as num?)?.toInt(),
    rewardAmount: json['rewardAmount'] as num?,
    estimatedSeconds: (json['estimatedSeconds'] as num?)?.toInt(),
  );
}

enum SurveyQuestionType {
  singleChoice,
  multipleChoice,
  text,
  rating,
  boolean,
  unknown;

  static SurveyQuestionType parse(String? raw) => switch (raw) {
    'SINGLE_CHOICE' => singleChoice,
    'MULTIPLE_CHOICE' => multipleChoice,
    'TEXT' => text,
    'RATING' => rating,
    'BOOLEAN' => boolean,
    _ => unknown,
  };
}

class SurveyOption {
  const SurveyOption({required this.id, required this.text});

  final String id;
  final String text;

  factory SurveyOption.fromJson(Map<String, dynamic> json) => SurveyOption(
    id: json['id']?.toString() ?? '',
    text: json['optionText'] as String? ?? '',
  );
}

class SurveyQuestion {
  const SurveyQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.isRequired,
    required this.options,
    this.minVal,
    this.maxVal,
    this.orderIndex,
  });

  final String id;
  final String text;
  final SurveyQuestionType type;
  final bool isRequired;
  final List<SurveyOption> options;

  /// Bounds for a RATING question.
  final int? minVal;
  final int? maxVal;

  /// Position within an ad's questions (`QuestionDto.orderIndex`).
  final int? orderIndex;

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) => SurveyQuestion(
    id: json['id']?.toString() ?? '',
    text: json['questionText'] as String? ?? '',
    type: SurveyQuestionType.parse(json['questionType'] as String?),
    // Surveys send `required`; the ad `QuestionDto` names it `isRequired`.
    isRequired: (json['required'] ?? json['isRequired']) as bool? ?? false,
    orderIndex: (json['orderIndex'] as num?)?.toInt(),
    minVal: (json['minVal'] as num?)?.toInt(),
    maxVal: (json['maxVal'] as num?)?.toInt(),
    options: (json['options'] as List? ?? [])
        .map((e) => SurveyOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// Survey details (`MobileSurveyDetailsResponse`).
class SurveyDetails {
  const SurveyDetails({
    required this.id,
    required this.title,
    required this.questions,
    this.description,
    this.rewardAmount,
    this.estimatedSeconds,
  });

  final String id;
  final String title;
  final List<SurveyQuestion> questions;
  final String? description;
  final num? rewardAmount;
  final int? estimatedSeconds;

  factory SurveyDetails.fromJson(Map<String, dynamic> json) => SurveyDetails(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    rewardAmount: json['rewardAmount'] as num?,
    estimatedSeconds: (json['estimatedSeconds'] as num?)?.toInt(),
    questions: (json['questions'] as List? ?? [])
        .map((e) => SurveyQuestion.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// A reserved survey slot (`SurveySlotResponse`).
///
/// Surveys cap concurrent respondents, so a slot is held while answering and
/// must be kept alive with a heartbeat or released with discard.
class SurveySlot {
  const SurveySlot({required this.status, this.reservationId, this.expiresAt});

  final String status;
  final String? reservationId;
  final DateTime? expiresAt;

  factory SurveySlot.fromJson(Map<String, dynamic> json) => SurveySlot(
    status: json['status'] as String? ?? '',
    reservationId: json['reservationId']?.toString(),
    expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
  );
}

/// One answer in a survey submission.
class SurveyAnswer {
  const SurveyAnswer({
    required this.questionId,
    this.optionId,
    this.optionIds,
    this.textAnswer,
  });

  final String questionId;
  final String? optionId;
  final List<String>? optionIds;
  final String? textAnswer;

  /// Something was picked or typed — a blank text box does not count.
  bool get hasValue =>
      optionId != null ||
      (optionIds?.isNotEmpty ?? false) ||
      (textAnswer?.trim().isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    if (optionId != null) 'optionId': optionId,
    if (optionIds != null) 'optionIds': optionIds,
    if (textAnswer != null) 'textAnswer': textAnswer,
  };
}

/// A completed task's reward (`RewardHistoryItem`,
/// `GET /mobile/rewards/history`). Sits `PENDING` until fraud validation
/// clears it, then is credited to the wallet.
class RewardHistoryItem {
  const RewardHistoryItem({
    required this.rewardId,
    required this.campaignName,
    required this.status,
    this.rewardAmount,
    this.rewardedAt,
  });

  final String rewardId;
  final String campaignName;
  final String status;
  final num? rewardAmount;
  final DateTime? rewardedAt;

  bool get isPending => status.toUpperCase() == 'PENDING';

  factory RewardHistoryItem.fromJson(Map<String, dynamic> json) =>
      RewardHistoryItem(
        rewardId: (json['rewardId'] ?? json['id'])?.toString() ?? '',
        campaignName: (json['campaignName'] ?? json['title'] ?? '').toString(),
        status: json['status'] as String? ?? '',
        rewardAmount: (json['rewardAmount'] ?? json['amount']) as num?,
        rewardedAt: DateTime.tryParse(
          (json['rewardedAt'] ?? json['createdAt'] ?? '').toString(),
        ),
      );
}

/// One item of today's checklist (`DailyTaskDto`, `GET /mobile/tasks/daily`).
class DailyTask {
  const DailyTask({
    required this.title,
    required this.target,
    required this.progress,
    this.id,
    this.reward,
  });

  final String title;
  final int target;
  final int progress;
  final String? id;
  final num? reward;

  bool get completed => target > 0 && progress >= target;

  factory DailyTask.fromJson(Map<String, dynamic> json) => DailyTask(
    id: json['id']?.toString(),
    title: json['title'] as String? ?? '',
    target: (json['target'] as num?)?.toInt() ?? 0,
    progress: (json['progress'] as num?)?.toInt() ?? 0,
    reward: json['reward'] as num?,
  );
}
