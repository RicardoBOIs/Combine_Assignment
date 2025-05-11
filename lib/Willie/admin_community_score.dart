// admin_community_score.dart
import 'package:flutter/material.dart';
import 'community_repository_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';
import 'ranking_model.dart';

/// Admin page that lets you enter / edit scores.
/// User profiles come from **getAllUsers()** (Firebase → SQLite fallback).
class ScoreInputScreen extends StatefulWidget {
  final CommunityMain community;
  const ScoreInputScreen({Key? key, required this.community}) : super(key: key);

  @override
  State<ScoreInputScreen> createState() => _ScoreInputScreenState();
}

class _ScoreInputScreenState extends State<ScoreInputScreen> {
  final _repo = RepositoryService.instance;

  late Future<void> _init;
  List<JoinEventModel> _joins = [];
  Map<String, Map<String, dynamic>> _userByEmail = {};
  Map<String, TextEditingController> _ctrl = {};
  String? _editing;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init = _load();
  }

  Future<void> _load() async {
    final cid = widget.community.id!;

    //-------------------------------------------------------------
    // 1️⃣ joined rows
    //-------------------------------------------------------------
    _joins = (await _repo.getJoinsForCommunity(cid))
        .where((j) => j.status == 'joined')
        .toList();

    //-------------------------------------------------------------
    // 2️⃣ ALL users – single call, remote first
    //-------------------------------------------------------------
    final users = await _repo.getAllUsers();
    _userByEmail = {for (var u in users) u['email'] as String: u};

    //-------------------------------------------------------------
    // 3️⃣ make sure every join has a profile
    //-------------------------------------------------------------
    for (final j in _joins) {
      _userByEmail[j.email] ??= {
        'email': j.email,
        'username': j.email,
        'phone': '',
        'location': '',
      };
    }

    //-------------------------------------------------------------
    // 4️⃣ existing scores → controllers
    //-------------------------------------------------------------
    _ctrl.clear();
    for (final j in _joins) {
      final rank = await _repo.getRankingForUserInCommunity(j.email, cid);
      final score = rank?.score ?? 0;
      _ctrl[j.email] =
          TextEditingController(text: score > 0 ? score.toString() : '');
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cid = widget.community.id!;
    final now = DateTime.now();

    for (final entry in _ctrl.entries) {
      final email = entry.key;
      final newScore = int.tryParse(entry.value.text.trim()) ?? 0;
      final existing = await _repo.getRankingForUserInCommunity(email, cid);

      if (newScore <= 0) {
        if (existing != null) await _repo.deleteRanking(email, cid);
      } else {
        final model = existing != null
            ? existing.copyWith(score: newScore, lastUpdated: now)
            : RankingModel(
          id: 0,
          email: email,
          communityID: cid,
          score: newScore,
          lastUpdated: now,
        );
        await _repo.saveRanking(model);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scores • ${widget.community.title}'),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder<void>(
        future: _init,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          //---------------------------------------------------------
          // search filter
          //---------------------------------------------------------
          final term = _search.toLowerCase();
          final joins = _joins.where((j) {
            final u = _userByEmail[j.email]!;
            return (u['username'] as String).toLowerCase().contains(term) ||
                j.email.toLowerCase().contains(term) ||
                (u['phone'] as String).toLowerCase().contains(term);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search…',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Expanded(
                child: joins.isEmpty
                    ? const Center(child: Text('No participants'))
                    : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: joins.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final j = joins[i];
                    final u = _userByEmail[j.email]!;
                    final editing = _editing == j.email;

                    return ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(u['username'] as String),
                      subtitle: Text(u['phone'] as String),
                      trailing: editing
                          ? SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _ctrl[j.email],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Score',
                            isDense: true,
                          ),
                        ),
                      )
                          : Text(_ctrl[j.email]!.text.isEmpty
                          ? '0'
                          : _ctrl[j.email]!.text),
                      onTap: () =>
                          setState(() => _editing = editing ? null : j.email),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save Changes'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
