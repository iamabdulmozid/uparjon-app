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

/// Talks to the campaign, ad, quiz and survey endpoints of the `02 Mobile`
/// group, plus the stats the earning screens show around them.
///
/// Reward-producing writes carry an `Idempotency-Key` so a retry after a
/// dropped connection cannot credit the user twice.
class EarnRepository {
  EarnRepository(this._api, this._device);

  final ApiClient _api;
  final DeviceIdentity _device;

  // ---------------------------------------------------------------- campaigns

  /// `GET /mobile/campaigns` — paged campaign cards.
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

  /// `GET /mobile/campaigns/{id}`.
  Future<CampaignDetails> campaign(String id) async {
    final data = await _api.get('/mobile/campaigns/$id');
    return CampaignDetails.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /mobile/campaigns/{id}/start` — opens a campaign session.
  Future<CampaignSession> startCampaign(String id) async {
    final data = await _api.post(
      '/mobile/campaigns/$id/start',
      idempotencyKey: Ids.newId(),
    );
    return CampaignSession.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /mobile/campaigns/{id}/complete` — enters reward/fraud validation.
  ///
  /// A successful completion does not mean the wallet is credited yet; the
  /// reward may sit pending until fraud checks pass.
  Future<CampaignSession> completeCampaign(String id) async {
    final data = await _api.post(
      '/mobile/campaigns/$id/complete',
      idempotencyKey: Ids.newId(),
    );
    return CampaignSession.fromJson((data as Map).cast<String, dynamic>());
  }

  // --------------------------------------------------------------------- ads

  /// `GET /mobile/ads/feed`.
  ///
  /// This endpoint answers with a bare JSON array rather than the usual
  /// `{success, data}` envelope, which [ApiClient] passes straight through.
  Future<List<VideoAd>> adsFeed() =>
      _cardList('/mobile/ads/feed', VideoAd.fromJson);

  /// `GET /ads/{id}` — the full ad, with its type, questions and attempt
  /// rules. The feed card has none of those.
  Future<VideoAd> ad(String id) async {
    final data = await _api.get('/ads/$id');
    return VideoAd.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /mobile/ads/{id}/view` — records the watch.
  ///
  /// For a plain ad this claims the reward. For an ad with questions it only
  /// marks the view `COMPLETED`: that is the prerequisite the answer
  /// submission checks, and the reward comes from [submitAdAnswers].
  Future<AdView> submitAdView({
    required String adId,
    required int watchedSeconds,
    String? idempotencyKey,
  }) async {
    final data = await _api.post(
      '/mobile/ads/$adId/view',
      data: {'watchedDurationSeconds': watchedSeconds, 'deviceId': _device.id},
      idempotencyKey: idempotencyKey ?? Ids.newId(),
    );
    return AdView.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /quizzes/submit` (graded) or `POST /surveys/submit` — answers an
  /// ad's questions once its view is recorded; the server refuses with a
  /// 400 otherwise.
  ///
  /// Both take `QuizSubmissionRequest {adId, answers[{questionId, optionId,
  /// textAnswer}]}` — `textAnswer`, although the integration guide spells it
  /// `answerText`. Pass the same [idempotencyKey] when retrying one attempt.
  Future<AdAssessment> submitAdAnswers({
    required VideoAd ad,
    required List<SurveyAnswer> answers,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      ad.isSurvey ? '/surveys/submit' : '/quizzes/submit',
      data: {
        'adId': ad.adId,
        'answers': answers.map((a) => a.toJson()).toList(),
      },
      idempotencyKey: idempotencyKey,
    );
    return AdAssessment.fromJson(
      data is Map ? data.cast<String, dynamic>() : const {},
      passedByDefault: ad.isSurvey,
    );
  }

  // ----------------------------------------------------------------- quizzes

  /// `GET /mobile/quizzes`.
  Future<List<QuizCard>> quizzes() =>
      _cardList('/mobile/quizzes', QuizCard.fromJson);

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

  // ----------------------------------------------------------------- surveys

  /// `GET /mobile/surveys`.
  Future<List<SurveyCard>> surveys() =>
      _cardList('/mobile/surveys', SurveyCard.fromJson);

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
      queryParameters: {'page': page, 'size': size},
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
