import 'dart:convert';
import 'dart:developer';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'join_event_model.dart';
import 'ranking_model.dart';
import 'community_main_model.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:assignment_test/attr/habit.dart';
import 'package:assignment_test/attr/habit_entry.dart';
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  static const _communityTable = 'Community';
  static const _joinEventTable   = 'JoinEvent';
  static const _rankingTable     = 'Ranking';
  static const _usersTable       = 'users';
  static const _footprintsTable  = 'footprints';
  static const _habitsTable      = 'habits';
  static const _entriesTable     = 'entries';
  static const _stepsTable       = 'steps';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir  = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'ecolife.db');
    return openDatabase(
      path,
      version: 14,  // bump to new version
      onConfigure: _onConfigure,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (db, version) async {
        // ─── legacy ─────────────────────────────
        await db.execute('''
          CREATE TABLE $_usersTable(
            email     TEXT PRIMARY KEY NOT NULL,
            username  TEXT,
            phone     TEXT,
            location  TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE $_footprintsTable(
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            email   TEXT    NOT NULL,
            date    TEXT    NOT NULL,
            kgCo2e  REAL    NOT NULL,
            UNIQUE(email, date)
          );
        ''');

        await db.execute('''
          CREATE TABLE $_habitsTable (
            user_email   TEXT    NOT NULL,
            id           TEXT    PRIMARY KEY,
            title        TEXT    NOT NULL,
            unit         TEXT,
            goal         REAL,
            currentValue REAL,
            quickAdds    TEXT,
            usePedometer INTEGER,
            createdAt    TEXT,
            updatedAt    TEXT,
            FOREIGN KEY(user_email) REFERENCES $_usersTable(email) ON DELETE CASCADE
          );
        ''');

        await db.execute('''
          CREATE TABLE $_entriesTable (
            id         TEXT PRIMARY KEY,
            user_email TEXT NOT NULL,
            habitTitle TEXT,
            date       TEXT,
            value      REAL,
            createdAt  TEXT,
            updatedAt  TEXT,
            FOREIGN KEY(user_email) REFERENCES $_usersTable(email) ON DELETE CASCADE
          );
        ''');

        await db.execute('''
          CREATE TABLE $_stepsTable (
            id         TEXT    PRIMARY KEY,
            user_email TEXT    NOT NULL,
            day        TEXT    NOT NULL,
            count      REAL    NOT NULL,
            createdAt  TEXT    NOT NULL,
            updatedAt  TEXT    NOT NULL,
            FOREIGN KEY(user_email) REFERENCES $_usersTable(email) ON DELETE CASCADE
          );
        ''');
        await db.execute('''
      CREATE TABLE daily_records(
        dateId TEXT, -- Date string (YYYY-MM-DD) - used as part of composite key
        userId TEXT, -- User ID (email) - used as part of composite key
        -- Removed: habitId TEXT, -- Habit ID no longer stored here
        checkInTimestamp TEXT, -- Store exact check-in time as ISO 8601 string
        treeGrowthStageOnDay INTEGER, -- Cumulative stage reached after this check-in
        createdAt TEXT, -- Store creation timestamp as ISO 8601 string
        PRIMARY KEY (dateId, userId) -- Composite primary key (now just dateId and userId)
      )
    ''');

        // ─── community ──────────────────────────
        await _createCommunityTable(db);
        await _createJoinEventTable(db);
        await _createRankingTable(db);
      },
      onUpgrade: (db, oldV, newV) async {
        // if someone was on the very old v1 (which had no legacy tables), create them now
        if (oldV < 2) {
          await db.execute('''
            CREATE TABLE $_usersTable(
              email     TEXT PRIMARY KEY NOT NULL,
              username  TEXT,
              phone     TEXT,
              location  TEXT
            );
          ''');
          // …repeat for footprints, habits, entries, steps…
        }
        // if you’re upgrading from v2 → v13, drop orphaned/tracking tables
        if (oldV < 13) {
          await db.execute('DROP TABLE IF EXISTS entries');
          await db.execute('DROP TABLE IF EXISTS Tracking');
        }
        // you could also add future migrations here for v14+
      },
    );
  }

  Future _onCreate(Database db, int v) async {
    await _createCommunityTable(db);
    await _createJoinEventTable(db);
    await _createRankingTable(db);
  }

  Future _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 13) {
      // Remove the orphaned entries / tracking tables if they exist
      await db.execute('DROP TABLE IF EXISTS entries');
      await db.execute('DROP TABLE IF EXISTS Tracking');
    }
  }

  //–– Table creation

  Future _createCommunityTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_communityTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        typeOfEvent TEXT,
        shortDescription TEXT,
        description TEXT,
        startDate DATETIME,
        endDate DATETIME,
        location TEXT,
        capacity INTEGER,
        termsAndConditions TEXT,
        imagePath TEXT,
        existLeaderboard TEXT,
        typeOfLeaderboard TEXT,
        selectedHabitTitle TEXT,
        createdAt DATETIME,
        updatedAt DATETIME
      )
    ''');
  }

  Future _createJoinEventTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_joinEventTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        communityID INTEGER,
        joinedAt DATETIME,
        status TEXT,
        FOREIGN KEY(communityID) REFERENCES $_communityTable(id) ON DELETE CASCADE,
        UNIQUE(email, communityID)  
      )
    ''');
  }

  Future _createRankingTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_rankingTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        communityID INTEGER,
        score INTEGER,
        lastUpdated DATETIME,
        FOREIGN KEY(communityID) REFERENCES $_communityTable(id) ON DELETE CASCADE
      )
    ''');
  }

  //–– Users

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return db.query(
        _usersTable,
        columns: ['email','username','phone','location'],
        orderBy: 'username'
    );
  }

  Future<int> insertUser(Map<String,dynamic> u) async {
    final db = await database;
    return db.insert(_usersTable, u, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteUser(String email) async {
    final db = await database;
    return db.delete(_usersTable, where: 'email = ?', whereArgs: [email]);
  }


  //–– Habit Titles

  /// Include "Step Counter" plus every distinct habitTitle from the entries table
  Future<RankingModel> getHabitScoreForUserInCommunity({
    required String userEmail,
    required int    communityID,
    required String habitTitle,               // expected = 'Step Counter'
  }) async {
    if (habitTitle != 'Step Counter') {
      return RankingModel(
        id: null,
        email: userEmail,
        communityID: communityID,
        score: 0,
        lastUpdated: DateTime.now(),
      );
    }

    final db   = await database;
    final rows = await db.query(
      _stepsTable,
      columns : ['count'],
      where   : 'user_email = ?',
      whereArgs: [userEmail],
    );
    final total = rows.fold<double>(
        0, (sum, r) => sum + (r['count'] as num).toDouble());

    return RankingModel(
      id         : null,
      email      : userEmail,
      communityID: communityID,
      score      : total.round(),
      lastUpdated: DateTime.now(),
    );
  }


  //–– Entries CRUD (formerly Tracking)



  //–– Steps

  Future<void> upsertStepCount({
    required String userEmail,
    required String day,
    required double count,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final uuid = Uuid().v4();

    final existing = await db.query(
      _stepsTable,
      where: 'user_email = ? AND day = ?',
      whereArgs: [userEmail, day],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        _stepsTable,
        {'count': count, 'updatedAt': now},
        where: 'user_email = ? AND day = ?',
        whereArgs: [userEmail, day],
      );
    } else {
      await db.insert(_stepsTable, {
        'id': uuid,
        'user_email': userEmail,
        'day': day,
        'count': count,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getStepsForUser({
    required String userEmail,
    String? fromDay,
    String? toDay,
  }) async {
    final db = await database;
    final clauses = ['user_email = ?'];
    final args = [userEmail];
    if (fromDay != null) {
      clauses.add('day >= ?');
      args.add(fromDay);
    }
    if (toDay != null) {
      clauses.add('day <= ?');
      args.add(toDay);
    }
    return db.query(
      _stepsTable,
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'day ASC',
    );
  }


  //–– Community CRUD

  Future<int> insertCommunity(CommunityMain c) async {
    final db = await database;
    return db.insert(_communityTable, c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CommunityMain>> getAllCommunities() async {
    final db = await database;
    final rows = await db.query(_communityTable, orderBy: 'startDate DESC');
    return rows.map((r) => CommunityMain.fromJson(r)).toList();
  }

  Future<CommunityMain?> getCommunityById(int id) async {
    final db = await database;
    final rows = await db.query(
        _communityTable,
        where: 'id = ?', whereArgs: [id], limit: 1
    );
    return rows.isEmpty ? null : CommunityMain.fromJson(rows.first);
  }

  Future<int> updateCommunity(CommunityMain c) async {
    final db = await database;
    return db.update(
      _communityTable,
      c.toMap(),
      where: 'id = ?', whereArgs: [c.id],
    );
  }

  Future<int> deleteCommunity(int id) async {
    final db = await database;
    return db.delete(_communityTable, where: 'id = ?', whereArgs: [id]);
  }

  //–– JoinEvent CRUD

  /// Insert or update (by email+communityID) join record
  Future<void> upsertJoinEvent(String email, int communityID, String status) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      _joinEventTable,
      where: 'email = ? AND communityID = ?',
      whereArgs: [email, communityID],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        _joinEventTable,
        {'status': status},
        where: 'email = ? AND communityID = ?',
        whereArgs: [email, communityID],
      );
    } else {
      await db.insert(_joinEventTable, {
        'email': email,
        'communityID': communityID,
        'joinedAt': now,
        'status': status,
      });
    }
  }

  Future<int> updateJoinEventStatus(String email, int communityID, String status) async {
    final db = await database;
    return db.update(
      _joinEventTable,
      {'status': status},
      where: 'email = ? AND communityID = ?',
      whereArgs: [email, communityID],
    );
  }

  Future<List<JoinEventModel>> getJoinsForCommunity(int communityID) async {
    final db = await database;
    final rows = await db.query(
        _joinEventTable,
        where: 'communityID = ?', whereArgs: [communityID]
    );
    return rows.map((r) => JoinEventModel.fromJson(r)).toList();
  }

  Future<List<JoinEventModel>> getJoinsForUser(String email) async {
    final db = await database;
    final rows = await db.query(
        _joinEventTable,
        where: 'email = ?', whereArgs: [email]
    );
    return rows.map((r) => JoinEventModel.fromJson(r)).toList();
  }

  Future<int> deleteJoinEvent(int id) async {
    final db = await database;
    return db.delete(_joinEventTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteJoinsForCommunity(int communityID) async {
    final db = await database;
    return db.delete(
        _joinEventTable,
        where: 'communityID = ?', whereArgs: [communityID]
    );
  }

  //–– Ranking CRUD

  Future<int> insertOrUpdateRanking(RankingModel r) async {
    final db   = await database;

    // 1️⃣ does a row already exist for the same email + communityID ?
    final existing = await db.query(
      _rankingTable,
      columns: ['id'],
      where: 'email = ? AND communityID = ?',
      whereArgs: [r.email, r.communityID],
      limit: 1,
    );

    final data = {                                  // drop the "id" field
      'email'      : r.email,
      'communityID': r.communityID,
      'score'      : r.score,
      'lastUpdated': r.lastUpdated.toIso8601String(),
    };

    if (existing.isNotEmpty) {
      // 🔄 UPDATE
      return db.update(
        _rankingTable,
        data,
        where: 'email = ? AND communityID = ?',
        whereArgs: [r.email, r.communityID],
      );
    } else {
      // ➕ INSERT
      return db.insert(_rankingTable, data);
    }
  }


  Future<int> updateRanking(RankingModel r) async {
    final db = await database;
    return db.update(
        _rankingTable,
        r.toMap(),
        where: 'id = ?', whereArgs: [r.id]
    );
  }

  Future<List<RankingModel>> getRankingsForCommunity(int communityID, {int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
        _rankingTable,
        where: 'communityID = ?', whereArgs: [communityID],
        orderBy: 'score DESC', limit: limit
    );
    return rows.map((r) => RankingModel.fromJson(r)).toList();
  }

  Future<RankingModel?> getRankingForUserInCommunity(String email, int communityID) async {
    final db = await database;
    final rows = await db.query(
        _rankingTable,
        where: 'email = ? AND communityID = ?', whereArgs: [email, communityID],
        limit: 1
    );
    return rows.isEmpty ? null : RankingModel.fromJson(rows.first);
  }

  Future<int> deleteRanking(int id) async {
    final db = await database;
    return db.delete(_rankingTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRankingsForCommunity(int communityID) async {
    final db = await database;
    return db.delete(
        _rankingTable,
        where: 'communityID = ?', whereArgs: [communityID]
    );
  }

  //–– Optionally close DB
  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }

  //Habit Tracking part---------------------------------------------------
  Future<void> deleteAllEntries() async {
    final db = await database;
    await db.delete('entries');
  }

  // Proper implementation for getting today's step count
  Future<int?> getLastSavedSteps() async {
    final db = await database;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final rows = await db.query(
      'steps',
      where: 'day = ?',
      whereArgs: [todayKey],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return (rows.first['count'] as num).toInt();
  }

  /// Overwrite today's Short‑Walk row with the new total.
  Future<void> saveSteps(int steps, String user_email) async {
    final db = await database;
    final today = DateTime.now();
    final ymd = DateFormat('yyyy-MM-dd').format(today);

    await db.delete(
      'entries',
      where: 'habitTitle = ? AND substr(date,1,10) = ?',
      whereArgs: ['Short Walk', ymd],
    );

    await db.insert('entries', {
      'id': const Uuid().v4(),
      'user_email': user_email,
      'habitTitle': 'Short Walk',
      'date': today.toIso8601String(),
      'value': steps,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteDay(String habitTitle, DateTime date) async {
    final db = await database;
    final key = DateFormat('yyyy-MM-dd').format(date); // "2025-05-05"
    await db.delete(
      'entries',
      where: 'habitTitle = ? AND substr(date,1,10) = ?', // YYYY-MM-DD
      whereArgs: [habitTitle, key],
    );
  }

  Future<void> clearEntriesForHabit(String habitTitle) async {
    final db = await database;
    final cutoff =
    DateTime.now().subtract(const Duration(days: 6)).toIso8601String();
    await db.delete(
      'entries',
      where: 'habitTitle = ? AND date >= ?',
      whereArgs: [habitTitle, cutoff],
    );
  }

  /// 删除指定用户的某个习惯
  Future<void> deleteHabit(String userEmail, String title) async {
    final db = await database;
    await db.delete(
      'habits',
      where: 'user_email = ? AND title = ?',
      whereArgs: [userEmail, title],
    );
  }

  /// Inspect existing table and migrate only if 'date' is not TEXT.
  Future<void> _onConfigure(Database db) async {
    final info = await db.rawQuery("PRAGMA table_info('entries')");
    // If table exists and date column is not TEXT, migrate:
    if (info.isNotEmpty &&
        !info.any((c) => c['name'] == 'date' && c['type'] == 'TEXT')) {
      await db.execute('ALTER TABLE entries RENAME TO entries_old');
      await db.execute('''
        INSERT INTO entries (id, user_email, habitTitle, date, value, createdAt, updatedAt)
        SELECT id, user_email, habitTitle, date, value, createdAt, updatedAt
        FROM entries_old;
      ''');
      await db.execute('DROP TABLE entries_old');
    }
  }

  // Insert or replace an entry, storing all dates as ISO-8601 strings.
  Future<void> upsertEntry(HabitEntry entry) async {
    final db = await database;
    print(
      "► try insert entry: ${entry.habitTitle} @ ${entry.date.toIso8601String()}",
    );
    final id = await db.insert('entries', {
      'id': entry.id,
      'user_email': entry.user_email,
      'habitTitle': entry.habitTitle,
      'date': entry.date.toIso8601String(),
      'value': entry.value,
      'createdAt': entry.createdAt.toIso8601String(),
      'updatedAt': entry.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    print("✓ insert success, returned id: $id");
  }

  Future<List<HabitEntry>> fetchAllEntries(
      String user_email,
      String habitTitle,
      ) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      where: 'user_email = ? AND habitTitle = ?',
      whereArgs: [user_email, habitTitle],
      orderBy: 'date ASC',
    );
    return rows.map((r) => HabitEntry(
      id        : r['id'] as String,
      user_email: r['user_email'] as String,
      habitTitle: r['habitTitle'] as String,
      date      : DateTime.parse(r['date'] as String),
      value     : (r['value'] as num).toDouble(),
      createdAt : DateTime.parse(r['createdAt'] as String),
      updatedAt : DateTime.parse(r['updatedAt'] as String),
    )).toList();
  }

  // Group entries by month (YYYY-MM) and sum values.
  Future<List<HabitEntry>> fetchMonthlyTotals(
      String user_email,
      String habitTitle,
      ) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        substr(date,1,7) AS ym,
        SUM(value)      AS total
      FROM entries
      WHERE user_email = ?
      AND habitTitle = ?
      GROUP BY ym
      ORDER BY ym ASC
      ''',
      [user_email, habitTitle],
    );

    return rows.map((r) {
      final ym = r['ym'] as String; // e.g. "2025-05"
      final parts = ym.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      return HabitEntry(
        id: const Uuid().v4(),
        user_email: user_email,
        habitTitle: habitTitle,
        date: DateTime(year, month),
        value: (r['total'] as num).toDouble(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();
  }

  Future<void> clearEntries() async {
    final db = await database;
    await db.delete('entries');
  }

  Future<void> dropAndRecreateEntriesTable() async {
    final db = await database;
    await db.execute('DROP TABLE IF EXISTS entries');
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
  }

  Future<List<HabitEntry>> fetchRange(
      String user_email,
      String habitTitle,
      DateTime pivot,
      ) async {
    final db = await database;
    final start =
    DateTime(
      pivot.year,
      pivot.month,
      pivot.day,
    ).subtract(const Duration(days: 6)).toIso8601String();
    final end =
    DateTime(
      pivot.year,
      pivot.month,
      pivot.day,
      23,
      59,
      59,
    ).toIso8601String();

    final rows = await db.query(
      'entries',
      where: 'user_email = ? AND habitTitle = ? AND date BETWEEN ? AND ?',
      whereArgs: [user_email, habitTitle, start, end],
      orderBy: 'date ASC',
    );

    final List<HabitEntry> result = [];
    for (final r in rows) {
      // extract user_email and guard against null
      final userEmailStr = r['user_email'] as String?;
      if (userEmailStr == null) {
        // skip rows that somehow lack a user_email
        continue;
      }
      // also guard your other required fields
      final idStr = r['id'] as String?;
      final dateStr = r['date'] as String?;
      final created = r['createdAt'] as String?;
      final updated = r['updatedAt'] as String?;
      if (idStr == null ||
          dateStr == null ||
          created == null ||
          updated == null) {
        continue;
      }
      result.add(
        HabitEntry(
          id: idStr,
          user_email: userEmailStr,
          // ← now mapped
          habitTitle: r['habitTitle'] as String? ?? habitTitle,
          date: DateTime.parse(dateStr),
          value: (r['value'] as num? ?? 0).toDouble(),
          createdAt: DateTime.parse(created),
          updatedAt: DateTime.parse(updated),
        ),
      );
    }
    return result;
  }

  Future<List<HabitEntry>> fetchRangeLatest(
      String habit,
      DateTime pivot,
      ) async {
    final db = await database;
    final start =
    DateTime(
      pivot.year,
      pivot.month,
      pivot.day,
    ).subtract(const Duration(days: 6)).toIso8601String();
    final end =
    DateTime(
      pivot.year,
      pivot.month,
      pivot.day,
      23,
      59,
      59,
    ).toIso8601String();

    final rows = await db.rawQuery(
      '''
    SELECT e.*
    FROM entries e
    JOIN (
      SELECT substr(date,1,10) AS d, MAX(updatedAt) AS maxUpd
      FROM entries
      WHERE habitTitle = ? AND date BETWEEN ? AND ?
      GROUP BY d
    ) latest
    ON substr(e.date,1,10) = latest.d AND e.updatedAt = latest.maxUpd
    ORDER BY e.date ASC
    ''',
      [habit, start, end],
    );

    return rows
        .map(
          (r) => HabitEntry(
        id: r['id'] as String,
        user_email: r['user_email'] as String,
        habitTitle: r['habitTitle'] as String,
        date: DateTime.parse(r['date'] as String),
        value: (r['value'] as num).toDouble(),
        createdAt: DateTime.parse(r['createdAt'] as String),
        updatedAt: DateTime.parse(r['updatedAt'] as String),
      ),
    )
        .toList();
  }

  Future<void> dumpSchema() async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type='table'",
    );
    print("=== tables ===");
    for (final row in tables) {
      print("${row['name']}: ${row['sql']}");
    }
  }

  Future<void> dumpCounts() async {
    final db = await database;
    for (final t in ['users', 'entries', 'steps']) {
      try {
        final cnt = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $t'),
        );
        print("count($t) = $cnt");
      } catch (e) {
        print("table $t missing: $e");
      }
    }
  }

  Future<void> deleteAllEntriesForHabit(String habitTitle) async {
    final db = await database;
    await db.delete(
      'entries',
      where: 'habitTitle = ?',
      whereArgs: [habitTitle],
    );
  }



  Future<void> upsertHabit(Habit habit, String user_email) async {
    final db = await database;
    final exists = (await db.query(
      'habits',
      where: 'user_email = ? AND title = ?',
      whereArgs: [user_email, habit.title],
    )).isNotEmpty;

    final nowIso = DateTime.now().toIso8601String();
    if (exists) {
      // only update the fields that changed
      await db.update(
        'habits',
        {
          'id'         : const Uuid().v4(),
          'goal'       : habit.goal,
          'unit'       : habit.unit,
          'usePedometer': habit.usePedometer ? 1 : 0,
          'quickAdds'  : jsonEncode(habit.quickAdds),
          'updatedAt'  : nowIso,
        },
        where: 'user_email = ? AND title = ?',
        whereArgs: [user_email, habit.title],
      );
    } else {
      // first time insert
      await db.insert(
        'habits',
        {
          'user_email'   : user_email,
          'id'         : const Uuid().v4(),
          'title'        : habit.title,
          'unit'         : habit.unit,
          'goal'         : habit.goal,
          'currentValue' : habit.currentValue,
          'quickAdds'    : jsonEncode(habit.quickAdds),
          'usePedometer' : habit.usePedometer ? 1 : 0,
          'createdAt'    : nowIso,
          'updatedAt'    : nowIso,
        },
      );
    }
  }

  Future<List<Habit>> fetchHabits(String user_email) async {
    final db   = await database;
    final rows = await db.query('habits',
      where: 'user_email = ?', whereArgs: [user_email],
    );
    return rows.map((r) {
      return Habit(
        id           : r['id']        as String,
        title       : r['title']        as String,
        unit        : r['unit']         as String,
        goal        : (r['goal']        as num).toDouble(),
        currentValue: (r['currentValue']as num).toDouble(),
        quickAdds   : (jsonDecode(r['quickAdds'] as String) as List)
            .map((e) => (e as num).toDouble()).toList(),
        usePedometer: (r['usePedometer'] as int) == 1,
      );
    }).toList();
  }


  //Home Page-------------------------------------------------------

  Future<int> saveDailyRecord(String userId, String dateId, Map<String, dynamic> dailyData) async {
    final db = await database;
    // Ensure required data is present
    if (dateId.isEmpty || userId.isEmpty) { // Removed habitId check
      print('Error: Cannot save daily record without date ID or User ID.');
      return 0; // Indicate failure
    }
    // Prepare data for insertion, ensuring correct types and including composite key parts
    final Map<String, dynamic> dataToInsert = {
      'dateId': dateId,
      'userId': userId,
      // Removed: 'habitId': dailyData['habitId'], // Remove this line
      'checkInTimestamp': dailyData['checkInTimestamp'], // Should already be ISO 8601 string from CheckInPage
      'treeGrowthStageOnDay': dailyData['treeGrowthStageOnDay'],
      'createdAt': dailyData['createdAt'], // Should already be ISO 8601 string from CheckInPage
      // Add other fields if they are in dailyData and needed in the table
    };

    return await db.insert(
      'daily_records',
      dataToInsert,
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if (dateId, userId) composite key exists
    );
  }

  // Get the latest daily record for a specific user
  // Removed habitId from parameters
  Future<Map<String, dynamic>?> getLatestDailyRecord(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_records',
      where: 'userId = ?', // Simplified where clause
      whereArgs: [userId],
      orderBy: 'checkInTimestamp DESC', // Order by timestamp descending to get the latest
      limit: 1, // Get only the most recent one
    );
    if (maps.isNotEmpty) {
      return maps.first; // Return the data as a Map
    }
    return null; // No records found
  }

  // Get the total count of daily records for a specific user
  // Removed habitId from parameters
  Future<int> getCheckInCount(String userId) async {
    final db = await database;
    // Use count(*) to get the number of rows
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) FROM daily_records WHERE userId = ?', // Simplified where clause
      [userId],
    );
    int count = Sqflite.firstIntValue(result) ?? 0; // Get the count value
    return count;
  }

}