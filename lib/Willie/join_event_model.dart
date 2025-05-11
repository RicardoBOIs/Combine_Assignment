// join_event_model.dart

class JoinEventModel {
  final int? id;
  final String email;
  final int communityID;
  final DateTime joinedAt;
  final String status;

  JoinEventModel({
    this.id,
    required this.email,
    required this.communityID,
    required this.joinedAt,
    required this.status,
  });

  factory JoinEventModel.fromJson(Map<String, dynamic> data) {
    return JoinEventModel(
      id: data['id'] as int?,
      email: data['email'] as String,
      communityID: data['communityID'] as int,
      joinedAt: DateTime.parse(data['joinedAt'] as String),
      status: data['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'email': email,
      'communityID': communityID,
      'joinedAt': joinedAt.toIso8601String(),  // ← 名称要和表定义严格吻合
      'status': status,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  JoinEventModel copyWith({
    int? id,
    String? email,
    int? communityID,
    DateTime? joinedAt,
    String? status,
  }) {
    return JoinEventModel(
      id: id ?? this.id,
      email: email ?? this.email,
      communityID: communityID ?? this.communityID,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
    );
  }

}
