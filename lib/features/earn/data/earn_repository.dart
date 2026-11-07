import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_identity.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/ids.dart';
import 'earn_models.dart';

final earnRepositoryProvider = Provider<EarnRepository>(
  (ref) => EarnRepository(
    ref.watch(apiClientProvider),
    ref.watch(deviceIdentityProvider),
  ),
);

/// Talks to the campaign and content endpoints of the `02 Mobile` group
/// (`docs/API Docs V2/mobile-api-changes-2026-10-11.md`), plus the stats the
/// earning screens show around them.
///
/// Reward-producing writes carry an `Idempotency-Key` so a retry after a
/// dropped connection cannot credit the user twice.
class EarnRepository {
  EarnRepository(this._api, this._device);

  final ApiClient _api;
  final DeviceIdentity _device;

  // ---------------------------------------------------------------- campaigns

  /// `GET /mobile/campaigns` — paged campaign cards. Only live campaigns the
  /// user may take part in are listed, so one seen earlier can vanish.
  Future<Paged<CampaignCard>> campaigns({int page = 0, int size = 20}) async {
    final data = await _api.get(
      '/mobile/campaigns',
      queryParameters: {'page': page, 'size': size},
    );
    if (data is! Map) return Paged.empty();
    return Paged.fromJson(data.cast<String, dynamic>(), CampaignCard.fromJson);
  }

  /// `GET /mobile/campaigns/featured`.
  Future<List<CampaignCard>> featuredCampaigns() =>
      _cardList('/mobile/campaigns/featured', CampaignCard.fromJson);

  /// `GET /mobile/campaigns/trending`.
  Future<List<CampaignCard>> trendingCampaigns() =>
      _cardList('/mobile/campaigns/trending', CampaignCard.fromJson);

  /// `GET /mobile/campaigns/{id}/items` — the campaign screen: every item
  /// with the user's progress. `404 NOT_FOUND` once the campaign is no longer
  /// live, unless the user already took part.
  Future<CampaignContent> campaignItems(String id) async {
    final data = await _api.get('/mobile/campaigns/$id/items');
    return CampaignContent.fromJson((data as Map).cast<String, dynamic>());
  }

  // ----------------------------------------------------------------- content

  /// `GET /mobile/content/ads` — media-only items from every live campaign,
  /// newest first. [mediaType] narrows it to `IMAGE`, `GIF` or `VIDEO`.
  Future<Paged<ContentItem>> contentAds({
    MediaType? mediaType,
    int page = 0,
    int size = 20,
  }) => _contentPage('/mobile/content/ads', page, size, {
    if (mediaType != null) 'mediaType': mediaType.name.toUpperCase(),
  });

  /// `GET /mobile/content/quizzes` — graded items, standalone quizzes
  /// included.
  Future<Paged<ContentItem>> contentQuizzes({int page = 0, int size = 20}) =>
      _contentPage('/mobile/content/quizzes', page, size);

  /// `GET /mobile/content/surveys` — ungraded items, standalone surveys
  /// included.
  Future<Paged<ContentItem>> contentSurveys({int page = 0, int size = 20}) =>
      _contentPage('/mobile/content/surveys', page, size);

