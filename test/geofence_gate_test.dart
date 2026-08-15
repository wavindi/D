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
    });

    test(
      'requires outside observation and three confirmed inside readings',
      () {
        final gate = GeofenceGate();
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
      },
    );

    test('boundary jitter resets confirmation instead of starting', () {
      final gate = GeofenceGate();
      gate.confirmEntry(
        distanceMeters: 110,
        radiusMeters: 90,
        accuracyMeters: 5,
      );
      gate.confirmEntry(
        distanceMeters: 70,
        radiusMeters: 90,
        accuracyMeters: 5,
      );
      gate.confirmEntry(
        distanceMeters: 88,
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

    test('requires three outside readings to finish', () {
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

    test('reported accuracy widens the hysteresis margin', () {
      final gate = GeofenceGate();
      gate.confirmEntry(
        distanceMeters: 120,
        radiusMeters: 90,
        accuracyMeters: 40,
      );
      for (var i = 0; i < 4; i++) {
        expect(
          gate.confirmEntry(
            distanceMeters: 75,
            radiusMeters: 90,
            accuracyMeters: 40,
          ),
          isFalse,
        );
      }
    });
  });
}
