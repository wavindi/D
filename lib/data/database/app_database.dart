import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get database async {
    final cached = _database;
    if (cached != null) return cached;
    final path = p.join(await getDatabasesPath(), 'd_racing.db');
    return _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE runs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            distance_meters REAL NOT NULL,
            top_speed_kmh REAL NOT NULL
          )
        ''');
      },
    );
  }
}
