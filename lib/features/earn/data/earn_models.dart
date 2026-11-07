/// Models for the earning content: campaign items (ads, quizzes, surveys),
/// standalone quizzes and surveys, and campaigns.
///
/// Field names mirror the `02 Mobile` OpenAPI DTOs, which is what the live
/// API sends; where the docs name a field differently the other name is read
/// as a fallback. Money arrives as a number and is kept as [num] — the client
/// never does arithmetic on it.
library;

import '../../../core/utils/server_time.dart';

/// `Paged` and `EarningsSummary` used to live here. They are re-exported so
/// the earning screens keep a single import: the page envelope is shared
/// infrastructure, and the earnings total belongs to the wallet whose
/// endpoint serves it.
export '../../../core/network/paged.dart';
export '../../wallet/data/wallet_models.dart' show EarningsSummary;

/// What a content item asks of the user (`MobileContentItemDto.kind`).
enum ContentKind {
  /// Media only, paid when the view completes.
  ad,

  /// Graded questions, paid on submit when the score passes.
  quiz,

  /// Ungraded questions, paid on submit.
  survey;

  static ContentKind parse(String? raw) => switch (raw?.toUpperCase()) {
    'QUIZ' => quiz,
    'SURVEY' => survey,
    _ => ad,
  };
}

/// Which endpoints open and submit an item.
enum ContentSource {
  /// Part of a campaign: viewed with `/mobile/ads/{id}/view`, answered with
  /// `/quizzes/submit` or `/surveys/submit`.
  campaign,

  /// A quiz or survey that belongs to no campaign: opened and submitted
  /// through `/mobile/quizzes/{id}` or `/mobile/surveys/{id}`, with no media
  /// and no view step.
  standalone;

  static ContentSource parse(String? raw) =>
      raw?.toUpperCase() == 'STANDALONE' ? standalone : campaign;
}

/// The user's progress on one item.
enum ContentProgress {
  notStarted,

  /// The view is counted but the answers were never sent — the item opens
  /// straight on its questions.
  answersPending,
  completed;

  static ContentProgress parse(String? raw) => switch (raw?.toUpperCase()) {
    'ANSWERS_PENDING' => answersPending,
    'COMPLETED' => completed,
    _ => notStarted,
  };
}

enum MediaType {
  image,
  gif,
  video;

  static MediaType? parse(String? raw) => switch (raw?.toUpperCase()) {
    'IMAGE' => image,
    'GIF' => gif,
    'VIDEO' => video,
    _ => null,
  };
}

const _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

/// A still or animated image rather than a video, by declared type or, when
/// the type is missing, by the file extension.
bool isImageMedia(MediaType? type, String? url) {
  if (type == MediaType.image || type == MediaType.gif) return true;
  if (type == MediaType.video) return false;
  final path = Uri.tryParse(url ?? '')?.path.toLowerCase() ?? '';
  return _imageExtensions.any(path.endsWith);
}

/// One ad, quiz or survey (`MobileContentItemDto`) — the card in the Ads,
/// Quiz and Survey lists and on the campaign screen. Its [id] is the same on
/// every screen; for a campaign item it is the ad id the view and submit
/// endpoints take.
class ContentItem {
  const ContentItem({
    required this.id,
    required this.kind,
    required this.source,
    required this.title,
    this.description,
    this.mediaType,
    this.mediaUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.reward,
    this.paysPerQuestion = false,
    this.questionCount = 0,
    this.passingScore,
    this.progress = ContentProgress.notStarted,
    this.available = true,
    this.unavailableCode,
    this.unavailableMessage,
    this.campaignId,
    this.campaignTitle,
    this.campaignBannerUrl,
    this.campaignEndAt,
  });

  final String id;
  final ContentKind kind;
  final ContentSource source;
  final String title;
  final String? description;
  final MediaType? mediaType;
  final String? mediaUrl;

  /// Falls back to the campaign banner on the server already.
  final String? thumbnailUrl;

  /// Media length. The view only counts after 80% of it.
  final int? durationSeconds;

  /// BDT. When [paysPerQuestion] is true this is the most one user can earn.
  final num? reward;
  final bool paysPerQuestion;
  final int questionCount;

  /// Quiz only: the % of correct answers needed to be paid; null means 100.
  final int? passingScore;
  final ContentProgress progress;

  /// The user can do it now. When false, [unavailableMessage] says why and
  /// is safe to show.
  final bool available;
  final String? unavailableCode;
  final String? unavailableMessage;

