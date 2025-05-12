import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  String? id; // Unique ID for the habit/challenge (e.g., 'daily_eco_check_in')
  final String userId; // ID of the user this habit belongs to
  final String name;
  int currentTreeGrowthStage; // Store the current cumulative growth stage
  DateTime? lastCheckInDate; // To track the last check-in date for this habit

  Habit({
    this.id, // Should be the challengeId
    required this.userId, // User ID is now required
    required this.name,
    this.currentTreeGrowthStage = 0, // Default to 0
    this.lastCheckInDate,
  });

  // Convert a Habit object into a Map for SQLite (for caching cumulative state)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'currentTreeGrowthStage': currentTreeGrowthStage,
      'lastCheckInDate': lastCheckInDate?.toIso8601String(), // Store as ISO 8601 string
    };
  }

  // Convert a Map from SQLite to a Habit object
  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      currentTreeGrowthStage: map['currentTreeGrowthStage'] ?? 0,
      lastCheckInDate: map['lastCheckInDate'] != null
          ? DateTime.tryParse(map['lastCheckInDate'])
          : null,
    );
  }

  // Convert a Habit object to a Map for Firestore (for cumulative state)
  Map<String, dynamic> toFirestore() {
    return {
      // 'id': id, // Firestore document ID will be used as the ID
      'userId': userId, // Include user ID
      'name': name,
      'currentTreeGrowthStage': currentTreeGrowthStage,
      'lastCheckInDate': lastCheckInDate != null
          ? Timestamp.fromDate(lastCheckInDate!) // Firestore uses Timestamp
          : null,
      // Optional metadata timestamps
      'createdAt': FieldValue.serverTimestamp(), // Will only be set on creation
      'updatedAt': FieldValue.serverTimestamp(), // Will be updated on each save
    };
  }

  // Convert a DocumentSnapshot from Firestore to a Habit object
  factory Habit.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Habit(
      id: doc.id, // Use Firestore document ID as Habit ID
      userId: data['userId'] ?? '', // Read user ID
      name: data['name'] ?? '',
      currentTreeGrowthStage: data['currentTreeGrowthStage'] ?? 0,
      lastCheckInDate: data['lastCheckInDate'] != null
          ? (data['lastCheckInDate'] as Timestamp).toDate()
          : null,
    );
  }

  // For printing/debugging
  @override
  String toString() {
    return 'Habit{id: $id, userId: $userId, name: $name, currentTreeGrowthStage: $currentTreeGrowthStage, lastCheckInDate: $lastCheckInDate}';
  }

  // A helper method to create a copy with updated values
  Habit copyWith({
    String? id,
    String? userId,
    String? name,
    int? currentTreeGrowthStage,
    DateTime? lastCheckInDate,
  }) {
    return Habit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      currentTreeGrowthStage: currentTreeGrowthStage ?? this.currentTreeGrowthStage,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
    );
  }
}