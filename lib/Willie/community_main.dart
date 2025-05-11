// community_challenges_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'community_repository_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';
import 'community_leaderboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
/// Community Challenges List Page with search, filter, ordering, and RepositoryService sync
class CommunityChallengesScreen extends StatefulWidget {
  const CommunityChallengesScreen({Key? key}) : super(key: key);

  @override
  State<CommunityChallengesScreen> createState() =>
      _CommunityChallengesScreenState();
}

class _CommunityChallengesScreenState extends State<CommunityChallengesScreen> {
  final _repo = RepositoryService.instance;
  late Future<List<CommunityMain>> _futureCommunities;
  late final String currentEmail;         // non-nullable
  late Future<void> _initialSync;


  String _searchTerm = '';
  String _selectedType = 'All';
  final List<String> _allEventTypes = [
    'All',
    'Workshop',
    'Seminar',
    'Meetup',
    'Competition',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    // Fail fast in debug if the page is opened without a user
    final user = FirebaseAuth.instance.currentUser;
    assert(user != null && user.email != null,
    'CommunityMain must be opened after a successful login.');
    currentEmail = user!.email!;
    _initialSync = _repo.syncAllForUser(currentEmail);
    _reloadAll();
  }


  void _reloadAll() {
    setState(() {
      _futureCommunities = _repo.getCommunities();
    });
  }

  Future<List<Object>> _joinInfo(int communityId) {
    // returns [hasJoined, joinCount]
    return Future.wait([
      _repo
          .getJoinsForUser(currentEmail)
          .then((joins) => joins.any((j) =>
      j.communityID == communityId && j.status == 'joined')),
      _repo
          .getJoinsForCommunity(communityId)
          .then((joins) => joins.where((j) => j.status == 'joined').length),
    ]);
  }

