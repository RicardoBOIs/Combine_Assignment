import 'dart:developer';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'join_event_model.dart';
import 'ranking_model.dart';
import 'community_main_model.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../YenHan/Databases/database_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  // ─── TABLE NAMES ─────────────────────────────────────────────────────────
  static const _communityTable = 'Community';
  static const _joinEventTable = 'JoinEvent';
  static const _rankingTable   = 'Ranking';
  static const _usersTable     = 'users';
  static const _stepsTable     = 'steps';

  // ─── OPEN / UPGRADE DB ───────────────────────────────────────────────────
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir  = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'ecolife.db');
    log('Opening DB at $path');
    return openDatabase(
      path,
      version: 13,                     // bump once to drop “entries”
      onConfigure: (db) async =>
          db.execute('PRAGMA foreign_keys = ON'),
      onCreate : _onCreate,
      onUpgrade: _onUpgrade,
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
}