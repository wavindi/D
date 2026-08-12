class SpeedSample {
  const SpeedSample({required this.lat, required this.lng, required this.speedKmh});
  final double lat;
  final double lng;
  final double speedKmh;

  Map<String, Object?> toMap() => {
        'lat': lat,
        'lng': lng,
        'speed_kmh': speedKmh,
      };

  factory SpeedSample.fromMap(Map<String, Object?> map) => SpeedSample(
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        speedKmh: (map['speed_kmh'] as num).toDouble(),
      );
}

class RunRecord {
  const RunRecord({
    this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.topSpeedKmh,
    this.averageSpeedKmh = 0,
    this.destinationName,
    this.stoppedSeconds = 0,
    this.samples = const [],
  });

  final int? id;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double topSpeedKmh;
  final double averageSpeedKmh;
  final String? destinationName;
  final int stoppedSeconds;
  final List<SpeedSample> samples;

  Map<String, Object?> toMap() => {
        'id': id,
        'started_at': startedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'top_speed_kmh': topSpeedKmh,
        'average_speed_kmh': averageSpeedKmh,
        'destination_name': destinationName,
        'stopped_seconds': stoppedSeconds,
        'samples': samples.map((s) => s.toMap()).toList(growable: false),
      };

  factory RunRecord.fromMap(Map<String, Object?> map) {
    final rawSamples = map['samples'];
    final samples = rawSamples is List
        ? rawSamples
            .map((e) => SpeedSample.fromMap(Map<String, Object?>.from(e as Map)))
            .toList(growable: false)
        : const <SpeedSample>[];
    return RunRecord(
      id: map['id'] as int?,
      startedAt: DateTime.parse(map['started_at'] as String),
      durationSeconds: map['duration_seconds'] as int,
      distanceMeters: (map['distance_meters'] as num).toDouble(),
      topSpeedKmh: (map['top_speed_kmh'] as num).toDouble(),
      averageSpeedKmh: ((map['average_speed_kmh'] as num?) ?? 0).toDouble(),
      destinationName: map['destination_name'] as String?,
      stoppedSeconds: (map['stopped_seconds'] as int?) ?? 0,
      samples: samples,
    );
  }
}

class DrivingStats {
  const DrivingStats({
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.totalStoppedSeconds,
    required this.tripCount,
    required this.topSpeedKmh,
    required this.monthlyDistanceMeters,
  });

  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final int totalStoppedSeconds;
  final int tripCount;
  final double topSpeedKmh;
  final Map<String, double> monthlyDistanceMeters;
}

class SpeedDistribution {
  const SpeedDistribution({
    required this.under50,
    required this.from50to90,
    required this.from90to130,
    required this.over130,
  });

  final double under50;
  final double from50to90;
  final double from90to130;
  final double over130;

  static SpeedDistribution fromSamples(List<SpeedSample> samples) {
    if (samples.isEmpty) {
      return const SpeedDistribution(
        under50: 0,
        from50to90: 0,
        from90to130: 0,
        over130: 0,
      );
    }
    var a = 0, b = 0, c = 0, d = 0;
    for (final s in samples) {
      if (s.speedKmh < 50) {
        a++;
      } else if (s.speedKmh < 90) {
        b++;
      } else if (s.speedKmh < 130) {
        c++;
      } else {
        d++;
      }
    }
    final n = samples.length.toDouble();
    return SpeedDistribution(
      under50: a / n,
      from50to90: b / n,
      from90to130: c / n,
      over130: d / n,
    );
  }
}
