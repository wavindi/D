import 'package:d/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDuration', () {
    test('formats hours, minutes, and seconds', () {
      expect(
        formatDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
        '02:03:04',
      );
    });
  });

  group('formatDistance', () {
    test('uses meters below one kilometer', () {
      expect(formatDistance(850), '850 m');
    });

    test('uses kilometers at one kilometer and above', () {
      expect(formatDistance(1534), '1.53 km');
    });
  });
}
