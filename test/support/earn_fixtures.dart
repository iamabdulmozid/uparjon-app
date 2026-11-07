import 'fake_api.dart';

/// A `MobileContentItemDto` — what the Ads, Quiz and Survey lists and the
/// campaign screen return. Defaults describe a plain video ad.
Map<String, dynamic> contentItem({
  String id = 'ad-1',
  String kind = 'AD',
  String source = 'CAMPAIGN',
  String title = 'Regal Furniture',
  String? mediaType = 'VIDEO',
  String? mediaUrl = 'https://cdn.test/regal.mp4',
  int durationSeconds = 3,
  num reward = 10,
  int questionCount = 0,
  int? passingScore,
  bool paysPerQuestion = false,
  String progress = 'NOT_STARTED',
  bool available = true,
  String? unavailableCode,
  String? unavailableMessage,
}) => {
  'id': id,
  'kind': kind,
  'source': source,
  'title': title,
  'description': null,
  'mediaType': mediaType,
  'mediaUrl': mediaUrl,
  'thumbnailUrl': null,
  'durationSeconds': durationSeconds,
  'reward': reward,
  'paysPerQuestion': paysPerQuestion,
  'questionCount': questionCount,
  'passingScore': passingScore,
  'progress': progress,
  'available': available,
  'unavailableCode': unavailableCode,
  'unavailableMessage': unavailableMessage,
  'campaignId': source == 'CAMPAIGN' ? 'c-1' : null,
  'campaignTitle': source == 'CAMPAIGN' ? 'Kitchen week' : null,
  'campaignBannerUrl': null,
  'campaignEndAt': null,
};

/// Everything the earning screens read on the way to a task, so a test only
/// has to add the endpoints it is about.
Map<String, FakeReply> earnRoutes({
  List<Map<String, dynamic>> ads = const [],
  List<Map<String, dynamic>> quizzes = const [],
  List<Map<String, dynamic>> surveys = const [],
  List<Map<String, dynamic>> campaigns = const [],
  List<Map<String, dynamic>> rewards = const [],
  List<Map<String, dynamic>> dailyTasks = const [],
  num today = 0,
}) => {
  'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
  'GET /mobile/content/ads': ok(springPage(ads)),
  'GET /mobile/content/quizzes': ok(springPage(quizzes)),
  'GET /mobile/content/surveys': ok(springPage(surveys)),
  'GET /mobile/campaigns': ok(springPage(campaigns)),
  'GET /mobile/rewards/history': ok(springPage(rewards)),
  'GET /mobile/tasks/daily': ok(dailyTasks),
  'GET /mobile/wallet/earnings-summary': ok({
    'today': today,
    'thisWeek': today,
    'thisMonth': today,
    'lifetime': today,
  }),
};
