import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

/// Enhanced Leaderboard Screen with Repository (Firebase-first, then SQLite)
class LeaderboardScreen extends StatefulWidget {
  final CommunityMain community;
  const LeaderboardScreen({Key? key, required this.community})
      : super(key: key);

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  final _repo = RepositoryService.instance;
  late Future<List<RankingDisplay>> _futureDisplayRankings;
  late AnimationController _animationController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _futureDisplayRankings = _loadLeaderboardData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          habitTitle: habit, // e.g. "Step Counter"
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
      _isRefreshing = true;
      _futureDisplayRankings = _loadLeaderboardData();
    });

    await _futureDisplayRankings;

    setState(() {
      _isRefreshing = false;
      _animationController.reset();
      _animationController.forward();
    });
  }

  Widget _buildEmptyState(String message, BoxConstraints constraints) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 80,
                color: Colors.green.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: _refreshLeaderboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.community.existLeaderboard != 'Yes' ||
        widget.community.typeOfLeaderboard == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          backgroundColor: Colors.green.shade700,
        ),
        body: _buildEmptyState(
          widget.community.existLeaderboard != 'Yes'
              ? 'Leaderboard is not enabled for this community.'
              : 'Leaderboard type is not configured.',
          BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.community.title} Leaderboard'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade500,
                Colors.green.shade800,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshLeaderboard,
            tooltip: 'Refresh leaderboard',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade50,
              Colors.white,
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshLeaderboard,
          color: Colors.green.shade700,
          backgroundColor: Colors.white,
          child: FutureBuilder<List<RankingDisplay>>(
            future: _futureDisplayRankings,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading leaderboard...',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load leaderboard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snap.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          onPressed: _refreshLeaderboard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final entries = snap.data ?? [];
              if (entries.isEmpty) {
                final msg = widget.community.typeOfLeaderboard == 'Auto Input Score'
                    ? 'No one has tracked "${widget.community.selectedHabitTitle}" yet.'
                    : 'No scores have been recorded yet.';
                return LayoutBuilder(builder: (context, constraints) {
                  return _buildEmptyState(msg, constraints);
                });
              }

              final lastUpdate = entries
                  .map((e) => e.lastUpdated)
                  .reduce((a, b) => a.isAfter(b) ? a : b);
              final lastUpdateStr =
              DateFormat('MMM d, yyyy h:mm a').format(lastUpdate);

              return Column(
                children: [
                  // Top winners podium
                  if (entries.length >= 2)
                    _buildTopWinnersSection(entries.take(3).toList()),

                  // Last updated info card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Card(
                      elevation: 0,
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.update, color: Colors.green.shade700, size: 18),
                                const SizedBox(width: 8),
                                const Text('Last updated:',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                            Text(
                              lastUpdateStr,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Leaderboard title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.leaderboard, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Full Rankings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Rankings List
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _buildRankingItem(entries[index], index)
                            .animate(
                          controller: _animationController,
                          delay: Duration(milliseconds: 60 * index),
                        )
                            .fadeIn(duration: const Duration(milliseconds: 300))
                            .slideX(
                          begin: 0.2,
                          end: 0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopWinnersSection(List<RankingDisplay> topEntries) {
    // Handle having fewer than 3 entries
    while (topEntries.length < 3) {
      topEntries.add(RankingDisplay(
        rank: topEntries.length + 1,
        userEmail: '',
        userName: '',
        score: 0,
        lastUpdated: DateTime.now(),
      ));
    }

    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green.shade100,
            Colors.green.shade50,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd place
              _buildWinnerPodium(
                topEntries[1],
                Colors.grey.shade300,
                Colors.grey.shade600,
                height: 100,
                width: 100,
                fontSize: 16,
                showScore: true,
              ),

              const SizedBox(width: 8),

              // 1st place
              _buildWinnerPodium(
                topEntries[0],
                Colors.amber.shade100,
                Colors.amber,
                height: 120,
                width: 120,
                fontSize: 18,
                showCrown: true,
                showScore: true,
              ),

              const SizedBox(width: 8),

              // 3rd place
              _buildWinnerPodium(
                topEntries[2],
                Colors.brown.shade100,
                Colors.brown.shade400,
                height: 80,
                width: 100,
                fontSize: 16,
                showScore: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerPodium(
      RankingDisplay ranking,
      Color bgColor,
      Color medalColor, {
        required double height,
        required double width,
        required double fontSize,
        bool showCrown = false,
        bool showScore = false,
      }) {
    // Skip empty entries (when we have fewer than 3 participants)
    if (ranking.userName.isEmpty) {
      return SizedBox(width: width);
    }

    return Column(
      children: [
        if (showCrown)
          Icon(Icons.emoji_events, color: Colors.amber, size: 32)
              .animate()
              .scale(
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            begin: const Offset(0.5, 0.5),
            end: const Offset(1.0, 1.0),
          )
              .then()
              .shimmer(
            duration: const Duration(seconds: 2),
            delay: const Duration(seconds: 1),
          ),

        SizedBox(
          height: height,
          width: width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: width / 4,
                backgroundColor: medalColor,
                child: Text(
                  '${ranking.rank}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  ranking.userName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize - 2,
                  ),
                ),
              ),
              if (showScore)
                Text(
                  '${ranking.score} pts',
                  style: TextStyle(
                    fontSize: fontSize - 4,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
            ],
          ),
        ),

        // Podium base
        Container(
          width: width,
          height: 20,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(5),
              topRight: Radius.circular(5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankingItem(RankingDisplay item, int index) {
    final isTop3 = item.rank <= 3;
    Color medalColor;
    IconData medalIcon;

    switch (item.rank) {
      case 1:
        medalColor = Colors.amber;
        medalIcon = Icons.emoji_events;
        break;
      case 2:
        medalColor = Colors.grey.shade400;
        medalIcon = Icons.emoji_events;
        break;
      case 3:
        medalColor = Colors.brown.shade400;
        medalIcon = Icons.emoji_events;
        break;
      default:
        medalColor = Colors.green.shade200;
        medalIcon = Icons.shield_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isTop3 ? 2 : 1,
        color: isTop3 ? Colors.white : Colors.grey.shade50,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isTop3
              ? BorderSide(color: medalColor.withOpacity(0.5), width: 1)
              : BorderSide.none,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: medalColor.withOpacity(0.2),
                child: Text(
                  '${item.rank}',
                  style: TextStyle(
                    color: medalColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isTop3)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(medalIcon, color: medalColor, size: 14),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.userName,
                  style: TextStyle(
                    fontWeight: isTop3 ? FontWeight.bold : FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.score}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Last activity: ${DateFormat('MMM d').format(item.lastUpdated)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}