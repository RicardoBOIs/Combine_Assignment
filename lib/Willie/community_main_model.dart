class CommunityMain {
  final int? id; // nullable for new records
  final String title;
  final String typeOfEvent;
  final String shortDescription;
  final String description;
  final DateTime startDate;
  final DateTime endDate; // renamed from endStart
  final String location;
  final int capacity;
  final String termsAndConditions;
  final String? imagePath;
  final String existLeaderboard;
  final String? typeOfLeaderboard;
  final String? selectedHabitTitle;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommunityMain({
    this.id,
    required this.title,
    required this.typeOfEvent,
    required this.shortDescription,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.capacity,
    required this.termsAndConditions,
    required this.imagePath,
    required this.existLeaderboard,
    required this.typeOfLeaderboard,
    required this.selectedHabitTitle,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create CommunityMain from JSON (database row)
  factory CommunityMain.fromJson(Map<String, dynamic> json) {
    return CommunityMain(
      id: json['id'],
      title: json['title'],
      typeOfEvent: json['typeOfEvent'],
      shortDescription: json['shortDescription'],
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      location: json['location'],
      capacity: json['capacity'],
      termsAndConditions: json['termsAndConditions'],
      imagePath: json['imagePath'],
      existLeaderboard: json['existLeaderboard'],
      typeOfLeaderboard: json['typeOfLeaderboard'],
      selectedHabitTitle: json['selectedHabitTitle'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Convert CommunityMain to JSON (for database operations)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'typeOfEvent': typeOfEvent,
      'shortDescription': shortDescription,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'location': location,
      'capacity': capacity,
      'termsAndConditions': termsAndConditions,
      'imagePath' : imagePath,
      'existLeaderboard' : existLeaderboard,
      'typeOfLeaderboard' : typeOfLeaderboard,
      'selectedHabitTitle' : selectedHabitTitle,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create a copy of this community with modified fields
  CommunityMain copyWith({
    int? id,
    String? title,
    String? typeOfEvent,
    String? shortDescription,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    int? capacity,
    String? termsAndConditions,
    String? imagePath,
    String? existLeaderboard,
    String? typeOfLeaderboard,
    String? selectedHabitTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityMain(
      id: id ?? this.id,
      title: title ?? this.title,
      typeOfEvent: typeOfEvent ?? this.typeOfEvent,
      shortDescription: shortDescription ?? this.shortDescription,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      imagePath: imagePath ?? this.imagePath,
      existLeaderboard: existLeaderboard ?? this.existLeaderboard,
      typeOfLeaderboard: typeOfLeaderboard ?? this.typeOfLeaderboard,
      selectedHabitTitle: selectedHabitTitle ?? this.selectedHabitTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Community: $title (ID: $id)';
  }
}