import 'package:sqflite/sqflite.dart';
import 'package:assignment_test/Willie/community_database_service.dart';

class FootprintDao {
  final _db = DatabaseService();

  /// insert or replace by (email, date)
  Future<void> upsert(String email, String yyyyMmDd, double kg) async {
    final db = await _db.database;
    await db.insert(
      'footprints',
      {'email': email, 'date': yyyyMmDd, 'kgCo2e': kg},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> ofEmail(String email) async {
    final db = await _db.database;
    return db.query(
      'footprints',
      where: 'email=?',
      whereArgs: [email],
      orderBy: 'date DESC',
    );
  }
}

