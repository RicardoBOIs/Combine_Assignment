import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  DatabaseService._constructor();
  static final DatabaseService instance = DatabaseService._constructor();


  Database? _db;

  Future<Database> get database async {
    _db ??= await _openDB();                 // open once
    return _db!;
  }

  /* ────────── create / migrate ────────── */
  Future<Database> _openDB() async {
    final dir  = await getDatabasesPath();
    final path = join(dir, 'ecolife.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,

    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        email     TEXT PRIMARY KEY NOT NULL,
        username  TEXT,
        phone     TEXT,
        location  TEXT
      );
    ''');


    await db.execute('''
  CREATE TABLE footprints(
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    email   TEXT    NOT NULL,        -- use email as identifier
    date    TEXT    NOT NULL,        -- yyyy-MM-dd
    kgCo2e  REAL    NOT NULL,
    UNIQUE(email, date)              -- one row per user per day
  );
''');



    await db.execute('PRAGMA foreign_keys = ON');
  }
}
