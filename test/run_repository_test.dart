import 'package:d/data/api/d_api.dart';
import 'package:d/data/repositories/run_repository.dart';
import 'package:d/domain/models/run_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTripApi implements TripApi {
  FakeTripApi({required int userId, this.token = 'token'})
    : user = AuthUser(
        id: userId,
        email: 'user$userId@example.com',
        name: 'User $userId',
      );

  @override
  String? token;
  @override
  AuthUser? user;
  bool failSaves = false;
  bool failDeletes = false;
  bool failFetch = false;
  int _nextId = 1;
  final List<RunRecord> remote = [];

  @override
  Future<RunRecord> saveTrip(RunRecord run) async {
    if (failSaves) throw const ApiException('offline', statusCode: 503);
    final existing = remote.where(
      (item) => item.clientTripId == run.clientTripId,
    );
    if (existing.isNotEmpty) return existing.first;
    final saved = run.copyWith(id: _nextId++, syncState: 'synced');
    remote.add(saved);
    return saved;
  }

  @override
  Future<List<RunRecord>> fetchTrips() async {
    if (failFetch) throw const ApiException('offline', statusCode: 503);
    return [...remote];
  }

  @override
  Future<void> deleteTrip(int id) async {
    if (failDeletes) throw const ApiException('offline', statusCode: 503);
    remote.removeWhere((run) => run.id == id);
  }
}

RunRecord trip({DateTime? startedAt}) => RunRecord(
  startedAt: startedAt ?? DateTime.utc(2026, 8, 15, 12),
  durationSeconds: 120,
  distanceMeters: 1500,
  topSpeedKmh: 80,
  averageSpeedKmh: 45,
  samples: const [SpeedSample(lat: 36.8, lng: 10.18, speedKmh: 45)],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'offline completed trip survives refresh and syncs on reconnect',
    () async {
      final api = FakeTripApi(userId: 1)..failSaves = true;
      final repository = RunRepository(api: api);

      final saved = await repository.save(trip());
      expect(saved.syncState, 'pendingCreate');
      expect(saved.clientTripId, isNotNull);

      api.failSaves = false;
      final refreshed = await repository.getAll();
      expect(refreshed, hasLength(1));
      expect(refreshed.single.syncState, 'synced');
      expect(refreshed.single.id, isNotNull);
      expect(api.remote, hasLength(1));
    },
  );

  test(
    'remote fetch cannot erase a create that still fails to upload',
    () async {
      final api = FakeTripApi(userId: 2)..failSaves = true;
      final repository = RunRepository(api: api);
      final saved = await repository.save(trip());

      final refreshed = await repository.getAll();
      expect(
        refreshed.map((run) => run.clientTripId),
        contains(saved.clientTripId),
      );
      expect(refreshed.single.syncState, 'pendingCreate');
      expect(api.remote, isEmpty);
    },
  );

  test('failed delete remains queued and is retried on refresh', () async {
    final api = FakeTripApi(userId: 3);
    final repository = RunRepository(api: api);
    final saved = await repository.save(trip());
    expect(api.remote, hasLength(1));

    api.failDeletes = true;
    await repository.delete(saved);
    expect(await repository.getAll(), isEmpty);
    expect(api.remote, hasLength(1));

    api.failDeletes = false;
    expect(await repository.getAll(), isEmpty);
    expect(api.remote, isEmpty);
  });

  test('remote refresh rebuilds territories from downloaded samples', () async {
    final api = FakeTripApi(userId: 4);
    api.remote.add(
      trip().copyWith(
        id: 10,
        clientTripId: '123e4567-e89b-12d3-a456-426614174000',
      ),
    );
    final repository = RunRepository(api: api);

    expect(await repository.getAll(), hasLength(1));
    expect(await repository.getTerritories(), isNotEmpty);
  });

  test('malformed legacy cache is preserved for recovery', () async {
    SharedPreferences.setMockInitialValues({'d_racing_runs_v3': '{broken'});
    final api = FakeTripApi(userId: 12, token: null);
    final repository = RunRepository(api: api);

    expect(await repository.getAll(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('d_racing_runs_v3'), '{broken');
  });

  test('local caches are isolated by authenticated user ID', () async {
    final firstApi = FakeTripApi(userId: 10, token: null);
    final firstRepository = RunRepository(api: firstApi);
    await firstRepository.save(trip());
    expect(await firstRepository.getAll(), hasLength(1));

    final secondApi = FakeTripApi(userId: 11, token: null);
    final secondRepository = RunRepository(api: secondApi);
    expect(await secondRepository.getAll(), isEmpty);
  });
}
