import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import 'wallet_models.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.watch(apiClientProvider)),
);

/// Talks to the `/mobile/wallet` endpoints — the balance the home card shows,
/// the ledger behind Recent Activity, and the earning totals the task lists
/// put in their stat cards.
class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  /// `GET /mobile/wallet/overview` — available, pending, lifetime, withdrawn.
  Future<WalletOverview> overview() async {
    final data = await _api.get('/mobile/wallet/overview');
    return WalletOverview.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `GET /mobile/wallet/transactions` — newest first.
  ///
  /// [type] filters to `REWARD`, `BONUS`, `WITHDRAWAL` or
  /// `ADMIN_ADJUSTMENT`; omit it for everything.
  Future<Paged<WalletTransaction>> transactions({
    int page = 0,
    int size = 20,
    String? type,
  }) async {
    final data = await _api.get(
      '/mobile/wallet/transactions',
      queryParameters: {'page': page, 'size': size, 'type': ?type},
    );
    if (data is! Map) return Paged.empty();
    return Paged.fromJson(
      data.cast<String, dynamic>(),
      WalletTransaction.fromJson,
    );
  }

  /// `GET /mobile/wallet/earnings-summary` — today / week / month / lifetime.
  Future<EarningsSummary> earningsSummary() async {
    final data = await _api.get('/mobile/wallet/earnings-summary');
    return EarningsSummary.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `GET /mobile/wallet/insights` — best day, ads completed, daily average.
  Future<WalletInsights> insights() async {
    final data = await _api.get('/mobile/wallet/insights');
    return WalletInsights.fromJson((data as Map).cast<String, dynamic>());
  }
}
