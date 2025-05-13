// lib/ranking_model.dart

class RankingModel {
  final int? id; // <--- Changed from 'int' to 'int?'
  final String email;
  final int communityID;
  final int score;
  // Assuming lastUpdated is DateTime in the model for consistency.
  // If it's a String, ensure parsing/formatting is handled correctly.
  final DateTime lastUpdated;

  RankingModel({
    this.id, // <--- No longer 'required this.id', now it's optional and can be null
    required this.email,
    required this.communityID,
    required this.score,
    required this.lastUpdated,
  });

  // Factory constructor to create a RankingModel from a map (e.g., from SQLite)
  factory RankingModel.fromJson(Map<String, dynamic> json) {
    return RankingModel(
      id: json['id'] as int?, // Can be null from DB or if key doesn't exist
      email: json['email'] as String,
      communityID: json['communityID'] as int,
      score: json['score'] as int,
      // Assuming 'lastUpdated' is stored as an ISO8601 string in the database
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  // Method to convert a RankingModel instance to a map (e.g., for SQLite insertion)
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Will be null if the model instance doesn't have an ID (e.g., before insertion)
      'email': email,
      'communityID': communityID,
      'score': score,
      // Storing DateTime as an ISO8601 string in the database
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // Optional: A copyWith method can be useful
  RankingModel copyWith({
    int? id,
    String? email,
    int? communityID,
    int? score,
    DateTime? lastUpdated,
  }) {
    return RankingModel(
      id: id ?? this.id,
      email: email ?? this.email,
      communityID: communityID ?? this.communityID,
      score: score ?? this.score,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}