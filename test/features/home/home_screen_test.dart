import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/core/constants/app_assets.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/home/presentation/home_screen.dart';
import 'package:uparjon/features/home/presentation/widgets/balance_card.dart';
import 'package:uparjon/features/home/presentation/widgets/module_tiles.dart';
import 'package:uparjon/features/home/presentation/widgets/promo_banner.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

void main() {
  /// Home sits behind the auth guard, so the test needs a restorable session.
  Future<void> openHome(WidgetTester tester) async {
    final api = FakeApi({
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
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

  testWidgets('hides the balance when toggled', (tester) async {
    await openHome(tester);

    expect(find.text('৳ 16,457.15'), findsOneWidget);

    await tester.tap(find.text('Hide balance'));
    await tester.pumpAndSettle();

    expect(find.text('৳ 16,457.15'), findsNothing);
    expect(find.text('Show balance'), findsOneWidget);
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
