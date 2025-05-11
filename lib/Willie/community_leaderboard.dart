import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'community_repository_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';
import 'ranking_model.dart';

// Data class for displaying leaderboard entries
class RankingDisplay {
  final int rank;
  final String userEmail;
  final String userName;
  final int score;
  final DateTime lastUpdated;

  RankingDisplay({
    required this.rank,
    required this.userEmail,
    required this.userName,
    required this.score,
    required this.lastUpdated,
  });
}

/// Leaderboard Screen with Repository (Firebase-first, then SQLite)
class LeaderboardScreen extends StatefulWidget {
  final CommunityMain community;
  const LeaderboardScreen({Key? key, required this.community})
      : super(key: key);

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _repo = RepositoryService.instance;
  late Future<List<RankingDisplay>> _futureDisplayRankings;

  @override
  void initState() {
    super.initState();
    _futureDisplayRankings = _loadLeaderboardData();
  }

  Future<List<RankingDisplay>> _loadLeaderboardData() async {
    // 1) Fetch joined users (remote-first, then local)
    final joins = await _repo.getJoinsForCommunity(widget.community.id!);
    final joined = joins.where((j) => j.status == 'joined').toList();
    if (joined.isEmpty) return [];

    // 2) Fetch raw rankings (remote-first, then local)
    List<RankingModel> rawRankings;
    if (widget.community.typeOfLeaderboard == 'Manually Input Score') {
      rawRankings = await _repo.getRankingsForCommunity(widget.community.id!);
      // keep only those still joined
      final joinedEmails = joined.map((j) => j.email).toSet();
      rawRankings =
          rawRankings.where((r) => joinedEmails.contains(r.email)).toList();
    } else if (widget.community.typeOfLeaderboard == 'Auto Input Score') {
      final habit = widget.community.selectedHabitTitle;
      if (habit == null) return [];

      // get a score for every joined user, remote-first then local
      rawRankings = await Future.wait(
        joined.map((j) => _repo.getHabitScoreForUserInCommunity(
          j.email,
          widget.community.id!,
          habitTitle: habit, // e.g. “Step Counter”
        )),
      );

    }
    else {
      return [];
    }

    // 3) Load all users for name mapping (local only)
    final usersList = await _repo.getAllUsers();
    final nameByEmail = <String, String>{};
    for (var u in usersList) {
      final email = u['email'] as String?;
      final username = u['username'] as String?;
      if (email != null && username != null) {
        nameByEmail[email] = username;
      }
    }

    // 4) Filter, sort, build display list
    final valid = rawRankings.where((r) => r.score > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final display = <RankingDisplay>[];
    for (var i = 0; i < valid.length; i++) {
      final r = valid[i];
      final dt = r.lastUpdated is String
          ? DateTime.parse(r.lastUpdated as String)
          : r.lastUpdated as DateTime;
      display.add(RankingDisplay(
        rank: i + 1,
        userEmail: r.email,
        userName: nameByEmail[r.email] ?? r.email,
        score: r.score,
        lastUpdated: dt,
      ));
    }
    return display;
  }

  Future<void> _refreshLeaderboard() async {
    setState(() {
      _futureDisplayRankings = _loadLeaderboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.community.existLeaderboard != 'Yes' ||
        widget.community.typeOfLeaderboard == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          backgroundColor: Colors.grey[700],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.community.existLeaderboard != 'Yes'
                  ? 'Leaderboard is not enabled.'
                  : 'Leaderboard type is not set.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.community.title} Leaderboard'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLeaderboard,
        color: Theme.of(context).primaryColor,
        child: FutureBuilder<List<RankingDisplay>>(
          future: _futureDisplayRankings,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load leaderboard.\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }
            final entries = snap.data ?? [];
            if (entries.isEmpty) {
              final msg =
              widget.community.typeOfLeaderboard == 'Auto Input Score'
                  ? 'No one has tracked \"${widget.community.selectedHabitTitle}\" yet.'
                  : 'No scores yet.';
              return LayoutBuilder(builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          msg,
                          textAlign: TextAlign.center,
                          style:
                          TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
                );
              });
            }

            final lastUpdate = entries
                .map((e) => e.lastUpdated)
                .reduce((a, b) => a.isAfter(b) ? a : b);
            final lastUpdateStr =
            DateFormat('MMM d, yyyy h:mm a').format(lastUpdate);

            return Column(
              children: [
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last updated:',
                          style: TextStyle(color: Colors.grey)),
                      Text(lastUpdateStr,
                          style:
                          const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: entries.length,
                    itemBuilder: (c, i) {
                      final item = entries[i];
                      final isTop3 = item.rank <= 3;
                      Color medalColor;
                      switch (item.rank) {
                        case 1:
                          medalColor = Colors.amber;
                          break;
                        case 2:
                          medalColor = Colors.grey;
                          break;
                        case 3:
                          medalColor = Colors.brown;
                          break;
                        default:
                          medalColor = Colors.blueGrey;
                      }
                      return Card(
                        elevation: isTop3 ? 4 : 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: medalColor,
                            child: Text('${item.rank}',
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(item.userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text('Score: ${item.score}'),
                          trailing:
                          Icon(Icons.emoji_events, color: medalColor),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
