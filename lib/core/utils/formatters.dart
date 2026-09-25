/// Display formatting for money, durations and timestamps.
///
/// Amounts are only ever formatted, never computed — the server owns the maths.
abstract final class Formatters {
  /// "৳10.00" — the taka amount as the API returned it.
  static String taka(num amount) => '৳${amount.toStringAsFixed(2)}';

  /// "16,457.15" — two decimals with thousands separators, for the balance
  /// card. No currency sign; the card draws its own.
  static String grouped(num amount) {
    final text = amount.abs().toStringAsFixed(2);
    final parts = text.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i > 0 && remaining % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    final sign = amount < 0 ? '-' : '';
    return '$sign$buffer.${parts.last}';
  }

  /// "৳16,457.15" — [grouped] with the taka sign, for wallet figures.
  static String takaGrouped(num amount) => '৳${grouped(amount)}';

  /// "+ ৳10.00" for a credit, "- ৳500.00" for a debit. The API signs
  /// withdrawals negative, so the sign comes from the amount itself.
  static String signedTaka(num amount) =>
      '${amount < 0 ? '-' : '+'} ৳${amount.abs().toStringAsFixed(2)}';

  /// "৳ 60" for whole amounts, "৳ 12.50" otherwise (Figma stat cards).
  static String takaCompact(num amount) {
    final isWhole = amount % 1 == 0;
    return '৳ ${isWhole ? amount.toInt() : amount.toStringAsFixed(2)}';
  }

  /// "+ ৳10.00" for a credit, or null when there is nothing to show.
  static String? rewardOrNull(num? amount) =>
      amount == null ? null : '+ ${taka(amount)}';

  /// "04" — counts in the stat cards are always two digits.
  static String twoDigits(int value) => value.abs().toString().padLeft(2, '0');

  /// Rounds seconds into something readable: "45 sec", "3 min", "1 hr 5 min".
  static String duration(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }

  /// "Takes approximate 3 min" — the task card footer copy from Figma.
  static String approxDuration(int seconds) =>
      'Takes approximate ${duration(seconds)}';

  /// "01:32", or "01:02:03" once an hour is reached — the player clock.
  static String clock(Duration value) {
    final hours = value.inHours;
    final minutes = _two(value.inMinutes.remainder(60));
    final seconds = _two(value.inSeconds.remainder(60));
    return hours > 0 ? '${_two(hours)}:$minutes:$seconds' : '$minutes:$seconds';
  }

  /// "11 Jul 26 | 10:10 am" — activity rows, in the device's time zone.
  static String activityTime(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final meridiem = local.hour < 12 ? 'am' : 'pm';
    return '${_two(local.day)} ${months[local.month - 1]} '
        '${_two(local.year % 100)} | ${_two(hour)}:${_two(local.minute)} '
        '$meridiem';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
