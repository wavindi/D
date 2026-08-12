class RunRecord {
  const RunRecord({
    this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.topSpeedKmh,
    this.averageSpeedKmh = 0,
    this.destinationName,
  });

  final int? id;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double topSpeedKmh;
  final double averageSpeedKmh;
  final String? destinationName;

  Map<String, Object?> toMap() => {
        'id': id,
        'started_at': startedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'top_speed_kmh': topSpeedKmh,
        'average_speed_kmh': averageSpeedKmh,
        'destination_name': destinationName,
      };

  factory RunRecord.fromMap(Map<String, Object?> map) => RunRecord(
        id: map['id'] as int?,
        startedAt: DateTime.parse(map['started_at'] as String),
        durationSeconds: map['duration_seconds'] as int,
        distanceMeters: (map['distance_meters'] as num).toDouble(),
        topSpeedKmh: (map['top_speed_kmh'] as num).toDouble(),
        averageSpeedKmh: ((map['average_speed_kmh'] as num?) ?? 0).toDouble(),
        destinationName: map['destination_name'] as String?,
      );
}
