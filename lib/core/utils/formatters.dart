/// Display formatting for money and durations.
///
/// Amounts are only ever formatted, never computed — the server owns the maths.
abstract final class Formatters {
  /// "৳10.00" — the taka amount as the API returned it.
  static String taka(num amount) => '৳${amount.toStringAsFixed(2)}';

  /// "+ ৳10.00" for a credit, or null when there is nothing to show.
  static String? rewardOrNull(num? amount) =>
      amount == null ? null : '+ ${taka(amount)}';

  /// Rounds seconds into something readable: "45 sec", "3 min", "1 hr 5 min".
  static String duration(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }
}
