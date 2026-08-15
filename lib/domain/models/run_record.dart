class SpeedSample {
  const SpeedSample({
    required this.lat,
    required this.lng,
    required this.speedKmh,
  });
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
    this.clientTripId,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.topSpeedKmh,
    this.averageSpeedKmh = 0,
    this.destinationName,
    this.stoppedSeconds = 0,
    this.samples = const [],
    this.syncState = 'synced',
    this.activityType = 'drive',
    this.trackId,
    this.trackCenterLat,
    this.trackCenterLng,
    this.trackRadiusMeters,
  });

  final int? id;
  final String? clientTripId;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double topSpeedKmh;
  final double averageSpeedKmh;
  final String? destinationName;
  final int stoppedSeconds;
  final List<SpeedSample> samples;
  final String syncState;
  final String activityType;
  final String? trackId;
  final double? trackCenterLat;
  final double? trackCenterLng;
  final double? trackRadiusMeters;

  Map<String, Object?> toMap() => {
    'id': id,
    'client_trip_id': clientTripId,
    'started_at': startedAt.toIso8601String(),
    'duration_seconds': durationSeconds,
    'distance_meters': distanceMeters,
    'top_speed_kmh': topSpeedKmh,
    'average_speed_kmh': averageSpeedKmh,
    'destination_name': destinationName,
    'stopped_seconds': stoppedSeconds,
    'samples': samples.map((s) => s.toMap()).toList(growable: false),
    'sync_state': syncState,
    'activity_type': activityType,
    'track_id': trackId,
    'track_center_lat': trackCenterLat,
    'track_center_lng': trackCenterLng,
    'track_radius_meters': trackRadiusMeters,
  };

  factory RunRecord.fromMap(Map<String, Object?> map) {
    final rawSamples = map['samples'];
    final samples = rawSamples is List
        ? rawSamples
              .map(
                (e) => SpeedSample.fromMap(Map<String, Object?>.from(e as Map)),
              )
              .toList(growable: false)
        : const <SpeedSample>[];
    return RunRecord(
      id: map['id'] as int?,
      clientTripId: map['client_trip_id'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      durationSeconds: map['duration_seconds'] as int,
      distanceMeters: (map['distance_meters'] as num).toDouble(),
      topSpeedKmh: (map['top_speed_kmh'] as num).toDouble(),
      averageSpeedKmh: ((map['average_speed_kmh'] as num?) ?? 0).toDouble(),
      destinationName: map['destination_name'] as String?,
      stoppedSeconds: (map['stopped_seconds'] as int?) ?? 0,
      samples: samples,
      syncState: (map['sync_state'] as String?) ?? 'synced',
      activityType: (map['activity_type'] as String?) ?? 'drive',
      trackId: map['track_id'] as String?,
      trackCenterLat: (map['track_center_lat'] as num?)?.toDouble(),
      trackCenterLng: (map['track_center_lng'] as num?)?.toDouble(),
      trackRadiusMeters: (map['track_radius_meters'] as num?)?.toDouble(),
    );
  }

  RunRecord copyWith({
    int? id,
    bool clearId = false,
    String? clientTripId,
    DateTime? startedAt,
    int? durationSeconds,
    double? distanceMeters,
    double? topSpeedKmh,
    double? averageSpeedKmh,
    String? destinationName,
    int? stoppedSeconds,
    List<SpeedSample>? samples,
    String? syncState,
    String? activityType,
    String? trackId,
    double? trackCenterLat,
    double? trackCenterLng,
    double? trackRadiusMeters,
  }) => RunRecord(
    id: clearId ? null : (id ?? this.id),
    clientTripId: clientTripId ?? this.clientTripId,
    startedAt: startedAt ?? this.startedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    topSpeedKmh: topSpeedKmh ?? this.topSpeedKmh,
    averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
    destinationName: destinationName ?? this.destinationName,
    stoppedSeconds: stoppedSeconds ?? this.stoppedSeconds,
    samples: samples ?? this.samples,
    syncState: syncState ?? this.syncState,
    activityType: activityType ?? this.activityType,
    trackId: trackId ?? this.trackId,
    trackCenterLat: trackCenterLat ?? this.trackCenterLat,
    trackCenterLng: trackCenterLng ?? this.trackCenterLng,
    trackRadiusMeters: trackRadiusMeters ?? this.trackRadiusMeters,
  );
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
