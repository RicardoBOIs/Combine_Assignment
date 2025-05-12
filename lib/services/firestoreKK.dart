import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:firebase_auth/firebase_auth.dart'; // Ensure this is imported if you use it elsewhere in this file

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Helper to get the reference to the daily records subcollection for a specific user
  // Path: check-in/{userEmail}/days
  CollectionReference _userDailyCollection(String userEmail) {
    // Collection name is 'check-in'
    // User's email as document ID
    // 'days' subcollection for daily records
    return _db.collection('check-in')
        .doc(userEmail)
        .collection('days');
  }

  // Save a daily record (as a Map) for a user and date.
  // The document ID will be the date string (YYYY-MM-DD).
  // The map will contain only the necessary daily data.
  Future<void> saveDailyRecord(String userEmail, String dateId, Map<String, dynamic> dailyData) async {
    // Ensure date ID and user email are valid before saving
    if (dateId.isEmpty || userEmail.isEmpty) {
      print('Error: Cannot save daily record without date ID or User Email.');
      throw StateError('Date ID or User Email is missing.');
    }
    try {
      // Use set with merge: true to add or update the document by its date ID within the nested path
      await _userDailyCollection(userEmail).doc(dateId).set(dailyData, SetOptions(merge: true));
    } catch (e) {
      print('Error saving daily record $dateId for user $userEmail to Firestore: $e');
      throw e;
    }
  }

  // Get the latest daily record (as a Map) for a specific user
  // This is used to determine the current cumulative tree stage by finding the last recorded stage.
  Future<Map<String, dynamic>?> getLatestDailyRecord(String userEmail) async {
    try {
      final QuerySnapshot snapshot = await _userDailyCollection(userEmail)
          .orderBy('checkInTimestamp', descending: true) // Order by exact check-in time to find the latest
          .limit(1) // Get only the most recent one
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Return the data as a Map
        return snapshot.docs.first.data() as Map<String, dynamic>;
      }
      return null; // No daily records found for this user
    } catch (e) {
      print('Error getting latest daily record for user $userEmail from Firestore: $e');
      throw e;
    }
  }

  // Get the total count of daily records for a specific user
  Future<int> getCheckInCount(String userEmail) async {
    try {
      final QuerySnapshot snapshot = await _userDailyCollection(userEmail).get();
      return snapshot.docs.length; // Return the number of documents
    } catch (e) {
      print('Error getting check-in count for user $userEmail from Firestore: $e');
      throw e; // Re-throw to allow calling code to handle errors
    }
  }
}