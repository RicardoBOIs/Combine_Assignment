import 'package:cloud_firestore/cloud_firestore.dart';
// Removed: import 'package:assignment_test/models/daily_footprint.dart'; // Not using DailyFootprint model
import 'package:intl/intl.dart'; // Import for date formatting

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Helper to get the reference to the daily records subcollection for a specific habit and user
  // Path: users/{userId}/habits/{habitId}/days
  CollectionReference _userHabitDailyCollection(String userId, String habitId) {
    // Using users/{userId}/habits/{habitId}/days based on the requested structure
    return _db.collection('users')
        .doc(userId) // User's UID
        .collection('habits') // Habits subcollection
        .doc(habitId) // Specific habit document
        .collection('days'); // Daily records subcollection
  }

  // Save a daily record (as a Map) for a user, habit, and date.
  // The document ID will be the date string (YYYY-MM-DD).
  // The map will contain only the necessary daily data.
  Future<void> saveDailyRecord(String userId, String habitId, String dateId, Map<String, dynamic> dailyData) async {
    // Ensure date ID, user ID, and habit ID are valid before saving
    if (dateId.isEmpty || userId.isEmpty || habitId.isEmpty) {
      print('Error: Cannot save daily record without date ID, User ID, or Habit ID.');
      throw StateError('Date ID, User ID, or Habit ID is missing.');
    }
    try {
      // Use set with merge: true to add or update the document by its date ID within the nested path
      await _userHabitDailyCollection(userId, habitId).doc(dateId).set(dailyData, SetOptions(merge: true));
    } catch (e) {
      print('Error saving daily record $dateId for user $userId and habit $habitId to Firestore: $e');
      throw e;
    }
  }

  // Get the latest daily record (as a Map) for a specific habit and user
  // This is used to determine the current cumulative tree stage by finding the last recorded stage.
  Future<Map<String, dynamic>?> getLatestDailyRecord(String userId, String habitId) async {
    try {
      final QuerySnapshot snapshot = await _userHabitDailyCollection(userId, habitId)
      // No need to filter by habitId here as it's part of the collection path
          .orderBy('checkInTimestamp', descending: true) // Order by exact check-in time to find the latest
          .limit(1) // Get only the most recent one
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Return the data as a Map
        return snapshot.docs.first.data() as Map<String, dynamic>;
      }
      return null; // No daily records found for this habit and user
    } catch (e) {
      print('Error getting latest daily record for user $userId and habit $habitId from Firestore: $e');
      throw e;
    }
  }

  // Get the total count of daily records for a specific habit and user
  Future<int> getCheckInCount(String userId, String habitId) async {
    try {
      final QuerySnapshot snapshot = await _userHabitDailyCollection(userId, habitId).get();
      return snapshot.docs.length; // Return the number of documents
    } catch (e) {
      print('Error getting check-in count for user $userId and habit $habitId from Firestore: $e');
      throw e; // Re-throw to allow calling code to handle errors
    }
  }

// --- Removed previous methods not relevant to this structure ---
// getHabit, saveHabit (for cumulative state), getUserHabits, deleteHabit, addCheckIn, getCheckInCount, getLastCheckInTime, getCheckInHistory
}
