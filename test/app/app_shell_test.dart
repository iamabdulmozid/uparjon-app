import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/earn/presentation/earn_screen.dart';
import 'package:uparjon/features/home/presentation/home_screen.dart';
import 'package:uparjon/features/menu/presentation/menu_screen.dart';
import 'package:uparjon/features/wallet/presentation/wallet_screen.dart';

import '../support/fake_api.dart';
import '../support/pump_app.dart';

void main() {
  /// Home sits behind the auth guard, so the test needs a restorable session.
  Future<void> openShell(WidgetTester tester) async {
    final api = FakeApi({
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
    });
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
  }

  testWidgets('opens on the home tab', (tester) async {
    await openShell(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(EarnScreen), findsNothing);
  });

  testWidgets('each bottom nav tab shows its own page', (tester) async {
    await openShell(tester);

    await tester.tap(find.text('Uparjon').last);
    await tester.pumpAndSettle();
    expect(find.byType(EarnScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuScreen), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('home keeps its state when returning from another tab', (
    tester,
  ) async {
    await openShell(tester);

    await tester.tap(find.text('Hide balance'));
    await tester.pumpAndSettle();
    expect(find.text('Show balance'), findsOneWidget);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // IndexedStack keeps the tab alive, so the toggle is still hidden.
    expect(find.text('Show balance'), findsOneWidget);
  });
}
