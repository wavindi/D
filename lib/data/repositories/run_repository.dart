import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/run_record.dart';
import '../api/d_api.dart';

class RunRepository {
  RunRepository({
    TripApi? api,
    Future<SharedPreferences> Function()? preferences,
    Uuid? uuid,
  }) : _api = api ?? DApi.instance,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _uuid = uuid ?? const Uuid();

  static const _runsPrefix = 'd_racing_runs_v4';
  static const _territoryPrefix = 'd_racing_territories_v2';
  static const _pendingDeletesPrefix = 'd_racing_pending_deletes_v1';
  static const _legacyRunsKey = 'd_racing_runs_v3';
  static const _legacyTerritoryKey = 'd_racing_territories_v1';
  static const _legacyUnsyncedKey = 'd_racing_unsynced_starts_v1';
  static const _legacyDeletedKey = 'd_racing_deleted_trip_keys_v1';

  final TripApi _api;
  final Future<SharedPreferences> Function() _preferences;
  final Uuid _uuid;
  Future<List<RunRecord>>? _refreshing;

  String get _scope => _api.user == null ? 'guest' : 'user_${_api.user!.id}';
  String get _runsKey => '${_runsPrefix}_$_scope';
  String get _territoryKey => '${_territoryPrefix}_$_scope';
  String get _pendingDeletesKey => '${_pendingDeletesPrefix}_$_scope';
  String get _migrationKey => 'd_racing_storage_migrated_$_scope';

  Future<RunRecord> save(RunRecord run) async {
    final prefs = await _preferences();
    await _migrateLegacyIfNeeded(prefs);
    final existing = _readLocal(prefs);
    final local = run.copyWith(
      clientTripId: run.clientTripId ?? _uuid.v4(),
      syncState: _api.token == null ? 'local' : 'pendingCreate',
    );
    final next = [local, ...existing.where((item) => !_isSameRun(item, local))];
    await _writeLocal(prefs, next);
    await _rebuildTerritories(prefs, next);

    if (_api.token == null) return local;
    try {
      final remote = await _api.saveTrip(local);
      final reconciled = [
        remote.copyWith(syncState: 'synced'),
        ...next.where((item) => !_isSameRun(item, local)),
      ];
      await _writeLocal(prefs, reconciled);
      await _rebuildTerritories(prefs, reconciled);
      return remote.copyWith(syncState: 'synced');
    } catch (_) {
      // The local outbox is the durable success boundary. Synchronization is
      // retried by getAll() without losing the completed trip.
      return local;
    }
  }