  /// Null for a standalone item.
  final String? campaignId;
  final String? campaignTitle;
  final String? campaignBannerUrl;

  /// Null means the campaign has no end date.
  final DateTime? campaignEndAt;

  bool get isCompleted => progress == ContentProgress.completed;
  bool get isStandalone => source == ContentSource.standalone;
  bool get isSurvey => kind == ContentKind.survey;
  bool get hasQuestions => kind != ContentKind.ad;
  bool get isImage => isImageMedia(mediaType, mediaUrl);

  /// Worth offering a Start button: not done, and either open to the user or
  /// already viewed and waiting on its answers.
  bool get canStart =>
      !isCompleted && (available || progress == ContentProgress.answersPending);

  factory ContentItem.fromJson(Map<String, dynamic> json) => ContentItem(
    id: json['id']?.toString() ?? '',
    kind: ContentKind.parse(json['kind'] as String?),
    source: ContentSource.parse(json['source'] as String?),
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    mediaType: MediaType.parse(json['mediaType'] as String?),
    mediaUrl: json['mediaUrl'] as String?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    reward: json['reward'] as num?,
    paysPerQuestion: json['paysPerQuestion'] as bool? ?? false,
    questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    passingScore: (json['passingScore'] as num?)?.toInt(),
    progress: ContentProgress.parse(json['progress'] as String?),
    available: json['available'] as bool? ?? true,
    unavailableCode: json['unavailableCode'] as String?,
    unavailableMessage: json['unavailableMessage'] as String?,
    campaignId: json['campaignId']?.toString(),
    campaignTitle: json['campaignTitle'] as String?,
    campaignBannerUrl: json['campaignBannerUrl'] as String?,
    campaignEndAt: ServerTime.parse(json['campaignEndAt']),
  );
}

/// An item with its questions (`MobileContentDetailDto`,
/// `GET /mobile/content/{id}`). The correct answers are never sent.
class ContentDetail {
  const ContentDetail({required this.item, this.questions = const []});

  final ContentItem item;
  final List<SurveyQuestion> questions;

