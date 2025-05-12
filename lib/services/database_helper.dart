import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// Removed: import 'package:assignment_test/models/check_in_challenge.dart'; // Not needed for this DatabaseHelper version
// Removed: import 'dart:convert'; // Import for JSON encoding/decoding (not needed for minimal map)

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'user_eco_daily_records.db'); // Changed database name

    return await openDatabase(
      dbPath,
      version: 1, // Start version at 1. If you had data, you'd increment this and use onUpgrade.
      onCreate: _onCreate,
      // If you need to update the schema later and keep data, you'll need onUpgrade
      // onUpgrade: _onUpgrade, // Example _onUpgrade function is commented below
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table for daily check-in records per user and date
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
  }

  // --- Daily Record Operations ---

  // Save a daily record (insert or replace)
  // dateId should be in YYYY-MM-DD format
  // Removed habitId from parameters
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

// Example _onUpgrade function if you were incrementing version
// Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//   if (oldVersion < 1) { // Example: upgrading from version 0 to 1 (assuming initial schema was empty or different)
//     // This would be your _onCreate content if you're migrating from nothing or adding the table
//     await db.execute('''
//       CREATE TABLE daily_records(
//         dateId TEXT,
//         userId TEXT,
//         habitId TEXT, -- If you still wanted this column here
//         checkInTimestamp TEXT,
//         treeGrowthStageOnDay INTEGER,
//         createdAt TEXT,
//         PRIMARY KEY (dateId, userId, habitId)
//       )
//     ''');
//   }
//   if (oldVersion < 2 && newVersion >= 2) { // Example: upgrading from version 1 to 2
//      // If you had habitId and wanted to remove it
//      await db.execute('CREATE TABLE daily_records_new ('
//                       'dateId TEXT,'
//                       'userId TEXT,'
//                       'checkInTimestamp TEXT,'
//                       'treeGrowthStageOnDay INTEGER,'
//                       'createdAt TEXT,'
//                       'PRIMARY KEY (dateId, userId)'
//                       ')');
//      // Copy data from old table to new table, excluding habitId
//      await db.execute('INSERT INTO daily_records_new (dateId, userId, checkInTimestamp, treeGrowthStageOnDay, createdAt) '
//                       'SELECT dateId, userId, checkInTimestamp, treeGrowthStageOnDay, createdAt FROM daily_records');
//      await db.execute('DROP TABLE daily_records');
//      await db.execute('ALTER TABLE daily_records_new RENAME TO daily_records');
//   }
// }
}