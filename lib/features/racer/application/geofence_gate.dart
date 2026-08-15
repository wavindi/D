import 'dart:math' as math;

/// Converts noisy distance readings into confirmed geofence transitions.
/// A race can only start after an outside reading followed by consecutive
/// inside readings. Finishing likewise requires consecutive outside readings.
class GeofenceGate {
  GeofenceGate({this.confirmations = 3, this.minimumMarginMeters = 10});

  final int confirmations;
  final double minimumMarginMeters;
  bool _seenOutside = false;
  int _insideCount = 0;
  int _outsideCount = 0;

  bool get hasSeenOutside => _seenOutside;

  void reset() {
    _seenOutside = false;
    _insideCount = 0;
    _outsideCount = 0;
  }

  bool confirmEntry({
    required double distanceMeters,
    required double radiusMeters,
    required double accuracyMeters,
  }) {
    final margin = math.max(minimumMarginMeters, accuracyMeters * .5);
    if (distanceMeters >= radiusMeters + margin) {
      _seenOutside = true;
      _insideCount = 0;
      return false;
    }
    if (!_seenOutside || distanceMeters > radiusMeters - margin) {
      _insideCount = 0;
      return false;
    }
    _insideCount++;
    return _insideCount >= confirmations;
  }

  bool confirmExit({
    required double distanceMeters,
    required double radiusMeters,
    required double accuracyMeters,
  }) {
    final margin = math.max(minimumMarginMeters, accuracyMeters * .5);
    if (distanceMeters <= radiusMeters + margin) {
      _outsideCount = 0;
      return false;
    }
    _outsideCount++;
    return _outsideCount >= confirmations;
  }
}
