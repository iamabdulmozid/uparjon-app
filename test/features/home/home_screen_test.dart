import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/core/constants/app_assets.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/home/presentation/home_screen.dart';
import 'package:uparjon/core/ui/balance_card.dart';
import 'package:uparjon/features/home/presentation/widgets/module_tiles.dart';
import 'package:uparjon/features/home/presentation/widgets/promo_banner.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';
import '../../support/wallet_fixtures.dart';

void main() {
  /// Home sits behind the auth guard, so the test needs a restorable session.
  Future<void> openHome(
    WidgetTester tester, {
    num available = 16457.15,
    num pending = 0,
    List<Map<String, dynamic>> transactions = const [],
    FakeReply? transactionsReply,
  }) async {
    final api = FakeApi({
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
      'GET /mobile/wallet/overview': ok(
        walletOverview(available: available, pending: pending),
      ),
      'GET /mobile/wallet/transactions':
          transactionsReply ?? ok(springPage(transactions)),
    });
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
  }

  testWidgets('renders the dashboard and its bottom navigation', (
    tester,
  ) async {
    await openHome(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(BalanceCard), findsOneWidget);
    expect(find.byType(ModuleTiles), findsOneWidget);
    expect(find.byType(PromoBanner), findsOneWidget);

    expect(find.text('Freelance'), findsOneWidget);
    expect(find.text('e-Commerce'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    // Nav labels ("Uparjon" also appears as a module tile).
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('the balance card shows the wallet balance from the API', (
    tester,
  ) async {
    await openHome(tester, available: 16457.15);

    expect(find.text('৳ 16,457.15'), findsOneWidget);
  });

  testWidgets('a held reward is called out under the balance', (tester) async {
    await openHome(tester, available: 30, pending: 250.5);

    expect(find.text('৳ 30.00'), findsOneWidget);
    expect(find.text('৳250.50 pending'), findsOneWidget);
  });

  testWidgets('no pending line when nothing is held', (tester) async {
    await openHome(tester, available: 30);

    expect(find.textContaining('pending'), findsNothing);
  });

  testWidgets('hides the balance when toggled', (tester) async {
    await openHome(tester, available: 16457.15);

    expect(find.text('৳ 16,457.15'), findsOneWidget);

    await tester.tap(find.text('Hide balance'));
    await tester.pumpAndSettle();

    expect(find.text('৳ 16,457.15'), findsNothing);
    expect(find.text('Show balance'), findsOneWidget);
  });

  testWidgets('recent activity comes from the wallet ledger', (tester) async {
    await openHome(
      tester,
      transactions: [surveyBonus, adReward, withdrawal, quizReward],
    );

    // Titles are derived from the ledger row, not the server's long
    // description.
    expect(find.text('Survey'), findsOneWidget);
    expect(find.text('Video Ad'), findsOneWidget);
    expect(find.text('Withdrawal'), findsOneWidget);
    expect(find.text('+ ৳30.00'), findsOneWidget);
    expect(find.text('+ ৳20.00'), findsOneWidget);
    expect(find.text('- ৳500.00'), findsOneWidget);

    // Home shows three rows; the rest belong to the Wallet tab.
    expect(find.text('Quiz'), findsNothing);
  });

  testWidgets('an empty ledger explains itself instead of showing nothing', (
    tester,
  ) async {
    await openHome(tester);

    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('a failing ledger degrades to a retry, keeping the balance', (
    tester,
  ) async {
    await openHome(
      tester,
      available: 30,
      transactionsReply: apiError('SERVER_ERROR', status: 500),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('৳ 30.00'), findsOneWidget);
  });

  testWidgets('the withdraw pill hugs its label instead of filling the card', (
    tester,
  ) async {
    await openHome(tester);

    final pill = find.ancestor(
      of: find.text('Withdraw'),
      matching: find.byType(Container),
    );
    final width = tester.getSize(pill.first).width;

    // The balance card is ~380 wide; the design pill is ~110.
    expect(width, lessThan(200));
  });

  testWidgets('the balance card carries the money bag artwork', (tester) async {
    await openHome(tester);

    final bag = find.byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          w.bytesLoader is SvgAssetLoader &&
          (w.bytesLoader as SvgAssetLoader).assetName == AppAssets.moneyBag,
    );
    expect(bag, findsOneWidget);
  });
}
