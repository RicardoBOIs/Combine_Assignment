// repository_service.dart
//
// One-stop façade that sits in front of BOTH local SQLite
// (via DatabaseService) and Firestore (via FirebaseService).
// – Firestore is always tried first
// – If offline / throws, we fall back to SQLite
//
// All “habit-tracking” logic now uses the new **entries** table
// (user_email, habitTitle, value, …) both locally and remotely.

import 'community_database_service.dart';
import 'community_firebase_database_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';
import 'ranking_model.dart';

class RepositoryService {
  RepositoryService._();

  static final instance = RepositoryService._();

  final _sql = DatabaseService();
  final _fb = FirebaseService.instance;

  // ─── COMMUNITIES ───────────────────────────────────────────────────────────

  Future<int> insertCommunity(CommunityMain c) async {
    // Insert locally first so we get the auto-id
    final id = await _sql.insertCommunity(c);
    // push to Firestore (id is now in the model)
    try {
      await _fb.saveCommunity(c.copyWith(id: id));
    } catch (_) {}
    return id;
  }

  Future<void> saveCommunity(CommunityMain c) async {
    await _sql.updateCommunity(c);
    try {
      await _fb.saveCommunity(c);
    } catch (_) {}
  }

  Future<List<CommunityMain>> getCommunities() async {
    try {
      return await _fb
          .streamCommunities()
          .first;
    } catch (_) {
      return _sql.getAllCommunities();
    }
  }

  Future<void> deleteCommunity(int communityID) async {
    await _sql.deleteCommunity(communityID);
    try {
      await _fb.deleteCommunity(communityID);
    } catch (_) {}
  }

  // ─── JOIN EVENTS ───────────────────────────────────────────────────────────

  Future<List<JoinEventModel>> getJoinsForCommunity(int communityID) async {
    try {
      return await _fb
          .streamJoinsForCommunity(communityID)
          .first;
    } catch (_) {
      return _sql.getJoinsForCommunity(communityID);
    }
  }

  Future<List<JoinEventModel>> getJoinsForUser(String email) async {
    try {
      return await _fb
          .streamJoinsForUser(email)
          .first;
    } catch (_) {
      return _sql.getJoinsForUser(email);
    }
  }

  Future<void> joinEvent(String email, int communityID) async {
    final model = JoinEventModel(
      email: email,
      communityID: communityID,
      joinedAt: DateTime.now(),
      status: 'joined',
    );
    await _sql.upsertJoinEvent(email, communityID, 'joined');
    try {
      await _fb.saveJoinEvent(model);
    } catch (_) {}
  }

  Future<void> exitEvent(String email, int communityID) async {
    await _sql.updateJoinEventStatus(email, communityID, 'exited');
    try {
      await _fb.updateJoinEventStatus(
        email: email,
        communityID: communityID,
        status: 'exited',
        recordExit: true,
      );
    } catch (_) {}
  }

  // ─── RANKINGS ─────────────────────────────────────────────────────────────

  Future<List<RankingModel>> getRankingsForCommunity(int communityID,
      {int limit = 50}) async {
    try {
      return await _fb
          .streamRankingsForCommunity(communityID)
          .first;
    } catch (_) {
      return _sql.getRankingsForCommunity(communityID, limit: limit);
    }
  }

  Future<RankingModel?> getRankingForUserInCommunity(String email,
      int communityID) async {
    try {
      final remote = await _fb.getRanking(email, communityID);
      if (remote != null) return remote;
    } catch (_) {}
    return _sql.getRankingForUserInCommunity(email, communityID);
  }

  Future<void> saveRanking(RankingModel r) async {
    await _sql.insertOrUpdateRanking(r);
    try {
      await _fb.saveRanking(r);
    } catch (_) {}
  }

  Future<void> deleteRanking(String email, int communityID) async {
    final local = await _sql.getRankingForUserInCommunity(email, communityID);
    if (local != null) await _sql.deleteRanking(local.id!);
    try {
      await _fb.deleteRanking(email, communityID);
    } catch (_) {}
  }


  // ─── STEPS ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStepsForUser(String email) async {
    try {
      return await _fb
          .streamStepsForUser(email)
          .first;
    } catch (_) {
      return _sql.getStepsForUser(userEmail: email);
    }
  }

  Future<void> saveStep(String id, Map<String, dynamic> s) async {
    await _sql.upsertStepCount(
      userEmail: s['user_email'] as String,
      day: s['day'] as String,
      count: (s['count'] as num).toDouble(),
    );
    try {
      await _fb.saveStep(id, s);
    } catch (_) {}
  }

  // ─── USERS & HABIT HELPERS ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUser(String email) async {
    try {
      final remote = await _fb.getUser(email);
      if (remote != null) return remote;
    } catch (_) {}
    final local = await _sql.getAllUsers();
    return local.firstWhere(
          (u) => u['email'] == email,
      orElse: () => {},
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      // 1️⃣ get every document from registered_users (or users) collection
      final remote = await _fb.streamUsers().first;

      // 2️⃣ cache/update in SQLite so we’re never behind when offline
      for (final u in remote) {
        await _sql.insertUser(u);        // insertUser does an upsert
      }
      return remote;
    } catch (_) {
      // 3️⃣ no network / Firebase error → local cache
      return _sql.getAllUsers();
    }
  }

  /* Sum of step-counts for a user (remote-first, fallback SQLite) */
  Future<int> _getStepTotal(String email) async {
    // --- try Firestore first
    try {
      final docs = await _fb
          .streamStepsForUser(email)
          .first;
      final total = docs.fold<double>(
        0,
            (sum, m) => sum + (m['count'] as num).toDouble(),
      );
      return total.round();
    } catch (_) {
      /* offline */
    }

    // --- fallback to SQLite
    final local = await _sql.getStepsForUser(userEmail: email);
    final total = local.fold<double>(
      0,
          (sum, m) => sum + (m['count'] as num).toDouble(),
    );
    return total.round();
  }


  // ─── CLEAN-UP ─────────────────────────────────────────────────────────────
  Future<void> close() async => _sql.close();

// ─── HABIT SCORE (remote first, then local) ───────────────────────────────
  Future<RankingModel> getHabitScoreForUserInCommunity(String email,
      int communityID, {
        required String habitTitle, // 'Step Counter'
      }) async {
    if (habitTitle != 'Step Counter') {
      return RankingModel(
          id: null,
          email: email,
          communityID: communityID,
          score: 0,
          lastUpdated: DateTime.now());
    }

    // 1.  Firestore first
    final remote = await _remoteStepTotal(email);
    if (remote >= 0) {
      return RankingModel(
        id: null,
        email: email,
        communityID: communityID,
        score: remote,
        lastUpdated: DateTime.now(),
      );
    }

    // 2.  Offline ⇒ SQLite
    return _sql.getHabitScoreForUserInCommunity(
      userEmail: email,
      communityID: communityID,
      habitTitle: habitTitle,
    );
  }

// ─── HABIT TITLES LIST ────────────────────────────────────────────────────
  Future<List<String>> getHabitTitles() async => ['Step Counter'];

// ─── everything else in the repo stays unchanged ──────────────────────────

  Future<int> _remoteStepTotal(String email) async {
    try {
      final docs = await _fb
          .streamStepsForUser(email)
          .first;
      return docs.fold<int>(0, (sum, m) => sum + (m['count'] as num).round());
    } catch (_) {
      return -1; // signal “offline / failed”
    }
  }
}
