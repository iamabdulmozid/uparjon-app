import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/core/utils/server_time.dart';

void main() {
  // `DateTime ==` also compares the UTC flag, so moments are compared with
  // `isAtSameMomentAs`.
  void expectMoment(DateTime? actual, DateTime expected) {
    expect(actual, isNotNull);
    expect(actual!.isUtc, isFalse, reason: 'returned in local time');
    expect(actual.isAtSameMomentAs(expected), isTrue, reason: '$actual');
  }

  test('a zone-less timestamp is read as UTC', () {
    expectMoment(
      ServerTime.parse('2026-10-01T18:45:27.554528'),
      DateTime.utc(2026, 10, 1, 18, 45, 27, 554, 528),
    );
  });

  test('a timestamp with a zone keeps it', () {
    expectMoment(
      ServerTime.parse('2026-10-02T00:45:27+06:00'),
      DateTime.utc(2026, 10, 1, 18, 45, 27),
    );
    expectMoment(
      ServerTime.parse('2026-10-01T18:45:27Z'),
      DateTime.utc(2026, 10, 1, 18, 45, 27),
    );
  });

  test('blank or malformed values are null', () {
    expect(ServerTime.parse(null), isNull);
    expect(ServerTime.parse(''), isNull);
    expect(ServerTime.parse('N/A'), isNull);
  });
}
