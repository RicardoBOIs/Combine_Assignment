import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'CarbonFootprint.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  //Save Daily FootPrint
  Future<void> saveDailyFootprint(double kgCO2e) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // ── date parts ───────────────────────────────────────────────
    final today     = DateTime.now();
    final midnight  = DateTime(today.year, today.month, today.day);
    final dateId    = DateFormat('yyyy-MM-dd').format(midnight);
    final email     = user.email!;

    // ── payload ─────────────────────────────────────────────────
    final footprint = CarbonFootprint(
      uid : email,
      date: Timestamp.fromDate(midnight),
      kgCO2e: kgCO2e,
    ).toJson();


    await _db
        .collection('daily_Carbon_FootPrint_record')
        .doc(email)
        .collection('days')
        .doc(dateId)
        .set(footprint, SetOptions(merge: true));

  }

  // Update and Save user profile
  Future<void> saveUserProfile({
    required String username,
    required String phone,
    required String location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    await _db
        .collection('Registered_users')
        .doc(user.email)
        .set({
      'email': user.email,
      'username': username,
      'phone': phone,
      'location': location,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


}
