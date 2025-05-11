import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';
import 'ranking_model.dart';

class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  final _firestore = FirebaseFirestore.instance;

  // top-level collections
  CollectionReference<Map<String, dynamic>> get _communities =>
      _firestore.collection('communities');

  CollectionReference<Map<String, dynamic>> get _registeredUsers =>
      _firestore.collection('Registered_users');

  CollectionReference<Map<String, dynamic>> get _joins =>
      _firestore.collection('joinEvents');

  CollectionReference<Map<String, dynamic>> get _rankings =>
      _firestore.collection('rankings');

  CollectionReference<Map<String, dynamic>> get _steps =>
      _firestore.collection('steps');

  // ───── COMMUNITIES ────────────────────────────────────────────────────────
  Future<void> saveCommunity(CommunityMain c) =>
      _communities.doc(c.id!.toString()).set(c.toMap());

  Future<CommunityMain?> getCommunity(int id) async {
    final snap = await _communities.doc(id.toString()).get();
    return snap.exists ? CommunityMain.fromJson(snap.data()!) : null;
  }

  Future<void> deleteCommunity(int id) =>
      _communities.doc(id.toString()).delete();

  Stream<List<CommunityMain>> streamCommunities() =>
      _communities.snapshots().map(
            (s) => s.docs.map((d) => CommunityMain.fromJson(d.data())).toList(),
      );

  // ───── REGISTERED USERS ───────────────────────────────────────────────────
  Future<void> saveUser(Map<String, dynamic> u) =>
      _registeredUsers.doc(u['email'] as String).set(u);

  Future<Map<String, dynamic>?> getUser(String email) async {
    final snap = await _registeredUsers.doc(email).get();
    return snap.exists ? snap.data() : null;
  }

  Future<void> deleteUser(String email) =>
      _registeredUsers.doc(email).delete();

  Stream<List<Map<String, dynamic>>> streamUsers() =>
      _registeredUsers.snapshots().map(
            (s) => s.docs.map((d) => d.data()).toList(),
      );

  // ───── JOIN EVENTS ────────────────────────────────────────────────────────
  Future<void> saveJoinEvent(JoinEventModel j) =>
      _joins.doc('${j.email}_${j.communityID}').set(j.toMap());

  Future<JoinEventModel?> getJoinEvent(String email, int communityID) async {
    final snap = await _joins.doc('$email\_$communityID').get();
    return snap.exists ? JoinEventModel.fromJson(snap.data()!) : null;
  }

  Future<void> updateJoinEventStatus({
    required String email,
    required int communityID,
    required String status,
    bool recordExit = false,
  }) {
    final data = <String, dynamic>{'status': status};
    if (recordExit) data['exitedAt'] = FieldValue.serverTimestamp();
    return _joins.doc('$email\_$communityID').update(data);
  }

  Future<void> deleteJoinEvent(String email, int communityID) =>
      _joins.doc('$email\_$communityID').delete();

  Stream<List<JoinEventModel>> streamJoinsForCommunity(int communityID) =>
      _joins.where('communityID', isEqualTo: communityID).snapshots().map(
            (s) => s.docs.map((d) => JoinEventModel.fromJson(d.data())).toList(),
      );

  Stream<List<JoinEventModel>> streamJoinsForUser(String email) =>
      _joins.where('email', isEqualTo: email).snapshots().map(
            (s) => s.docs.map((d) => JoinEventModel.fromJson(d.data())).toList(),
      );

  Future<List<JoinEventModel>> getJoinsForUser(String email) =>
      streamJoinsForUser(email).first;

  // ───── RANKINGS ───────────────────────────────────────────────────────────
  Future<void> saveRanking(RankingModel r) =>
      _rankings.doc('${r.email}_${r.communityID}').set(r.toMap());

  Future<RankingModel?> getRanking(String email, int communityID) async {
    final snap = await _rankings.doc('$email\_$communityID').get();
    return snap.exists ? RankingModel.fromJson(snap.data()!) : null;
  }

  Future<void> deleteRanking(String email, int communityID) =>
      _rankings.doc('$email\_$communityID').delete();

  Stream<List<RankingModel>> streamRankingsForCommunity(int communityID) =>
      _rankings
          .where('communityID', isEqualTo: communityID)
          .orderBy('score', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => RankingModel.fromJson(d.data())).toList());



  // ───── STEPS ──────────────────────────────────────────────────────────────
  Future<void> saveStep(String id, Map<String, dynamic> s) =>
      _steps.doc(id).set(s);

  Future<void> deleteStep(String id) => _steps.doc(id).delete();

  Stream<List<Map<String, dynamic>>> streamStepsForUser(String email) =>
      _steps.where('user_email', isEqualTo: email)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());

  // ─── HABIT TITLES ────────────────────────────────────────────────────────
  /// Cloud side always returns the single built-in habit.
  List<String> get habitTitlesRemote => ['Step Counter'];
}
