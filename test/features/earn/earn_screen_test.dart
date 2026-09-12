import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/earn/presentation/earn_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

/// A page of campaign cards, shaped like Spring's `Page`.
Map<String, dynamic> campaignPage(List<Map<String, dynamic>> items) => {
  'content': items,
  'number': 0,
  'size': 20,
  'totalElements': items.length,
  'totalPages': items.isEmpty ? 0 : 1,
  'first': true,
  'last': true,
  'empty': items.isEmpty,
};

FakeApi earnApi({
  List<Map<String, dynamic>> ads = const [],
  List<Map<String, dynamic>> surveys = const [],
  List<Map<String, dynamic>> quizzes = const [],
  List<Map<String, dynamic>> campaigns = const [],
}) => FakeApi({
  'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
  // The ads and quiz feeds answer with a bare array, not the envelope.
  'GET /mobile/ads/feed': rawJson(ads),
  'GET /mobile/quizzes': rawJson(quizzes),
  'GET /mobile/surveys': rawJson(surveys),
  'GET /mobile/campaigns': ok(campaignPage(campaigns)),
});

void main() {
  Future<void> openEarn(WidgetTester tester, FakeApi api) async {
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
    await tester.tap(find.text('Uparjon').last);
    await tester.pumpAndSettle();
    expect(find.byType(EarnScreen), findsOneWidget);
  }

  testWidgets('shows a tab per earning type', (tester) async {
    await openEarn(tester, earnApi());

    expect(find.text('Ads'), findsOneWidget);
    expect(find.text('Surveys'), findsOneWidget);
    expect(find.text('Quizzes'), findsOneWidget);
    expect(find.text('Campaigns'), findsOneWidget);
  });

  testWidgets('lists ads with their duration and reward', (tester) async {
    await openEarn(
      tester,
      earnApi(
        ads: [
          {
            'adId': 'ad-1',
            'title': 'Regal Furniture Up to 15% Off',
            'duration': 180,
            'reward': 10,
          },
        ],
      ),
    );

    expect(find.text('Regal Furniture Up to 15% Off'), findsOneWidget);
    expect(find.text('Takes approximately 3 min'), findsOneWidget);
    expect(find.text('+ ৳10.00'), findsOneWidget);
  });

  testWidgets('an empty feed explains itself instead of showing nothing', (
    tester,
  ) async {
    await openEarn(tester, earnApi());

    expect(find.textContaining('No ads available right now'), findsOneWidget);
  });

  testWidgets('each tab loads independently of the others', (tester) async {
    final api = earnApi(
      surveys: [
        {
          'id': 's-1',
          'title': 'A survey on popular foods',
          'questionCount': 10,
          'rewardAmount': 25,
          'estimatedSeconds': 300,
        },
      ],
    );
    // Ads fail; surveys must still render.
    api.routes['GET /mobile/ads/feed'] = apiError(
      'INTERNAL_SERVER_ERROR',
      status: 500,
    );
    await openEarn(tester, api);

    await tester.tap(find.text('Surveys'));
    await tester.pumpAndSettle();

    expect(find.text('A survey on popular foods'), findsOneWidget);
    expect(find.text('10 questions · 5 min'), findsOneWidget);
    expect(find.text('+ ৳25.00'), findsOneWidget);
  });

  testWidgets('campaigns come from the paged endpoint', (tester) async {
    await openEarn(
      tester,
      earnApi(
        campaigns: [
          {
            'id': 'c-1',
            'title': 'Install and try our app',
            'campaignType': 'INSTALL',
            'rewardAmount': 50,
            'estimatedSeconds': 120,
          },
        ],
      ),
    );

    await tester.tap(find.text('Campaigns'));
    await tester.pumpAndSettle();

    expect(find.text('Install and try our app'), findsOneWidget);
    expect(find.text('INSTALL · 2 min'), findsOneWidget);
  });
}
