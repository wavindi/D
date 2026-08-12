import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/run_record.dart';
import '../api/d_api.dart';

class RunRepository {
  static const _runsKey = 'd_racing_runs_v3';
  static const _territoryKey = 'd_racing_territories_v1';

  Future<RunRecord> save(RunRecord run) async {
    // Signed-in users store the canonical trip on the VPS. Keep a local copy
    // as an offline cache so the app remains useful during weak connectivity.
    RunRecord? remoteSaved;
    if (DApi.instance.token != null) {
      remoteSaved = await DApi.instance.saveTrip(run);
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = await _getLocal();
    final id = remoteSaved?.id ??
        ((existing.isEmpty
                ? 0
                : existing
                    .map((e) => e.id ?? 0)
                    .reduce((a, b) => a > b ? a : b)) +
            1);
    final saved = RunRecord(
      id: id,
      startedAt: run.startedAt,
      durationSeconds: run.durationSeconds,
      distanceMeters: run.distanceMeters,
      topSpeedKmh: run.topSpeedKmh,
      averageSpeedKmh: run.averageSpeedKmh,
      destinationName: run.destinationName,
      stoppedSeconds: run.stoppedSeconds,
      samples: run.samples,
    );
    final next = [
      saved,
      ...existing.where(
        (item) => item.startedAt.toIso8601String() != run.startedAt.toIso8601String(),
      ),
    ];
    await prefs.setString(
      _runsKey,
      jsonEncode(next.map((e) => e.toMap()).toList(growable: false)),
    );

    final claimed = await getTerritories();
    for (final sample in run.samples) {
      claimed.add(_cellKey(sample.lat, sample.lng));
    }
    await prefs.setStringList(_territoryKey, claimed.toList(growable: false));
    return saved;
  }

  Future<List<RunRecord>> getAll() async {
    if (DApi.instance.token != null) {
      try {
        final remote = await DApi.instance.fetchTrips();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _runsKey,
          jsonEncode(remote.map((e) => e.toMap()).toList(growable: false)),
        );
        return remote;
      } catch (_) {
        // Use the local cache if the VPS is temporarily unreachable.
      }
    }
    return _getLocal();
  }

  Future<List<RunRecord>> _getLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_runsKey) ?? prefs.getString('d_racing_runs_v2');
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => RunRecord.fromMap(Map<String, Object?>.from(item as Map)))
        .toList(growable: false);
  }

  Future<Set<String>> getTerritories() async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(_territoryKey)};
  }

  Future<DrivingStats> getStats() async {
    final runs = await getAll();
    if (runs.isEmpty) {
      return const DrivingStats(
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
        totalStoppedSeconds: 0,
        tripCount: 0,
        topSpeedKmh: 0,
        monthlyDistanceMeters: {},
      );
    }
    var distance = 0.0;
    var duration = 0;
    var stopped = 0;
    var top = 0.0;
    final monthly = <String, double>{};
    for (final run in runs) {
      distance += run.distanceMeters;
      duration += run.durationSeconds;
      stopped += run.stoppedSeconds;
      top = math.max(top, run.topSpeedKmh);
      final key =
          '${run.startedAt.year}-${run.startedAt.month.toString().padLeft(2, '0')}';
      monthly[key] = (monthly[key] ?? 0) + run.distanceMeters;
    }
    return DrivingStats(
      totalDistanceMeters: distance,
      totalDurationSeconds: duration,
      totalStoppedSeconds: stopped,
      tripCount: runs.length,
      topSpeedKmh: top,
      monthlyDistanceMeters: monthly,
    );
  }

  /// ~180m grid cells.
  static String _cellKey(double lat, double lng) {
    final y = (lat * 600).floor();
    final x = (lng * 600).floor();
    return '$y:$x';
  }

  static (double, double) cellCenter(String key) {
    final parts = key.split(':');
    final y = int.parse(parts[0]);
    final x = int.parse(parts[1]);
    return ((y + 0.5) / 600, (x + 0.5) / 600);
  }
}
