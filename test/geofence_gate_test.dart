import 'package:d/features/racer/application/geofence_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeofenceGate', () {
    test('does not start when armed inside the zone', () {
      final gate = GeofenceGate();
      for (var i = 0; i < 5; i++) {
        expect(
          gate.confirmEntry(
            distanceMeters: 20,
            radiusMeters: 90,
            accuracyMeters: 5,
          ),
          isFalse,
        );
      }
      expect(gate.hasSeenOutside, isFalse);
    });

    test('requires three outside then three inside readings', () {
      final gate = GeofenceGate();
      for (var i = 0; i < 2; i++) {
        expect(
          gate.confirmEntry(
            distanceMeters: 110,
            radiusMeters: 90,
            accuracyMeters: 5,
          ),
          isFalse,
        );
        expect(gate.hasSeenOutside, isFalse);
      }
      expect(
        gate.confirmEntry(
          distanceMeters: 110,
          radiusMeters: 90,
          accuracyMeters: 5,
        ),
        isFalse,
      );
      expect(gate.hasSeenOutside, isTrue);

      for (var i = 0; i < 2; i++) {
        expect(
          gate.confirmEntry(
            distanceMeters: 70,
            radiusMeters: 90,
            accuracyMeters: 5,
          ),
          isFalse,
        );
      }
      expect(
        gate.confirmEntry(
          distanceMeters: 70,
          radiusMeters: 90,
          accuracyMeters: 5,
        ),
        isTrue,
      );
    });

    test('boundary jitter resets consecutive confirmation', () {
      final gate = GeofenceGate();
      for (var i = 0; i < 3; i++) {
        gate.confirmEntry(
          distanceMeters: 110,
          radiusMeters: 90,
          accuracyMeters: 5,
        );
      }
      gate.confirmEntry(
        distanceMeters: 70,
        radiusMeters: 90,
        accuracyMeters: 5,
      );
      gate.confirmEntry(
        distanceMeters: 90,
        radiusMeters: 90,
        accuracyMeters: 5,
      );
      expect(
        gate.confirmEntry(
          distanceMeters: 70,
          radiusMeters: 90,
          accuracyMeters: 5,
        ),
        isFalse,
      );
    });

    test('requires three definite outside readings to finish', () {
      final gate = GeofenceGate();
      for (var i = 0; i < 2; i++) {
        expect(
          gate.confirmExit(
            distanceMeters: 110,
            radiusMeters: 90,
            accuracyMeters: 5,
          ),
          isFalse,
        );
      }
      expect(
        gate.confirmExit(
          distanceMeters: 110,
          radiusMeters: 90,
          accuracyMeters: 5,
        ),
        isTrue,
      );
    });

    test('full reported accuracy must clear the hysteresis band', () {
      final gate = GeofenceGate();
      for (var i = 0; i < 4; i++) {
        gate.confirmEntry(
          distanceMeters: 120,
          radiusMeters: 90,
          accuracyMeters: 40,
        );
      }
      expect(gate.hasSeenOutside, isFalse);
      for (var i = 0; i < 4; i++) {
        expect(
          gate.confirmExit(
            distanceMeters: 120,
            radiusMeters: 90,
            accuracyMeters: 40,
          ),
          isFalse,
        );
      }
    });

    test('rejects non-finite or negative accuracy values', () {
      final gate = GeofenceGate();
      expect(
        gate.confirmEntry(
          distanceMeters: 110,
          radiusMeters: 90,
          accuracyMeters: -1,
        ),
        isFalse,
      );
      expect(
        gate.confirmExit(
          distanceMeters: double.nan,
          radiusMeters: 90,
          accuracyMeters: 5,
        ),
        isFalse,
      );
    });
  });
}
