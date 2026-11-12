/// Timestamps from the API.
abstract final class ServerTime {
  static final RegExp _zone = RegExp(r'(?:[Zz]|[+-]\d{2}:?\d{2})$');

  /// The server's wall clock: Asia/Dhaka, which has no daylight saving.
  static const String _dhakaOffset = '+06:00';

  /// Parses an API timestamp into local time.
  ///
  /// The API writes almost every timestamp without an offset
  /// (`2026-11-11T14:30:00`), and that is **Asia/Dhaka** wall-clock time
  /// (Mobile API changes 2026-11-11 §7) — not UTC, and not whatever zone the
  /// device is in. `DateTime.parse` alone would read it as device-local
  /// time. Campaign dates (`startAt`, `endAt`, `campaignEndAt`) carry a `Z`
  /// and keep it.
  static DateTime? parse(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (_zone.hasMatch(text)) return DateTime.tryParse(text)?.toLocal();
    // A bare date has no time to put an offset on.
    return (DateTime.tryParse('$text$_dhakaOffset') ?? DateTime.tryParse(text))
        ?.toLocal();
  }
}
