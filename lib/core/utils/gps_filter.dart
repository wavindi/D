import 'dart:math' as math;

const double minimumGpsStepAllowanceMeters = 80;

/// Returns whether a GPS step is plausible for the time and reported speed.
///
/// The fixed minimum still filters sudden jumps while the speed-based allowance
/// prevents normal highway travel from being rejected when GPS updates arrive
/// several seconds apart.
bool isPlausibleGpsStep({
  required double distanceMeters,
  required Duration elapsed,
  required double previousSpeedKmh,
  required double currentSpeedMps,
  required double previousAccuracyMeters,
  required double currentAccuracyMeters,
}) {
  final elapsedSeconds = math.max(0.0, elapsed.inMilliseconds / 1000);
  final previousSpeedMps = math.max(0.0, previousSpeedKmh / 3.6);
  final safeCurrentSpeedMps = math.max(0.0, currentSpeedMps);
  final fastestReportedSpeed = math.max(previousSpeedMps, safeCurrentSpeedMps);
  final accuracyAllowance =
      math.max(0.0, previousAccuracyMeters) +
      math.max(0.0, currentAccuracyMeters);
  final speedAllowance = fastestReportedSpeed * elapsedSeconds * 1.5;
  final allowedDistance = math.max(
    minimumGpsStepAllowanceMeters,
    speedAllowance + accuracyAllowance,
  );

  return distanceMeters <= allowedDistance;
}