  factory ContentDetail.fromJson(Map<String, dynamic> json) => ContentDetail(
    item: ContentItem.fromJson(
      (json['item'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    questions: _inOrder(json['questions']),
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

/// A campaign with all of its items and the user's progress on them
/// (`MobileCampaignContentResponse`, `GET /mobile/campaigns/{id}/items`).
class CampaignContent {
  const CampaignContent({
    required this.id,
    required this.title,
    this.description,
    this.bannerUrl,
    this.campaignTypeLabel,
    this.contentTypeLabel,
    this.startAt,
    this.endAt,
    this.totalItems = 0,
    this.completedItems = 0,
    this.ads = const [],
    this.quizzes = const [],
    this.surveys = const [],
  });

  final String id;
  final String title;
  final String? description;
  final String? bannerUrl;
  final String? campaignTypeLabel;
  final String? contentTypeLabel;
  final DateTime? startAt;

  /// Null means no end date.
  final DateTime? endAt;
  final int totalItems;
  final int completedItems;
  final List<ContentItem> ads;
  final List<ContentItem> quizzes;
  final List<ContentItem> surveys;

  bool get isEmpty => ads.isEmpty && quizzes.isEmpty && surveys.isEmpty;

  factory CampaignContent.fromJson(Map<String, dynamic> json) {
    List<ContentItem> items(String key) => [
      for (final item in json[key] as List? ?? const [])
        if (item is Map) ContentItem.fromJson(item.cast<String, dynamic>()),
    ];
    final ads = items('ads');
    final quizzes = items('quizzes');
    final surveys = items('surveys');
    return CampaignContent(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      campaignTypeLabel: json['campaignTypeLabel'] as String?,
      contentTypeLabel: json['contentTypeLabel'] as String?,
      startAt: ServerTime.parse(json['startAt']),
      endAt: ServerTime.parse(json['endAt']),
      totalItems:
          (json['totalItems'] as num?)?.toInt() ??
          ads.length + quizzes.length + surveys.length,
      completedItems: (json['completedItems'] as num?)?.toInt() ?? 0,
      ads: ads,
      quizzes: quizzes,
      surveys: surveys,
    );
  }
}

/// Cashback reserved by an answer, paid once the user buys the product
/// (`cashback[]` on the submit reply).
class CashbackPromise {
  const CashbackPromise({
    required this.amount,
    this.cashbackId,
    this.questionId,
    this.status,
    this.purchaseDeadline,
  });

  final num amount;
  final String? cashbackId;
  final String? questionId;

  /// `AWAITING_PURCHASE` right after the answer.
  final String? status;
  final DateTime? purchaseDeadline;

  factory CashbackPromise.fromJson(Map<String, dynamic> json) =>
      CashbackPromise(
        amount: json['amount'] as num? ?? 0,
        cashbackId: json['cashbackId']?.toString(),
        questionId: json['questionId']?.toString(),
        status: json['status'] as String?,
        purchaseDeadline: ServerTime.parse(json['purchaseDeadline']),
      );
}

/// Outcome of answering a campaign item (`POST /quizzes/submit` or
/// `/surveys/submit`, both un-enveloped and untyped in the OpenAPI).
///
/// There is one submission per item: a failed quiz is still done, with no
/// reward, and cannot be retried.
class AdAssessment {
  const AdAssessment({
    required this.passed,
    this.score,
    this.totalQuestions,
    this.rewardEarned,
    this.cashbackPromised,
    this.cashback = const [],
    this.participationReference,
  });

  final bool passed;
  final int? score;
  final int? totalQuestions;

  /// Paid to the wallet now. A per-question item can pay something even when
  /// [passed] is false.
  final num? rewardEarned;

  /// Promised for buying a product later — not paid yet, so never "earned".
  final num? cashbackPromised;
  final List<CashbackPromise> cashback;
  final String? participationReference;

  bool get earned => (rewardEarned ?? 0) > 0;
  bool get hasCashback => (cashbackPromised ?? 0) > 0;

  /// [passedByDefault] covers a survey reply without a `passed` flag: a
  /// survey is not graded, so an accepted submission is a pass.
  factory AdAssessment.fromJson(
    Map<String, dynamic> json, {
    bool passedByDefault = false,
  }) => AdAssessment(
    passed: json['passed'] as bool? ?? passedByDefault,
    score: (json['score'] as num?)?.toInt(),
    totalQuestions: (json['totalQuestions'] as num?)?.toInt(),
    // Older replies named the payout `rewardAmount`. `pointsEarned` is a
    // points figure that never matched the wallet credit, so it is not read.
    rewardEarned: (json['rewardEarned'] ?? json['rewardAmount']) as num?,
    cashbackPromised: json['cashbackPromised'] as num?,
    cashback: [
      for (final entry in json['cashback'] as List? ?? const [])
        if (entry is Map)
          CashbackPromise.fromJson(entry.cast<String, dynamic>()),
    ],
    participationReference: json['participationReference'] as String?,
  );
}

/// Lifecycle of a recorded view (`AdViewResponse.status`).
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

/// A view of a campaign item (`AdViewResponse`, un-enveloped).
///
/// `POST /mobile/ads/{id}/view` is called twice: once when the media starts,
/// which answers [AdViewStatus.started] and pays nothing, and again when it
/// ends. The second call pays a plain ad ([AdViewStatus.rewarded]) or, for an
/// item with questions, completes the view with [awaitingAnswers] set.
class AdView {
  const AdView({
    required this.status,
    this.id,
    this.adId,
    this.watchedDurationSeconds,
    this.startedAt,
    this.completedAt,
    this.rewardEarned,
    this.awaitingAnswers = false,
  });

  final AdViewStatus status;
  final String? id;
  final String? adId;
  final int? watchedDurationSeconds;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final num? rewardEarned;

  /// The view counted; the reward now comes from submitting the answers.
  final bool awaitingAnswers;

  bool get isStarted => status == AdViewStatus.started;

  /// `rewardEligible` is deliberately not read: the server sets it on views
  /// that pay nothing, such as a quiz's.
  bool get isRewarded =>
      status == AdViewStatus.rewarded || (rewardEarned ?? 0) > 0;

  factory AdView.fromJson(Map<String, dynamic> json) => AdView(
    status: AdViewStatus.parse(json['status'] as String?),
    id: json['id']?.toString(),
    adId: json['adId']?.toString(),
    watchedDurationSeconds: (json['watchedDurationSeconds'] as num?)?.toInt(),
    startedAt: ServerTime.parse(json['startedAt']),
    completedAt: ServerTime.parse(json['completedAt']),
    rewardEarned: json['rewardEarned'] as num?,
    awaitingAnswers: json['awaitingAnswers'] as bool? ?? false,
  );
}

/// Campaign list card (`CampaignCardDto`). Tapping one opens the campaign
/// screen, which lists its items.
class CampaignCard {
  const CampaignCard({
    required this.id,
    required this.title,
    this.thumbnail,
    this.contentTypeLabel,
    this.rewardAmount,
    this.estimatedSeconds,
    this.status,
    this.endAt,
  });

  final String id;
  final String title;
  final String? thumbnail;

  /// "Quiz", "Video", "Survey" … (`contentTypeLabel`).
  final String? contentTypeLabel;
  final num? rewardAmount;
  final int? estimatedSeconds;

  /// `ACTIVE`, or `COMPLETED` once this user has finished it. Completed
  /// campaigns stay in the list as history.
  final String? status;

  /// Null means no end date.
  final DateTime? endAt;

  bool get isCompleted => status?.toUpperCase() == 'COMPLETED';

  factory CampaignCard.fromJson(Map<String, dynamic> json) => CampaignCard(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    thumbnail:
        (json['thumbnailUrl'] ?? json['thumbnail'] ?? json['bannerUrl'])
            as String?,
    contentTypeLabel: json['contentTypeLabel'] as String?,
    rewardAmount: json['rewardAmount'] as num?,
    estimatedSeconds:
        ((json['estimatedSeconds'] ?? json['durationSeconds']) as num?)
            ?.toInt(),
    status: json['status'] as String?,
    endAt: ServerTime.parse(json['endAt']),
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

/// Standalone quiz details (`QuizDetailsResponse`).
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

/// Standalone quiz outcome (`QuizResultResponse`).
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
    // `rewardAmount` per the spec (§10.1.3); the server still sends the
    // older `reward` too.
    reward: (json['rewardAmount'] ?? json['reward']) as num?,
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

/// A question — a standalone survey's (`MobileSurveyQuestionDto`) or a
/// campaign item's (`QuestionDto`), which adds rewards, media and cashback.
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
    this.rewardAmount,
    this.isCashback = false,
    this.productUrl,
    this.purchaseWindowDays,
    this.mediaType,
    this.mediaUrl,
  });

  /// The server's limit on a `TEXT` answer.
  static const int maxTextLength = 2000;

  final String id;
  final String text;
  final SurveyQuestionType type;
  final bool isRequired;
  final List<SurveyOption> options;

  /// Bounds for a RATING question; the server defaults them to 1–5.
  final int? minVal;
  final int? maxVal;

  /// Position within an item's questions (`QuestionDto.orderIndex`).
  final int? orderIndex;

  /// BDT this question pays — now, or as cashback when [isCashback].
  final num? rewardAmount;

  /// `rewardMode: PURCHASE_CASHBACK`: answering reserves cashback that is
  /// paid only after the user buys [productUrl] from the platform store
  /// within [purchaseWindowDays].
  final bool isCashback;
  final String? productUrl;
  final int? purchaseWindowDays;

  /// Media shown with the question itself.
  final MediaType? mediaType;
  final String? mediaUrl;

  bool get hasImage =>
      (mediaUrl?.isNotEmpty ?? false) && isImageMedia(mediaType, mediaUrl);

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) => SurveyQuestion(
    id: json['id']?.toString() ?? '',
    text: json['questionText'] as String? ?? '',
    type: SurveyQuestionType.parse(json['questionType'] as String?),
    // Surveys send `required`; the item `QuestionDto` names it `isRequired`.
    isRequired: (json['required'] ?? json['isRequired']) as bool? ?? false,
    orderIndex: (json['orderIndex'] as num?)?.toInt(),
    minVal: (json['minVal'] as num?)?.toInt(),
    maxVal: (json['maxVal'] as num?)?.toInt(),
    options: (json['options'] as List? ?? [])
        .map((e) => SurveyOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    rewardAmount: json['rewardAmount'] as num?,
    isCashback: json['rewardMode'] == 'PURCHASE_CASHBACK',
    productUrl: json['productUrl'] as String?,
    purchaseWindowDays: (json['purchaseWindowDays'] as num?)?.toInt(),
    mediaType: MediaType.parse(json['mediaType'] as String?),
    mediaUrl: json['mediaUrl'] as String?,
  );
}

/// Standalone survey details (`MobileSurveyDetailsResponse`).
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
    expiresAt: ServerTime.parse(json['expiresAt']),
  );
}

/// One answer in a survey or campaign-item submission.
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

  /// A TEXT answer, or a RATING's number as text. Sent as `textAnswer`,
  /// which the server accepts alongside the docs' `answerText`.
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
        rewardedAt: ServerTime.parse(json['rewardedAt'] ?? json['createdAt']),
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
