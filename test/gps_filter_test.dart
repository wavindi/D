import 'package:d/core/utils/gps_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPlausibleGpsStep', () {
    test('accepts highway travel when updates arrive three seconds apart', () {
      expect(
        isPlausibleGpsStep(
          distanceMeters: 84,
          elapsed: const Duration(seconds: 3),
          previousSpeedKmh: 100,
          currentSpeedMps: 100 / 3.6,
          previousAccuracyMeters: 5,
          currentAccuracyMeters: 5,
        ),
        isTrue,
      );
    });

    test('keeps the minimum allowance for frequent low-speed updates', () {
      expect(
        isPlausibleGpsStep(
          distanceMeters: 80,
          elapsed: const Duration(seconds: 1),
          previousSpeedKmh: 0,
          currentSpeedMps: 0,
          previousAccuracyMeters: 5,
          currentAccuracyMeters: 5,
        ),
        isTrue,
      );
    });

    test('rejects an implausible GPS teleport', () {
      expect(
        isPlausibleGpsStep(
          distanceMeters: 500,
          elapsed: const Duration(seconds: 2),
          previousSpeedKmh: 100,
          currentSpeedMps: 100 / 3.6,
          previousAccuracyMeters: 5,
          currentAccuracyMeters: 5,
        ),
        isFalse,
      );
    });
  });
}
