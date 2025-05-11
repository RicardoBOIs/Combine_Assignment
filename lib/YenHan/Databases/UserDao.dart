import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class UserDao {
  final _db = DatabaseService.instance;

  //Register User
  Future<void> EnsureUser({
    required String email,
    required String username,
    required String phone,
    required String location,
  }) async {
    final db = await _db.database;


    await db.insert(
      'users',
      {
        'email': email,
        'username': username,
        'phone': phone,
        'location': location,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }


  //Update existing user profile by email

  Future<void> updateProfile({
    required String email,
    String? username,
    String? phone,
    String? location,
  }) async {
    final db = await _db.database;

    final Map<String, Object?> data = {};
    if (username != null) data['username'] = username;
    if (phone    != null) data['phone']    = phone;
    if (location != null) data['location'] = location;

    if (data.isEmpty) return;                             // nothing to update

    await db.update(
      'users',
      data,
      where: 'email = ?',
      whereArgs: [email],
    );
  }
}
