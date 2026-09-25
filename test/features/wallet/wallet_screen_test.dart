import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/core/ui/balance_card.dart';
import 'package:uparjon/features/wallet/presentation/wallet_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';
import '../../support/wallet_fixtures.dart';

void main() {
  FakeApi walletApi({
    num available = 0,
    num pending = 0,
    num lifetime = 0,
    num withdrawn = 0,
    num today = 0,
    num week = 0,
    num month = 0,
    List<Map<String, dynamic>> transactions = const [],
    int? totalTransactions,
    FakeReply? overviewReply,
  }) => FakeApi({
    'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
    'GET /mobile/wallet/overview':
        overviewReply ??
        ok(
          walletOverview(
            available: available,
            pending: pending,
            lifetime: lifetime,
            withdrawn: withdrawn,
          ),
        ),
    'GET /mobile/wallet/earnings-summary': ok(
      earningsSummary(today: today, week: week, month: month),
    ),
    'GET /mobile/wallet/transactions': ok(
      springPage(transactions, totalElements: totalTransactions),
    ),
  });

  /// The wallet tab only builds once it is selected, so its feeds stay idle
  /// until the user goes there.
  Future<void> openWallet(WidgetTester tester, FakeApi api) async {
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget);
  }

  testWidgets('shows the balance, what it is made of, and the earnings', (
    tester,
  ) async {
    await openWallet(
      tester,
      walletApi(
        available: 1250.5,
        lifetime: 4000,
        withdrawn: 2749.5,
        today: 30,
        week: 120,
        month: 450,
      ),
    );

    expect(find.byType(BalanceCard), findsOneWidget);
    expect(find.text('৳ 1,250.50'), findsOneWidget);
    expect(find.text('৳4,000.00'), findsOneWidget);
    expect(find.text('৳2,749.50'), findsOneWidget);

    expect(find.text('৳ 30'), findsOneWidget);
    expect(find.text('৳ 120'), findsOneWidget);
    expect(find.text('৳ 450'), findsOneWidget);
  });

  testWidgets('lists the ledger with each row labelled by what earned it', (
    tester,
  ) async {
    await openWallet(
      tester,
      walletApi(
        available: 30,
        transactions: [surveyBonus, adReward, quizReward, withdrawal],
      ),
    );

    expect(find.text('Survey'), findsOneWidget);
    expect(find.text('Video Ad'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Withdrawal'), findsOneWidget);

    // Credits and the one debit, signed the way the API signed them.
    expect(find.text('+ ৳30.00'), findsOneWidget);
    expect(find.text('+ ৳20.00'), findsOneWidget);
    expect(find.text('+ ৳5.00'), findsOneWidget);
    expect(find.text('- ৳500.00'), findsOneWidget);
  });

  testWidgets('a held reward reads as pending, not as money in hand', (
    tester,
  ) async {
    await openWallet(
      tester,
      walletApi(available: 30, pending: 15, transactions: [pendingReward]),
    );

    expect(find.text('৳15.00 pending'), findsOneWidget);
    expect(find.text('Pending verification'), findsOneWidget);
  });

  testWidgets('Load more asks the API for a longer page', (tester) async {
    final api = walletApi(
      available: 30,
      transactions: [surveyBonus, adReward],
      totalTransactions: 40,
    );
    await openWallet(tester, api);

    expect(find.text('Load more'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    final sizes = api.calls
        .where((c) => c.path == '/mobile/wallet/transactions')
        .map((c) => c.queryParameters['size'])
        .toList();
    expect(sizes, contains(40));
  });

  testWidgets('an empty ledger explains itself', (tester) async {
    await openWallet(tester, walletApi());

    expect(find.textContaining('No transactions yet'), findsOneWidget);
  });

  testWidgets('a failing balance offers a retry without blanking the tab', (
    tester,
  ) async {
    await openWallet(
      tester,
      walletApi(
        transactions: [adReward],
        overviewReply: apiError('SERVER_ERROR', status: 500),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    // The ledger has its own provider, so it still rendered.
    expect(find.text('Video Ad'), findsOneWidget);
  });
}