  void _showEventDetail(BuildContext ctx, CommunityMain cm, bool joined, int joinCount) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          community: cm,
          email: currentEmail,
          joined: joined,
          joinCount: joinCount,
          onJoinConfirmed: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Joined')));
            _reloadAll();
          },
          onExitConfirmed: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Exited')));
            _reloadAll();
          },
        ),
      ),
    );
  }

  void _showLeaderboard(BuildContext ctx, CommunityMain cm) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => LeaderboardScreen(community: cm)),
    );
  }

  Widget _buildImage(CommunityMain c) {
    if (c.imagePath != null && File(c.imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(c.imagePath!), fit: BoxFit.cover),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset('assets/images/default.jpg', fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialSync,                     // wait for Firestore → SQLite sync
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // still syncing – show a spinner
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // sync finished – build the normal UI
        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Challenges',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: FutureBuilder<List<CommunityMain>>(
          future: _futureCommunities,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            var comms = snap.data ?? [];

            // Search & filter
            comms = comms.where((c) {
              final term = _searchTerm.toLowerCase();
              final byTitle = c.title.toLowerCase().contains(term);
              final byDesc =
              c.shortDescription.toLowerCase().contains(term);
              final byType =
                  _selectedType == 'All' || c.typeOfEvent == _selectedType;
              return (byTitle || byDesc) && byType;
            }).toList();

            return Column(
              children: [
                // Search bar
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search events…',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (t) => setState(() => _searchTerm = t),
                ),
                const SizedBox(height: 8),
                // Type filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _allEventTypes.map((type) {
                      final selected = type == _selectedType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: selected,
                          selectedColor: Colors.green.shade300,
                          onSelected: (_) =>
                              setState(() => _selectedType = type),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // Build list with join info
                FutureBuilder<List<List<Object>>>(
                  future:
                  Future.wait(comms.map((c) => _joinInfo(c.id!))),
                  builder: (ctx2, infoSnap) {
                    if (infoSnap.connectionState == ConnectionState.waiting) {
                      return const Expanded(
                          child: Center(child: CircularProgressIndicator()));
                    }
                    if (infoSnap.hasError) {
                      return Expanded(
                          child:
                          Center(child: Text('Error: ${infoSnap.error}')));
                    }
                    final infos = infoSnap.data!;
                    final items = <Map<String, dynamic>>[];
                    for (var i = 0; i < comms.length; i++) {
                      final c = comms[i];
                      final hasJoined = infos[i][0] as bool;
                      final count = infos[i][1] as int;
                      final expired = c.endDate.isBefore(now);
                      final full = count >= c.capacity;
                      final status = expired ? 2 : (full ? 1 : 0);
                      items.add({
                        'community': c,
                        'joined': hasJoined,
                        'joinCount': count,
                        'status': status,
                      });
                    }
                    // Sort: available → full → expired
                    items.sort((a, b) =>
                        (a['status'] as int).compareTo(b['status'] as int));

                    return Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('No events'))
                          : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 16),
                        itemBuilder: (ctx3, idx) {
                          final e = items[idx];
                          final cm = e['community'] as CommunityMain;
                          final joined = e['joined'] as bool;
                          final count = e['joinCount'] as int;
                          final expired = e['status'] == 2;
                          final full = e['status'] == 1;

                          String label;
                          VoidCallback? action;

                          if (expired) {
                            // event already ended – show “Expired” no matter what
                            label  = 'Expired';
                            action = null;                // disabled
                          } else if (full) {
                            label  = 'Full';
                            action = null;
                          } else if (joined) {
                            label  = 'View Details';
                            action = () => _showEventDetail(context, cm, joined, count);
                          } else {
                            label  = 'Join';
                            action = () => _showEventDetail(context, cm, joined, count);
                          }

                          return _ChallengeCard(
                            title: cm.title,
                            description: cm.shortDescription,
                            startDate:
                            'Starts: ${DateFormat.MMMd().format(cm.startDate)}',
                            imageWidget: _buildImage(cm),
                            primaryButtonLabel: label,
                            primaryOnPressed: action,
                            leaderboardButtonLabel:
                            cm.existLeaderboard == 'Yes'
                                ? 'Leaderboard'
                                : null,
                            leaderboardOnPressed:
                            cm.existLeaderboard == 'Yes'
                                ? () => _showLeaderboard(context, cm)
                                : null,
                            joinCount: count,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: 'Habits'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Community'),
          BottomNavigationBarItem(
              icon: Icon(Icons.lightbulb_outline), label: 'Tips'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onTap: (_) {},
      ),
    );
  }
}

/// Challenge card component (unchanged).
class _ChallengeCard extends StatelessWidget {
  final String title, description, startDate;
  final Widget imageWidget;
  final String primaryButtonLabel;
  final VoidCallback? primaryOnPressed;
  final String? leaderboardButtonLabel;
  final VoidCallback? leaderboardOnPressed;
  final int joinCount;

  const _ChallengeCard({
    Key? key,
    required this.title,
    required this.description,
    required this.startDate,
    required this.imageWidget,
    required this.primaryButtonLabel,
    this.primaryOnPressed,
    this.leaderboardButtonLabel,
    this.leaderboardOnPressed,
    required this.joinCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(description,
                      style:
                      TextStyle(fontSize: 14, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(startDate,
                      style:
                      TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('$joinCount joined',
                      style:
                      TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOnPressed != null
                              ? Colors.white
                              : Colors.grey.shade300,
                          side: BorderSide(
                              color: primaryOnPressed != null
                                  ? Colors.green
                                  : Colors.grey),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onPressed: primaryOnPressed,
                        child: Text(primaryButtonLabel,
                            style: TextStyle(
                                color: primaryOnPressed != null
                                    ? Colors.green
                                    : Colors.grey)),
                      ),
                      if (leaderboardButtonLabel != null)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onPressed: leaderboardOnPressed,
                          child: Text(leaderboardButtonLabel!,
                              style: const TextStyle(color: Colors.green)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 1, child: AspectRatio(aspectRatio: 1, child: imageWidget)),
          ],
        ),
      ),
    );
  }
}

/// Event detail & join/exit screen (unchanged except swapping to RepositoryService).
/// … keep your existing UI here, but inside your join/exit confirm dialogs use:
///   await repo.joinEvent(email, community.id!);
///   await repo.exitEvent(email, community.id!);



/// Event detail & join/exit screen (revised to use RepositoryService)
class EventDetailScreen extends StatelessWidget {
  final CommunityMain community;
  final String email;
  final bool joined;
  final int joinCount;
  final VoidCallback onJoinConfirmed;
  final VoidCallback onExitConfirmed;

  const EventDetailScreen({
    Key? key,
    required this.community,
    required this.email,
    required this.joined,
    required this.joinCount,
    required this.onJoinConfirmed,
    required this.onExitConfirmed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryService.instance;
    final now = DateTime.now();
    final expired = community.endDate.isBefore(now);
    final full = joinCount >= community.capacity;
    final dateFmt = DateFormat('EEE, MMM d, yyyy – h:mm a');

    String btnLabel;
    VoidCallback? btnAction;
    Color btnColor;
    IconData btnIcon;

    if (joined) {
      btnLabel = 'Exit Event';
      btnAction = () => _confirmExit(context, repo);
      btnColor = Colors.red;
      btnIcon = Icons.exit_to_app;
    } else if (expired) {
      btnLabel = 'Event Ended';
      btnAction = null;
      btnColor = Colors.grey;
      btnIcon = Icons.event_busy;
    } else if (full) {
      btnLabel = 'Full';
      btnAction = null;
      btnColor = Colors.grey;
      btnIcon = Icons.block;
    } else {
      btnLabel = 'Join Event';
      btnAction = () => _confirmJoin(context, repo);
      btnColor = Colors.teal;
      btnIcon = Icons.event_available;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                community.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    shadows: [Shadow(blurRadius: 2, color: Colors.black26)]),
              ),
              background: community.imagePath != null &&
                  File(community.imagePath!).existsSync()
                  ? Image.file(File(community.imagePath!), fit: BoxFit.cover)
                  : Image.asset('assets/images/default.jpg',
                  fit: BoxFit.cover),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overview',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(community.shortDescription,
                            style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _InfoRow(
                          icon: Icons.event,
                          label: 'Type',
                          value: community.typeOfEvent),
                      const Divider(),
                      _InfoRow(
                          icon: Icons.location_on,
                          label: 'Location',
                          value: community.location),
                      const Divider(),
                      _InfoRow(
                          icon: Icons.people,
                          label: 'Participants',
                          value: '$joinCount'),
                      const Divider(),
                      _InfoRow(
                          icon: Icons.schedule,
                          label: 'Starts',
                          value: dateFmt.format(community.startDate)),
                      const Divider(),
                      _InfoRow(
                          icon: Icons.schedule,
                          label: 'Ends',
                          value: dateFmt.format(community.endDate)),
                      const Divider(),
                      _InfoRow(
                          icon: Icons.people_outline,
                          label: 'Capacity',
                          value: '${community.capacity}'),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Details',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(community.description,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                const Text('Terms & Conditions',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(community.termsAndConditions,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(btnIcon),
                    label: Text(btnLabel),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    onPressed: btnAction,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmJoin(BuildContext context, RepositoryService repo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Join'),
          content: const Text('Do you want to join this event?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // close dialog
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();                // close dialog
                await repo.joinEvent(email, community.id!);       // update local+remote
                Navigator.of(context).pop();                     // pop detail screen
                onJoinConfirmed();                               // refresh list
              },
              child: const Text('Join'),
            ),
          ],        );
      },
    );
  }

  void _confirmExit(BuildContext context, RepositoryService repo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Exit'),
          content: const Text('Are you sure you want to exit this event?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // close dialog
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();                    // close dialog
                await repo.exitEvent(email, community.id!);           // update local+remote
                Navigator.of(context).pop();                         // pop detail screen
                onExitConfirmed();                                   // refresh list
              },
              child: const Text('Exit', style: TextStyle(color: Colors.red)),
            ),
          ],        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: style,
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        )
      ],
    );
  }
}
