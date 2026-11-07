/// Timestamps from the API.
abstract final class ServerTime {
  static final RegExp _zone = RegExp(r'(?:[Zz]|[+-]\d{2}:?\d{2})$');

  /// Parses an API timestamp into local time.
  ///
  /// The API writes UTC without a zone (`2026-10-01T18:45:27.554528`), which
  /// `DateTime.parse` would read as local time — six hours early in
  /// Bangladesh. A value that does carry a zone keeps it.
  static DateTime? parse(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (_zone.hasMatch(text)) return DateTime.tryParse(text)?.toLocal();
    // A bare date has no time to put a zone on.
    return (DateTime.tryParse('${text}Z') ?? DateTime.tryParse(text))
        ?.toLocal();
  }
}
