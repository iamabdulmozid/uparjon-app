import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_identity.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/ids.dart';
import 'earn_models.dart';

final earnRepositoryProvider = Provider<EarnRepository>(
  (ref) => EarnRepository(
    ref.watch(apiClientProvider),
    ref.watch(deviceIdentityProvider),
    ref.watch(localStoreProvider),
  ),
);

/// Talks to the campaign, content and ad-view endpoints
/// (`docs/API Docs V3/document.pdf`, Mobile API changes 2026-11-11), plus
/// the stats the earning screens show around them.
///
/// Reward-producing writes carry an `Idempotency-Key` so a retry after a
/// dropped connection cannot credit the user twice.
class EarnRepository {
  EarnRepository(this._api, this._device, this._store);

  final ApiClient _api;
  final DeviceIdentity _device;
  final LocalStore _store;

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

  // --------------------------------------------------------------- ad views

  // The one way to earn a campaign item (Mobile API changes 2026-11-11 §1):
  // start when the media starts, complete when it ends, answers when the
  // item has questions.

  /// `POST /ad-views/start` — opens a view of item [itemId] (its ad id) when
  /// playback really begins. Pays nothing; the server measures watch time
  /// from this call.
  Future<AdViewSession> startAdView({
    required String itemId,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      '/ad-views/start',
      data: {'adId': itemId, 'deviceId': _device.id},
      idempotencyKey: idempotencyKey,
    );
    return AdViewSession.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /ad-views/{adViewId}/complete` — once the media has been watched.
  /// A plain ad is paid here; an item with questions comes back
  /// `awaitingAnswers` and is paid by [submitAnswers].
  ///
  /// At least 80% of the item's `durationSeconds` must have been watched,
  /// and must really have passed since [startAdView]; otherwise
  /// `500 ILLEGAL_STATE` ("Insufficient watch duration…"). Retry that with a
  /// fresh [idempotencyKey], or the server would replay the refusal.
  Future<AdView> completeAdView({
    required String itemId,
    required String adViewId,
    required int watchedSeconds,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      '/ad-views/$adViewId/complete',
      data: {'watchedDurationSeconds': watchedSeconds},
      idempotencyKey: idempotencyKey,
    );
    final view = AdView.fromJson((data as Map).cast<String, dynamic>());
    // Kept so the answers can still be sent if the user leaves first.
    if (view.awaitingAnswers) {
      await _store.setPendingAdView(itemId, adViewId);
    }
    return view;
  }

  /// The completed view [itemId]'s answers are still owed to, if this
  /// device recorded one.
  String? pendingAdView(String itemId) => _store.pendingAdView(itemId);

  /// `POST /ad-views/{adViewId}/answers` — answers a campaign item once its
  /// view has completed. One submission per item.
  ///
  /// Every question must be answered exactly once, or the server refuses with
  /// `400 INVALID_ANSWER`. Pass the same [idempotencyKey] when retrying one
  /// submission after a dropped connection.
  Future<AdAssessment> submitAnswers({
    required ContentItem item,
    required String adViewId,
    required List<SurveyAnswer> answers,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      '/ad-views/$adViewId/answers',
      data: {'answers': answers.map((a) => a.toJson()).toList()},
      idempotencyKey: idempotencyKey,
    );
    await forgetPendingAdView(item.id);
    return AdAssessment.fromJson(
      data is Map ? data.cast<String, dynamic>() : const {},
      passedByDefault: item.isSurvey,
    );
  }

  /// Drops the kept view once its answers can no longer be sent — answered,
  /// or refused for good.
  Future<void> forgetPendingAdView(String itemId) =>
      _store.clearPendingAdView(itemId);

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

  /// A plain list in `data`. [ApiClient] has already unwrapped the
  /// envelope, which every `/mobile/**` endpoint now sends.
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
