/// Models for the earning content types: ads, quizzes, surveys and campaigns.
///
/// Field names mirror the `02 Mobile` OpenAPI DTOs, which is what the live
/// API sends. `docs/mobile-api-specification.md` names a few fields
/// differently (`thumbnailUrl`, `type`, `durationSeconds`); those are read as
/// fallbacks so either shape parses. Money arrives as a number and is kept as
/// [num] — the client never does arithmetic on it.
library;

/// A Spring `Page` envelope, used by the campaign list.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalElements,
    required this.isLast,
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int totalElements;
  final bool isLast;

  bool get hasMore => !isLast;

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) => Paged(
    items: (json['content'] as List? ?? [])
        .map((e) => itemFromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    page:
        (json['number'] as num?)?.toInt() ??
        ((json['pageable'] as Map?)?['pageNumber'] as num?)?.toInt() ??
        0,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
    isLast: json['last'] as bool? ?? true,
  );

  static Paged<T> empty<T>() => Paged<T>(
    items: const [],
    page: 0,
    totalPages: 0,
    totalElements: 0,
    isLast: true,
  );
}

/// A watchable video ad (`VideoAdDto`).
class VideoAd {
  const VideoAd({
    required this.adId,
    required this.title,
    this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    this.reward,
    this.question,
  });

  final String adId;
  final String title;
  final String? videoUrl;
  final String? thumbnailUrl;

  /// Required watch time in seconds.
  final int? duration;
  final num? reward;

  /// Follow-up question asked once the video ends (PRD ADS-4, Figma V2
  /// "Uparjon - Watch Ad"). `VideoAdDto` does not carry one yet, so this is
  /// null today and the flow goes straight from the video to verification.
  final AdQuestion? question;

  factory VideoAd.fromJson(Map<String, dynamic> json) => VideoAd(
    adId: (json['adId'] ?? json['id'])?.toString() ?? '',
    title: json['title'] as String? ?? '',
    videoUrl: (json['videoUrl'] ?? json['mediaUrl']) as String?,
    thumbnailUrl: (json['thumbnailUrl'] ?? json['thumbnail']) as String?,
    duration: ((json['duration'] ?? json['durationSeconds']) as num?)?.toInt(),
    reward: (json['reward'] ?? json['rewardAmount']) as num?,
    question: AdQuestion.tryParse(json['question']),
  );
}

/// A single-answer question about an ad.
///
/// Provisional shape — the API has no ad question yet. Parsing mirrors the
/// quiz DTOs (`questionText`, `options[].optionText`) so the backend can
/// reuse them; adjust here once `VideoAdDto` is extended.
class AdQuestion {
  const AdQuestion({
    required this.id,
    required this.text,
    required this.options,
  });

  final String id;
  final String text;
  final List<QuizOption> options;

  /// Null unless [raw] is a question with at least one option.
  static AdQuestion? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final options = [
      for (final option in json['options'] as List? ?? const [])
        if (option is Map)
          QuizOption(
            id: option['id']?.toString() ?? '',
            text: (option['optionText'] ?? option['text']) as String? ?? '',
          ),
    ];
    if (options.isEmpty) return null;
    return AdQuestion(
      id: json['id']?.toString() ?? '',
      text: (json['questionText'] ?? json['text']) as String? ?? '',
      options: options,
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
  });

  final String id;
  final String text;
  final SurveyQuestionType type;
  final bool isRequired;
  final List<SurveyOption> options;

  /// Bounds for a RATING question.
  final int? minVal;
  final int? maxVal;

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) => SurveyQuestion(
    id: json['id']?.toString() ?? '',
    text: json['questionText'] as String? ?? '',
    type: SurveyQuestionType.parse(json['questionType'] as String?),
    isRequired: json['required'] as bool? ?? false,
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

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    if (optionId != null) 'optionId': optionId,
    if (optionIds != null) 'optionIds': optionIds,
    if (textAnswer != null) 'textAnswer': textAnswer,
  };
}

/// Earnings totals (`EarningsSummaryResponse`,
/// `GET /mobile/wallet/earnings-summary`).
class EarningsSummary {
  const EarningsSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.lifetime,
  });

  final num today;
  final num thisWeek;
  final num thisMonth;
  final num lifetime;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        today: json['today'] as num? ?? 0,
        thisWeek: json['thisWeek'] as num? ?? 0,
        thisMonth: json['thisMonth'] as num? ?? 0,
        lifetime: json['lifetime'] as num? ?? 0,
      );
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