  Future<List<RunRecord>> getAll() {
    final current = _refreshing;
    if (current != null) return current;
    final future = _getAllInternal();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<List<RunRecord>> _getAllInternal() async {
    final prefs = await _preferences();
    await _migrateLegacyIfNeeded(prefs);
    var local = _readLocal(prefs);
    if (_api.token == null) return _sorted(local);

    local = await _flushPendingCreates(prefs, local);
    await _flushPendingDeletes(prefs);
    try {
      final remote = await _api.fetchTrips();
      final pendingDeleteIds = _pendingDeleteIds(prefs);
      final visibleRemote = remote
          .where((run) => run.id == null || !pendingDeleteIds.contains(run.id))
          .map((run) => run.copyWith(syncState: 'synced'))
          .toList(growable: true);
      final pendingLocal = local.where((run) => run.syncState != 'synced');
      for (final run in pendingLocal) {
        if (!visibleRemote.any((item) => _isSameRun(item, run))) {
          visibleRemote.add(run);
        }
      }
      final merged = _sorted(visibleRemote);
      await _writeLocal(prefs, merged);
      await _rebuildTerritories(prefs, merged);
      return merged;
    } catch (_) {
      // Authentication and transport errors must not destroy the local outbox.
      final safe = _sorted(local);
      await _writeLocal(prefs, safe);
      await _rebuildTerritories(prefs, safe);
      return safe;
    }
  }

  Future<void> delete(RunRecord run) async {
    final prefs = await _preferences();
    await _migrateLegacyIfNeeded(prefs);
    final remaining = _readLocal(
      prefs,
    ).where((item) => !_isSameRun(item, run)).toList(growable: false);
    await _writeLocal(prefs, remaining);
    await _rebuildTerritories(prefs, remaining);

    if (_api.token == null ||
        run.id == null ||
        run.syncState == 'pendingCreate') {
      return;
    }
    final pending = _pendingDeleteIds(prefs)..add(run.id!);
    await _writePendingDeletes(prefs, pending);
    try {
      await _api.deleteTrip(run.id!);
      pending.remove(run.id!);
      await _writePendingDeletes(prefs, pending);
    } catch (_) {
      // Keep the server ID in the delete outbox for the next refresh.
    }
  }

  Future<List<RunRecord>> _flushPendingCreates(
    SharedPreferences prefs,
    List<RunRecord> local,
  ) async {
    final next = [...local];
    for (var index = 0; index < next.length; index++) {
      final run = next[index];
      if (run.syncState != 'pendingCreate') continue;
      try {
        next[index] = (await _api.saveTrip(run)).copyWith(syncState: 'synced');
        await _writeLocal(prefs, next);
      } catch (_) {
        // Leave this record pending and continue syncing independent trips.
      }
    }
    return next;
  }

  Future<void> _flushPendingDeletes(SharedPreferences prefs) async {
    final pending = _pendingDeleteIds(prefs);
    for (final id in [...pending]) {
      try {
        await _api.deleteTrip(id);
        pending.remove(id);
        await _writePendingDeletes(prefs, pending);
      } catch (_) {
        // Keep failed deletes in the outbox.
      }
    }
  }

  List<RunRecord> _readLocal(SharedPreferences prefs) {
    final raw = prefs.getString(_runsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => RunRecord.fromMap(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: false);
    } catch (_) {
      // Preserve the corrupt value for diagnostics instead of deleting it.
      return const [];
    }
  }

  Future<void> _writeLocal(SharedPreferences prefs, List<RunRecord> runs) =>
      prefs.setString(
        _runsKey,
        jsonEncode(runs.map((run) => run.toMap()).toList(growable: false)),
      );

  Set<int> _pendingDeleteIds(SharedPreferences prefs) {
    final result = <int>{};
    for (final raw
        in prefs.getStringList(_pendingDeletesKey) ?? const <String>[]) {
      final id = int.tryParse(raw);
      if (id != null) result.add(id);
    }
    return result;
  }

  Future<void> _writePendingDeletes(SharedPreferences prefs, Set<int> ids) =>
      prefs.setStringList(
        _pendingDeletesKey,
        ids.map((id) => '$id').toList(growable: false),
      );

  Future<void> _migrateLegacyIfNeeded(SharedPreferences prefs) async {
    if (_api.user == null || prefs.getBool(_migrationKey) == true) return;
    var legacyRunsMigrated = true;
    if (!prefs.containsKey(_runsKey)) {
      final raw =
          prefs.getString(_legacyRunsKey) ??
          prefs.getString('d_racing_runs_v2');
      if (raw != null && raw.isNotEmpty) {
        try {
          final unsynced = {...?prefs.getStringList(_legacyUnsyncedKey)};
          final decoded = jsonDecode(raw) as List<dynamic>;
          final migrated = decoded
              .map((item) {
                final run = RunRecord.fromMap(
                  Map<String, Object?>.from(item as Map),
                );
                final pending = unsynced.contains(
                  run.startedAt.toIso8601String(),
                );
                return run.copyWith(
                  clientTripId: run.clientTripId ?? _uuid.v4(),
                  syncState: pending ? 'pendingCreate' : 'synced',
                );
              })
              .toList(growable: false);
          await _writeLocal(prefs, migrated);
        } catch (_) {
          // Leave malformed legacy data untouched for manual recovery.
          legacyRunsMigrated = false;
        }
      }
    }
    if (!legacyRunsMigrated) return;
    final oldTerritories = prefs.getStringList(_legacyTerritoryKey);
    if (!prefs.containsKey(_territoryKey) && oldTerritories != null) {
      await prefs.setStringList(_territoryKey, oldTerritories);
    }
    final oldDeleted =
        prefs.getStringList(_legacyDeletedKey) ?? const <String>[];
    final pendingIds = _pendingDeleteIds(prefs);
    for (final key in oldDeleted) {
      final id = int.tryParse(key.split(':').first);
      if (id != null) pendingIds.add(id);
    }
    await _writePendingDeletes(prefs, pendingIds);
    await prefs.setBool(_migrationKey, true);
    await prefs.remove(_legacyRunsKey);
    await prefs.remove('d_racing_runs_v2');
    await prefs.remove(_legacyTerritoryKey);
    await prefs.remove(_legacyUnsyncedKey);
    await prefs.remove(_legacyDeletedKey);
  }

  List<RunRecord> _sorted(Iterable<RunRecord> runs) {
    final result = runs.toList(growable: false);
    result.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return result;
  }

  bool _isSameRun(RunRecord first, RunRecord second) {
    if (first.clientTripId != null && second.clientTripId != null) {
      return first.clientTripId == second.clientTripId;
    }
    if (first.id != null && second.id != null) return first.id == second.id;
    return first.startedAt.toUtc() == second.startedAt.toUtc();
  }

  Future<Set<String>> getTerritories() async {
    final prefs = await _preferences();
    await _migrateLegacyIfNeeded(prefs);
    return {...?prefs.getStringList(_territoryKey)};
  }

  Future<void> _rebuildTerritories(
    SharedPreferences prefs,
    List<RunRecord> runs,
  ) async {
    final claimed = <String>{};
    for (final run in runs) {
      for (final sample in run.samples) {
        claimed.add(_cellKey(sample.lat, sample.lng));
      }
    }
    await prefs.setStringList(_territoryKey, claimed.toList(growable: false));
  }

  Future<DrivingStats> getStats() async {
    final runs = (await getAll())
        .where((run) => run.activityType != 'racer')
        .toList(growable: false);
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

  /// Approximately 180 m grid cells.
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