  /// `GET /mobile/content/{id}` — one campaign item with its media and
  /// questions.
  Future<ContentDetail> contentItem(String id) async {
    final data = await _api.get('/mobile/content/$id');
    return ContentDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /mobile/ads/{id}/view`, first call — opens the view when the
  /// media starts. Pays nothing.
  ///
  /// The server times the gap to [completeView]: at least 80% of the item's
  /// `durationSeconds` (less a 2 s grace) must really pass in between.
  Future<AdView> startView({
    required String itemId,
    required String idempotencyKey,
  }) => _postView(itemId, watchedSeconds: 0, idempotencyKey: idempotencyKey);

  /// `POST /mobile/ads/{id}/view`, second call — completes the view once the
  /// media has been watched. A plain ad is paid here; an item with
  /// questions comes back `awaitingAnswers` and is paid by [submitAnswers].
  ///
  /// Too early answers `500 ILLEGAL_STATE` ("Insufficient watch
  /// duration…") and leaves the view started, so the same call can be made
  /// again later — with a fresh [idempotencyKey], or the server would replay
  /// the refusal.
  Future<AdView> completeView({
    required String itemId,
    required int watchedSeconds,
    required String idempotencyKey,
  }) => _postView(
    itemId,
    watchedSeconds: watchedSeconds,
    idempotencyKey: idempotencyKey,
  );

  Future<AdView> _postView(
    String itemId, {
    required int watchedSeconds,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      '/mobile/ads/$itemId/view',
      data: {'watchedDurationSeconds': watchedSeconds, 'deviceId': _device.id},
      idempotencyKey: idempotencyKey,
    );
    return AdView.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /quizzes/submit` (graded) or `POST /surveys/submit` — answers a
  /// campaign item once its view has completed. One submission per item.
  ///
  /// Every question must be answered exactly once, or the server refuses with
  /// `400 INVALID_ANSWER`. Pass the same [idempotencyKey] when retrying one
  /// submission after a dropped connection.
  Future<AdAssessment> submitAnswers({
    required ContentItem item,
    required List<SurveyAnswer> answers,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      item.isSurvey ? '/surveys/submit' : '/quizzes/submit',
      data: {
        'adId': item.id,
        'answers': answers.map((a) => a.toJson()).toList(),
      },
      idempotencyKey: idempotencyKey,
    );
    return AdAssessment.fromJson(
      data is Map ? data.cast<String, dynamic>() : const {},
      passedByDefault: item.isSurvey,
    );
  }

  Future<Paged<ContentItem>> _contentPage(
    String path,
    int page,
    int size, [
    Map<String, dynamic> filters = const {},
  ]) async {
    final data = await _api.get(
      path,
      queryParameters: {...filters, 'page': page, 'size': size},
    );
    if (data is! Map) return Paged.empty();
    return Paged.fromJson(data.cast<String, dynamic>(), ContentItem.fromJson);
  }

  // ------------------------------------------------- standalone quizzes/surveys

  // Listed by the content endpoints above (`source: STANDALONE`); opened and
  // submitted through their own endpoints, with no media and no view step.

  /// `GET /mobile/quizzes/{id}`.
  Future<QuizDetails> quiz(String id) async {
    final data = await _api.get('/mobile/quizzes/$id');
    return QuizDetails.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /mobile/quizzes/{id}/submit`.
  Future<QuizResult> submitQuiz({
    required String quizId,
    required Map<String, String> answers,
  }) async {
    final data = await _api.post(
      '/mobile/quizzes/$quizId/submit',
      data: {
        'answers': [
          for (final entry in answers.entries)
            {'questionId': entry.key, 'optionId': entry.value},
        ],
      },
      idempotencyKey: Ids.newId(),
    );
    return QuizResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `GET /mobile/surveys/{id}`.
  Future<SurveyDetails> survey(String id) async {
    final data = await _api.get('/mobile/surveys/$id');
    return SurveyDetails.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /mobile/surveys/{id}/heartbeat` — holds the concurrency slot open
  /// while the user is answering.
  Future<SurveySlot> surveyHeartbeat(String id) async {
    final data = await _api.post('/mobile/surveys/$id/heartbeat');
    return SurveySlot.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /mobile/surveys/{id}/discard` — releases the slot when the user
  /// abandons the survey, so someone else can take it.
  Future<void> discardSurvey(String id) =>
      _api.post('/mobile/surveys/$id/discard');

  /// `POST /mobile/surveys/{id}/submit`.
  Future<void> submitSurvey({
    required String surveyId,
    required List<SurveyAnswer> answers,
  }) => _api.post(
    '/mobile/surveys/$surveyId/submit',
    data: {'answers': answers.map((a) => a.toJson()).toList()},
    idempotencyKey: Ids.newId(),
  );

  // ------------------------------------------------------------------- stats

  // The "Today's Earning" figure these screens show comes from the wallet
  // feature's `walletEarningsProvider` — it is a wallet endpoint, and the
  // Wallet tab reads it too.

  /// `GET /mobile/rewards/history` — what the user has completed, newest
  /// first. Rewards may sit `PENDING` until fraud validation clears them.
  Future<Paged<RewardHistoryItem>> rewardHistory({
    int page = 0,
    int size = 20,
  }) async {
    final data = await _api.get(
      '/mobile/rewards/history',
      // The server's default order is oldest first.
      queryParameters: {'page': page, 'size': size, 'sort': 'createdAt,desc'},
    );
    if (data is! Map) return Paged.empty();
    return Paged.fromJson(
      data.cast<String, dynamic>(),
      RewardHistoryItem.fromJson,
    );
  }

  /// `GET /mobile/tasks/daily` — today's checklist, behind the completion
  /// ring on the earning tab.
  Future<List<DailyTask>> dailyTasks() =>
      _cardList('/mobile/tasks/daily', DailyTask.fromJson);

  // ------------------------------------------------------------------ shared

  /// Handles both the bare-array and enveloped-list shapes the API mixes.
  Future<List<T>> _cardList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final data = await _api.get(path);
    if (data is! List) return const [];
    return data
        .map((e) => fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
