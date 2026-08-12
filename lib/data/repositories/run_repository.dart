import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/run_record.dart';

class RunRepository {
  static const _key = 'd_racing_runs_v2';

  Future<RunRecord> save(RunRecord run) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final id = (existing.isEmpty ? 0 : existing.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b)) + 1;
    final saved = RunRecord(
      id: id,
      startedAt: run.startedAt,
      durationSeconds: run.durationSeconds,
      distanceMeters: run.distanceMeters,
      topSpeedKmh: run.topSpeedKmh,
      averageSpeedKmh: run.averageSpeedKmh,
      destinationName: run.destinationName,
    );
    final next = [saved, ...existing];
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toMap()).toList(growable: false)),
    );
    return saved;
  }

  Future<List<RunRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => RunRecord.fromMap(Map<String, Object?>.from(item as Map)))
        .toList(growable: false);
  }
}
