import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInEvent {
  String? id; // Optional: Local ID for SQLite, or Firestore Document ID
  final String userId; // ID of the user who performed the check-in
  final String challengeId; // ID of the habit/challenge
  final DateTime timestamp; // The time the check-in occurred

  CheckInEvent({
    this.id,
    required this.userId,
    required this.challengeId,
    required this.timestamp,
  });

  // Convert a CheckInEvent object into a Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      // 'id': id, // SQLite can auto-generate primary key
      'userId': userId,
      'challengeId': challengeId,
      'timestamp': timestamp.toIso8601String(), // Store as ISO 8601 string
    };
  }

  // Convert a Map from SQLite to a CheckInEvent object
  factory CheckInEvent.fromMap(Map<String, dynamic> map) {
    return CheckInEvent(
      id: map['id']?.toString(), // SQLite ID might be int, convert to String
      userId: map['userId'],
      challengeId: map['challengeId'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // Convert a CheckInEvent object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'challengeId': challengeId,
      'timestamp': Timestamp.fromDate(timestamp), // Firestore uses Timestamp
    };
  }

  // Convert a DocumentSnapshot from Firestore to a CheckInEvent object
  factory CheckInEvent.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return CheckInEvent(
      id: doc.id, // Use Firestore document ID as the ID
      userId: data['userId'] ?? '',
      challengeId: data['challengeId'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(), // Provide a default if timestamp is missing
    );
  }

  @override
  String toString() {
    return 'CheckInEvent{id: $id, userId: $userId, challengeId: $challengeId, timestamp: $timestamp}';
  }
}
