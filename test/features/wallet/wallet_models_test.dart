import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/core/network/paged.dart';
import 'package:uparjon/features/wallet/data/wallet_models.dart';

/// Parses responses captured verbatim from staging (`api.avytor.com`), so a
/// change in what the server actually sends breaks a test rather than the app.
void main() {
  Map<String, dynamic> dataOf(String body) =>
      (jsonDecode(body) as Map<String, dynamic>)['data']
          as Map<String, dynamic>;

  group('WalletOverview', () {
    test('parses the live overview response', () {
      const body = '''
{"success":true,"message":"Wallet overview retrieved successfully",
"data":{"availableBalance":60.0000,"pendingBalance":0.0000,
"lifetimeEarnings":60.0000,"totalWithdrawn":0.0000,"pendingRewards":0,
"completedRewards":0},"timestamp":"2026-09-20T15:13:32.00522965"}''';

      final overview = WalletOverview.fromJson(dataOf(body));

      expect(overview.availableBalance, 60);
      expect(overview.pendingBalance, 0);
      expect(overview.lifetimeEarnings, 60);
      expect(overview.totalWithdrawn, 0);
    });

    test('reads the home feed block, which omits the last three fields', () {
      final overview = WalletOverview.fromJson({
        'availableBalance': 30.0,
        'pendingBalance': 0.0,
        'lifetimeEarnings': 30.0,
      });

      expect(overview.availableBalance, 30);
      expect(overview.totalWithdrawn, 0);
      expect(overview.completedRewards, 0);
    });

    test('falls back to the field names in the API specification', () {
      // The spec document calls these `balance` and `pendingAmount`.
      final overview = WalletOverview.fromJson({
        'balance': 14250.60,
        'pendingAmount': 250.00,
      });

      expect(overview.availableBalance, 14250.60);
      expect(overview.pendingBalance, 250.00);
    });
  });

  group('WalletTransaction', () {
    const liveTransactions = '''
{"success":true,"message":"Transaction history retrieved successfully",
"data":{"content":[
{"id":"727f04ea-00ba-46c9-a7f4-c1fab95440eb","type":"BONUS","amount":30.0000,
"status":"COMPLETED","description":"Completed Survey: National Consumer Digital Financial Habits Survey 2026-2028 [Updated] 17897941198473658",
"createdAt":"2026-09-20T14:26:05.417647"}],
"empty":false,"first":true,"last":true,"number":0,"numberOfElements":1,
"pageable":{"offset":0,"pageNumber":0,"pageSize":20,"paged":true},
"size":20,"totalElements":1,"totalPages":1},
"timestamp":"2026-09-20T15:13:32.823337648"}''';

    test('parses the live paged ledger', () {
      final page = Paged.fromJson(
        dataOf(liveTransactions),
        WalletTransaction.fromJson,
      );

      expect(page.items, hasLength(1));
      expect(page.totalElements, 1);
      expect(page.hasMore, isFalse);

      final row = page.items.single;
      expect(row.amount, 30);
      expect(row.type, 'BONUS');
      expect(row.isDebit, isFalse);
      expect(row.isPending, isFalse);
      expect(row.createdAt, DateTime.parse('2026-09-20T14:26:05.417647'));
    });

    test('recognises a survey payout the API books as a BONUS', () {
      // There is no category field; the description is the only signal, and
      // surveys are what the live account has actually earned from.
      final page = Paged.fromJson(
        dataOf(liveTransactions),
        WalletTransaction.fromJson,
      );

      expect(page.items.single.kind, WalletActivityKind.survey);
    });

    test('classifies every earning type and the payout', () {
      WalletActivityKind kindOf(String type, String description) =>
          WalletTransaction.fromJson({
            'type': type,
            'description': description,
          }).kind;

      expect(
        kindOf('REWARD', 'Ad Reward: Grameenphone 5G Promo'),
        WalletActivityKind.ad,
      );
      expect(
        kindOf('REWARD', 'Quiz Reward: Daily General Knowledge'),
        WalletActivityKind.quiz,
      );
      expect(
        kindOf('REWARD', 'Campaign Reward: Summer Referral Drive'),
        WalletActivityKind.campaign,
      );
      expect(
        kindOf('WITHDRAWAL', 'Payout to bKash (017******78)'),
        WalletActivityKind.withdrawal,
      );
      // A withdrawal wins on type even when the text mentions an ad, and an
      // unrecognisable description falls back rather than guessing.
      expect(
        kindOf('WITHDRAWAL', 'Payout: ad revenue share'),
        WalletActivityKind.withdrawal,
      );
      expect(kindOf('ADMIN_ADJUSTMENT', 'Goodwill credit'),
          WalletActivityKind.other);
    });

    test('keeps the sign the API puts on a withdrawal', () {
      final row = WalletTransaction.fromJson({
        'type': 'WITHDRAWAL',
        'amount': -500.00,
        'status': 'COMPLETED',
        'description': 'Payout to bKash (017******78)',
      });

      expect(row.isDebit, isTrue);
      expect(row.amount, -500);
    });
  });

  group('EarningsSummary', () {
    test('parses the live summary, where only lifetime has moved', () {
      const body = '''
{"success":true,"message":"Earnings summary retrieved successfully",
"data":{"today":0,"thisWeek":0,"thisMonth":0,"lifetime":30.0000},
"timestamp":"2026-09-20T15:00:25.586127756"}''';

      final summary = EarningsSummary.fromJson(dataOf(body));

      expect(summary.today, 0);
      expect(summary.lifetime, 30);
    });
  });

  group('WalletInsights', () {
    test('keeps the "N/A" the API sends for a user with no history', () {
      const body = '''
{"success":true,"message":"Wallet insights retrieved successfully",
"data":{"highestEarningDay":"N/A","highestEarningAmount":0,"adsCompleted":0,
"averageDailyReward":0},"timestamp":"2026-09-20T15:00:43.848367692"}''';

      final insights = WalletInsights.fromJson(dataOf(body));

      expect(insights.highestEarningDay, 'N/A');
      expect(insights.adsCompleted, 0);
    });
  });
}
