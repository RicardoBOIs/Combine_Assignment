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
      version: 1, // Start version at 1
      onCreate: _onCreate,
      // If you need to update the schema later, you'll need onUpgrade
      // onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table for daily check-in records per user, habit, and date
    await db.execute('''
      CREATE TABLE daily_records(
        dateId TEXT, -- Date string (YYYY-MM-DD) - used as part of composite key
        userId TEXT, -- User ID - used as part of composite key
        habitId TEXT, -- Habit ID - used as part of composite key
        checkInTimestamp TEXT, -- Store exact check-in time as ISO 8601 string
        treeGrowthStageOnDay INTEGER, -- Cumulative stage reached after this check-in
        createdAt TEXT, -- Store creation timestamp as ISO 8601 string
        PRIMARY KEY (dateId, userId, habitId) -- Composite primary key
      )
    ''');
    // Removed habits table creation as it's not stored in this DatabaseHelper version
  }

  // --- Daily Record Operations ---

  // Save a daily record (insert or replace)
  // dateId should be in YYYY-MM-DD format
  Future<int> saveDailyRecord(String userId, String habitId, String dateId, Map<String, dynamic> dailyData) async {
    final db = await database;
    // Ensure required data is present
    if (dateId.isEmpty || userId.isEmpty || habitId.isEmpty) {
      print('Error: Cannot save daily record without date ID, User ID, or Habit ID.');
      return 0; // Indicate failure
    }
    // Prepare data for insertion, ensuring correct types and including composite key parts
    final Map<String, dynamic> dataToInsert = {
      'dateId': dateId,
      'userId': userId,
      'habitId': habitId,
      'checkInTimestamp': dailyData['checkInTimestamp'], // Should already be ISO 8601 string from CheckInPage
      'treeGrowthStageOnDay': dailyData['treeGrowthStageOnDay'],
      'createdAt': dailyData['createdAt'], // Should already be ISO 8601 string from CheckInPage
      // Add other fields if they are in dailyData and needed in the table
    };

    return await db.insert(
      'daily_records',
      dataToInsert,
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if (dateId, userId, habitId) composite key exists
    );
  }

  // Get the latest daily record for a specific user and habit
  Future<Map<String, dynamic>?> getLatestDailyRecord(String userId, String habitId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_records',
      where: 'userId = ? AND habitId = ?',
      whereArgs: [userId, habitId],
      orderBy: 'checkInTimestamp DESC', // Order by timestamp descending to get the latest
      limit: 1, // Get only the most recent one
    );
    if (maps.isNotEmpty) {
      return maps.first; // Return the data as a Map
    }
    return null; // No records found
  }

  // Get the total count of daily records for a specific user and habit
  Future<int> getCheckInCount(String userId, String habitId) async {
    final db = await database;
    // Use count(*) to get the number of rows
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) FROM daily_records WHERE userId = ? AND habitId = ?',
      [userId, habitId],
    );
    int count = Sqflite.firstIntValue(result) ?? 0; // Get the count value
    return count;
  }


// --- Removed previous methods (if they were still here) ---
// getHabit, updateHabit, getUserHabits, deleteHabit (for cumulative habits)
// addCheckIn, getCheckInCount, getLastCheckInTime, getCheckInHistory (for old check_in_event structure)

// Example onUpgrade function if you were incrementing version
// Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//   if (oldVersion < 1) { // Example: upgrading from version 0 to 1
//     // Add the daily_records table if it didn't exist
//   }
//   if (oldVersion < 2) { // Example: upgrading from version 1 to 2
//      await db.execute('''
//        ALTER TABLE daily_records ADD COLUMN newField TEXT;
//      ''');
//   }
// }
}
