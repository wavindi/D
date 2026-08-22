/// Converts noisy GPS distance readings into confirmed geofence transitions.
/// A race can only start after consecutive definite outside readings followed
/// by consecutive definite inside readings. Accuracy-overlapping readings reset
/// confirmation so a single noisy fix cannot start or finish a race.
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
    if (!_valid(distanceMeters, radiusMeters, accuracyMeters)) return false;
    final definitelyOutside =
        distanceMeters - accuracyMeters >= radiusMeters + minimumMarginMeters;
    final definitelyInside =
        distanceMeters + accuracyMeters <= radiusMeters - minimumMarginMeters;

    if (definitelyOutside) {
      _outsideCount++;
      _insideCount = 0;
      if (_outsideCount >= confirmations) _seenOutside = true;
      return false;
    }
    if (definitelyInside) {
      _outsideCount = 0;
      if (!_seenOutside) {
        _insideCount = 0;
        return false;
      }
      _insideCount++;
      return _insideCount >= confirmations;
    }
    _insideCount = 0;
    _outsideCount = 0;
    return false;
  }

  bool confirmExit({
    required double distanceMeters,
    required double radiusMeters,
    required double accuracyMeters,
  }) {
    if (!_valid(distanceMeters, radiusMeters, accuracyMeters)) return false;
    final definitelyOutside =
        distanceMeters - accuracyMeters >= radiusMeters + minimumMarginMeters;
    final definitelyInside =
        distanceMeters + accuracyMeters <= radiusMeters - minimumMarginMeters;

    if (definitelyOutside) {
      _outsideCount++;
      return _outsideCount >= confirmations;
    }
    if (definitelyInside) {
      _outsideCount = 0;
      return false;
    }
    _outsideCount = 0;
    return false;
  }

  bool _valid(double distance, double radius, double accuracy) =>
      distance.isFinite &&
      radius.isFinite &&
      accuracy.isFinite &&
      distance >= 0 &&
      radius > 0 &&
      accuracy >= 0;
}
