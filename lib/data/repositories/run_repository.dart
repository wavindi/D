import '../../domain/models/run_record.dart';
import '../database/app_database.dart';

class RunRepository {
  RunRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<RunRecord> save(RunRecord run) async {
    final db = await _appDatabase.database;
    final id = await db.insert('runs', run.toMap());
    return RunRecord(
      id: id,
      startedAt: run.startedAt,
      durationSeconds: run.durationSeconds,
      distanceMeters: run.distanceMeters,
      topSpeedKmh: run.topSpeedKmh,
    );
  }

  Future<List<RunRecord>> getAll() async {
    final db = await _appDatabase.database;
    final rows = await db.query('runs', orderBy: 'started_at DESC');
    return rows.map(RunRecord.fromMap).toList(growable: false);
  }
}
