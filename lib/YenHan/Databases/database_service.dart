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
      version: 2,
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

    await db.execute('''
    CREATE TABLE habits (
      user_email   TEXT    NOT NULL,
      id           TEXT    PRIMARY KEY,
      title        TEXT    NOT NULL,
      unit         TEXT,
      goal         REAL,
      currentValue REAL,
      quickAdds    TEXT,      -- JSON‐encoded list of doubles
      usePedometer INTEGER,   -- 0 or 1
      createdAt    TEXT,
      updatedAt    TEXT,
      FOREIGN KEY(user_email) REFERENCES users(email) ON DELETE CASCADE
     );
   ''');

    await db.execute('''
    CREATE TABLE entries (
      id         TEXT PRIMARY KEY,
      user_email TEXT NOT NULL,
      habitTitle TEXT,
      date       TEXT,
      value      REAL,
      createdAt  TEXT,
      updatedAt  TEXT,
      FOREIGN KEY(user_email) REFERENCES users(email) ON DELETE CASCADE
    )
  ''');

    await db.execute('DROP TABLE IF EXISTS steps');
    await db.execute('''
   CREATE TABLE steps (
     id         TEXT    PRIMARY KEY,
     user_email TEXT    NOT NULL,
     day        TEXT    NOT NULL,
     count      REAL    NOT NULL,
     createdAt  TEXT    NOT NULL,
     updatedAt  TEXT    NOT NULL,
     FOREIGN KEY(user_email) REFERENCES users(email) ON DELETE CASCADE
   )
 ''');

    await db.execute('''
    CREATE UNIQUE INDEX idx_steps_day
      ON steps(day)
  ''');

  }
}
