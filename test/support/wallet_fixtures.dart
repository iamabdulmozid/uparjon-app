/// Wallet payloads shaped like the ones staging returns, so the tests fail
/// when the app stops understanding the real API rather than a tidied-up
/// version of it.
library;

/// `GET /mobile/wallet/overview`.
Map<String, dynamic> walletOverview({
  num available = 0,
  num pending = 0,
  num lifetime = 0,
  num withdrawn = 0,
}) => {
  'availableBalance': available,
  'pendingBalance': pending,
  'lifetimeEarnings': lifetime,
  'totalWithdrawn': withdrawn,
  'pendingRewards': 0,
  'completedRewards': 0,
};

/// `GET /mobile/wallet/earnings-summary`.
Map<String, dynamic> earningsSummary({
  num today = 0,
  num week = 0,
  num month = 0,
  num lifetime = 0,
}) => {
  'today': today,
  'thisWeek': week,
  'thisMonth': month,
  'lifetime': lifetime,
};

/// A survey payout. The API books these as `BONUS`, and the only clue to what
/// earned it is the description — there is no category field.
const surveyBonus = {
  'id': 't-survey',
  'type': 'BONUS',
  'amount': 30.0,
  'status': 'COMPLETED',
  'description':
      'Completed Survey: National Consumer Digital Financial Habits '
      'Survey 2026-2028 [Updated] 17897941198473658',
  'createdAt': '2026-09-20T14:26:05.417647',
};

const adReward = {
  'id': 't-ad',
  'type': 'REWARD',
  'amount': 20.0,
  'status': 'COMPLETED',
  'description': 'Ad Reward: Grameenphone 5G Fiber Broadband Mega Promo',
  'createdAt': '2026-09-19T10:10:00',
};

/// Withdrawals arrive with a negative amount.
const withdrawal = {
  'id': 't-withdrawal',
  'type': 'WITHDRAWAL',
  'amount': -500.0,
  'status': 'COMPLETED',
  'description': 'Payout to bKash (017******78)',
  'createdAt': '2026-09-18T11:15:00',
};

const quizReward = {
  'id': 't-quiz',
  'type': 'REWARD',
  'amount': 5.0,
  'status': 'COMPLETED',
  'description': 'Quiz Reward: Daily General Knowledge',
  'createdAt': '2026-09-17T09:02:00',
};

/// Earned but still held by fraud validation.
const pendingReward = {
  'id': 't-pending',
  'type': 'REWARD',
  'amount': 15.0,
  'status': 'PENDING',
  'description': 'Campaign Reward: Summer Referral Drive',
  'createdAt': '2026-09-20T15:00:00',
};
