import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';          // RouteAware support
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'community_repository_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';
import 'community_leaderboard.dart';
import 'community_joined_history.dart';   // ⬅️ new line

import '../screen/home.dart';
import '../screen/track_habit_screen.dart';
import '../screen/profile.dart';
import '../YenHan/pages/tips_education.dart';
/// Route observer (put once in this file; referenced from main.dart)
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

/// Community Challenges List Page with search, filter, ordering,
/// and RepositoryService sync.
class CommunityChallengesScreen extends StatefulWidget {
  const CommunityChallengesScreen({Key? key}) : super(key: key);

  @override
  State<CommunityChallengesScreen> createState() =>
      _CommunityChallengesScreenState();
}

class _CommunityChallengesScreenState extends State<CommunityChallengesScreen>
    with RouteAware {
  final _repo = RepositoryService.instance;

  late Future<List<CommunityMain>> _futureCommunities;
  late final String currentEmail;

  // ─── UI State ────────────────────────────────────────────────────────────
  String _searchTerm = '';
  String _selectedType = 'All';
  final List<String> _allEventTypes = [
    'All', 'Workshop', 'Seminar', 'Meetup', 'Competition', 'Other'
  ];

  // ─── PAGE LIFECYCLE ──────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    assert(user != null && user.email != null,
    'CommunityChallengesScreen must be opened after login.');
    currentEmail = user!.email!;
    _reloadAll();                               // initial load
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called automatically when user navigates back to this screen.
  @override
  void didPopNext() => _reloadAll();

  // ─── DATA HELPERS ────────────────────────────────────────────────────────
  Future<List<CommunityMain>> _syncAndFetch() async {
    await _repo.syncAllForUser(currentEmail);    // Cloud → SQLite
    return _repo.getCommunities();               // freshest list
  }

  void _reloadAll() {
    setState(() {
      _futureCommunities = _syncAndFetch();   // ← assignment only, no return
    });
  }

  Future<List<Object>> _joinInfo(int communityId) {
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

  // ─── NAVIGATION HELPERS ──────────────────────────────────────────────────
  void _showEventDetail(BuildContext ctx, CommunityMain cm,
      bool joined, int joinCount) {
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
                .showSnackBar(SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Successfully joined event!'),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ));
            _reloadAll();
          },
          onExitConfirmed: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 12),
                  Text('You left the event'),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ));
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

  // ─── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => FutureBuilder<List<CommunityMain>>(
    future: _futureCommunities,
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
        );
      }
      if (snap.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: ${snap.error}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: _reloadAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return _buildScaffold(ctx, snap.data ?? []);
    },
  );

  Widget _buildScaffold(BuildContext context, List<CommunityMain> commsRaw) {
    final now = DateTime.now();

    // ── search / filter in memory ──
    var comms = commsRaw.where((c) {
      final term = _searchTerm.toLowerCase();
      final matchTitle = c.title.toLowerCase().contains(term);
      final matchDesc  = c.shortDescription.toLowerCase().contains(term);
      final matchType  =
          _selectedType == 'All' || c.typeOfEvent == _selectedType;
      return (matchTitle || matchDesc) && matchType;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Challenges',
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
            )),
        backgroundColor: Colors.green.shade600,
        elevation: 2,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(15),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rtl_outlined, color: Colors.white),
            tooltip: 'My Events',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyJoinedEventsScreen(email: currentEmail),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reloadAll(),
        color: Colors.green.shade700,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey.shade50, Colors.grey.shade100],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.green.shade600),
                      hintText: 'Search events…',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.green.shade300, width: 2),
                      ),
                    ),
                    onChanged: (t) => setState(() => _searchTerm = t),
                  ),
                ),
                const SizedBox(height: 12),

                // Type filter chips
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _allEventTypes.map((type) {
                        final selected = type == _selectedType;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: selected,
                            selectedColor: Colors.green.shade100,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected ? Colors.green.shade700 : Colors.grey.shade700,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                            elevation: 1,
                            pressElevation: 2,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: BorderSide(
                                color: selected ? Colors.green.shade400 : Colors.grey.shade200,
                              ),
                            ),
                            onSelected: (_) => setState(() => _selectedType = type),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Info bar with counts
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Found ${comms.length} events',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_searchTerm.isNotEmpty || _selectedType != 'All')
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _searchTerm = '';
                              _selectedType = 'All';
                            });
                          },
                          child: Row(
                            children: [
                              Icon(Icons.filter_list_off, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Clear filters',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Build list with join info
                Expanded(
                  child: FutureBuilder<List<List<Object>>>(
                    future: Future.wait(comms.map((c) => _joinInfo(c.id!))),
                    builder: (ctx2, infoSnap) {
                      if (infoSnap.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                              ),
                              const SizedBox(height: 16),
                              Text('Loading event details...',
                                style: TextStyle(color: Colors.green.shade600),
                              ),
                            ],
                          ),
                        );
                      }
                      if (infoSnap.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              Text('Error: ${infoSnap.error}'),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                onPressed: _reloadAll,
                              ),
                            ],
                          ),
                        );
                      }
                      final infos = infoSnap.data!;
                      // merge meta info for sort & display
                      final items = <Map<String, dynamic>>[];
                      for (var i = 0; i < comms.length; i++) {
                        final c = comms[i];
                        final hasJoined = infos[i][0] as bool;
                        final count     = infos[i][1] as int;
                        final expired   = c.endDate.isBefore(now);
                        final full      = count >= c.capacity;
                        final status    = expired ? 2 : (full ? 1 : 0); // 0 avail
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

                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/empty_state.png',
                                width: 150,
                                height: 150,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No events found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters or check back later',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 16),
                        itemBuilder: (ctx3, idx) {
                          final e   = items[idx];
                          final cm  = e['community'] as CommunityMain;
                          final joined    = e['joined'] as bool;
                          final count     = e['joinCount'] as int;
                          final expired   = e['status'] == 2;
                          final full      = e['status'] == 1;

                          String label;
                          IconData buttonIcon;
                          VoidCallback? action;
                          if (joined) {
                            // Whoever is already in can ALWAYS see details / exit, no matter what.
                            label  = 'View Details';
                            buttonIcon = Icons.visibility;
                            action = () => _showEventDetail(context, cm, joined, count);
                          } else if (expired) {
                            label  = 'Expired';
                            buttonIcon = Icons.event_busy;
                            action = null;
                          } else if (full) {
                            label  = 'Full';
                            buttonIcon = Icons.people;
                            action = null;
                          } else {
                            label  = 'Join';
                            buttonIcon = Icons.add_circle_outline;
                            action = () => _showEventDetail(context, cm, joined, count);
                          }

                          return _ChallengeCard(
                            title: cm.title,
                            description: cm.shortDescription,
                            startDate: DateFormat.MMMd().format(cm.startDate),
                            endDate: DateFormat.MMMd().format(cm.endDate),
                            eventType: cm.typeOfEvent,
                            imageWidget: _buildImage(cm),
                            primaryButtonLabel: label,
                            primaryButtonIcon: buttonIcon,
                            primaryOnPressed: action,
                            leaderboardButtonLabel:
                            cm.existLeaderboard == 'Yes' ? 'Leaderboard' : null,
                            leaderboardOnPressed:
                            cm.existLeaderboard == 'Yes'
                                ? () => _showLeaderboard(context, cm)
                                : null,
                            joinCount: count,
                            capacity: cm.capacity,
                            joined: joined,
                            expired: expired,
                            full: full,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          child: BottomNavigationBar(
            currentIndex: 2,
            selectedItemColor: Colors.green.shade700,
            unselectedItemColor: Colors.grey.shade600,
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Habits'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  activeIcon: Icon(Icons.people_alt),
                  label: 'Community'
              ),
              BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outline), label: 'Tips'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
            onTap: (index) async {
              if (index == 0) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
                if (result == true) {
                  _syncAndFetch();
                }
              } else if (index == 1) { // 'Track Habit' is at index 1
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrackHabitScreen()),
                );
                if (result == true) {
                  _syncAndFetch();
                }
              } else if (index == 3){ // 'Tips & Learning' is at index 3
                final result = await Navigator.push( // Use result for tips too
                  context,
                  MaterialPageRoute(builder: (context) => TipsEducationScreen() ),
                );
                if (result == true) {
                  _syncAndFetch();
                }
              } else if (index == 4) { // 'Profile' is at index 4
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()), // Navigate to ProfilePage
                );
                if (result == true) {
                  _syncAndFetch();
                }
              }
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reloadAll,
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Refresh events',
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Widget _buildImage(CommunityMain c) {
    if (c.imagePath != null && File(c.imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(c.imagePath!), fit: BoxFit.cover),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/defaultEvent.jpg', fit: BoxFit.cover),
    );
  }
}

/// Challenge card component (enhanced).
class _ChallengeCard extends StatelessWidget {
  final String title, description, startDate, endDate, eventType;
  final Widget imageWidget;
  final String primaryButtonLabel;
  final IconData primaryButtonIcon;
  final VoidCallback? primaryOnPressed;
  final String? leaderboardButtonLabel;
  final VoidCallback? leaderboardOnPressed;
  final int joinCount;
  final int capacity;
  final bool joined;
  final bool expired;
  final bool full;

  const _ChallengeCard({
    Key? key,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.eventType,
    required this.imageWidget,
    required this.primaryButtonLabel,
    required this.primaryButtonIcon,
    this.primaryOnPressed,
    this.leaderboardButtonLabel,
    this.leaderboardOnPressed,
    required this.joinCount,
    required this.capacity,
    required this.joined,
    required this.expired,
    required this.full,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate percentage filled
    final double fillPercentage = capacity > 0 ? joinCount / capacity * 100 : 0;

    // Determine status chip color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (joined) {
      statusColor = Colors.green.shade700;
      statusText = 'Joined';
      statusIcon = Icons.check_circle;
    } else if (expired) {
      statusColor = Colors.grey.shade700;
      statusText = 'Expired';
      statusIcon = Icons.event_busy;
    } else if (full) {
      statusColor = Colors.orange.shade700;
      statusText = 'Full';
      statusIcon = Icons.people;
    } else {
      statusColor = Colors.blue.shade700;
      statusText = 'Open';
      statusIcon = Icons.event_available;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Image
          Stack(
            children: [
              // Event image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: imageWidget,
                ),
              ),
              // Top status badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Left event type badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    eventType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Event date range
                Row(
                  children: [
                    Icon(Icons.event, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      "$startDate - $endDate",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Capacity progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$joinCount participants',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${capacity - joinCount} spots left',
                          style: TextStyle(
                            fontSize: 13,
                            color: full || expired ? Colors.red.shade700 : Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: capacity > 0 ? joinCount / capacity : 0,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            fillPercentage >= 80
                                ? Colors.orange.shade700
                                : Colors.green.shade600
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(primaryButtonIcon, size: 18),
                        label: Text(primaryButtonLabel),
                        onPressed: primaryOnPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOnPressed != null
                              ? (joined ? Colors.green.shade100 : Colors.green.shade600)
                              : Colors.grey.shade300,
                          foregroundColor: primaryOnPressed != null
                              ? (joined ? Colors.green.shade800 : Colors.white)
                              : Colors.grey.shade700,
                          elevation: primaryOnPressed != null ? 0 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: primaryOnPressed != null && joined
                                ? BorderSide(color: Colors.green.shade600)
                                : BorderSide.none,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (leaderboardButtonLabel != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.leaderboard, size: 18),
                        label: Text(leaderboardButtonLabel!),
                        onPressed: leaderboardOnPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green.shade700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.green.shade600),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Event detail & join/exit screen (enhanced with visual improvements)
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
    final remainingSpots = community.capacity - joinCount;

    // Button configuration
    String btnLabel;
    VoidCallback? btnAction;
    Color btnColor;
    IconData btnIcon;

    if (joined) {
      btnLabel = 'Exit Event';
      btnAction = () => _confirmExit(context, repo);
      btnColor = Colors.red.shade600;
      btnIcon = Icons.exit_to_app;
    } else if (expired) {
      btnLabel = 'Event Ended';
      btnAction = null;
      btnColor = Colors.grey.shade600;
      btnIcon = Icons.event_busy;
    } else if (full) {
      btnLabel = 'Event Full';
      btnAction = null;
      btnColor = Colors.orange.shade700;
      btnIcon = Icons.block;
    } else {
      btnLabel = 'Join Event';
      btnAction = () => _confirmJoin(context, repo);
      btnColor = Colors.green.shade600;
      btnIcon = Icons.event_available;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.green.shade600,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                community.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  community.imagePath != null &&
                      File(community.imagePath!).existsSync()
                      ? Image.file(File(community.imagePath!), fit: BoxFit.cover)
                      : Image.asset('assets/defaultEvent.jpg', fit: BoxFit.cover),

                  // Gradient overlay for better text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),

                  // Event type badge
                  Positioned(
                    top: 60,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        community.typeOfEvent,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Event status card
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: joined
                          ? [Colors.green.shade50, Colors.green.shade100]
                          : expired
                          ? [Colors.grey.shade50, Colors.grey.shade200]
                          : full
                          ? [Colors.orange.shade50, Colors.orange.shade100]
                          : [Colors.blue.shade50, Colors.blue.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: joined
                          ? Colors.green.shade300
                          : expired
                          ? Colors.grey.shade300
                          : full
                          ? Colors.orange.shade300
                          : Colors.blue.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: joined
                            ? Colors.green.shade100
                            : expired
                            ? Colors.grey.shade300
                            : full
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                        child: Icon(
                          joined
                              ? Icons.check_circle
                              : expired
                              ? Icons.event_busy
                              : full
                              ? Icons.person_off
                              : Icons.event_available,
                          color: joined
                              ? Colors.green.shade700
                              : expired
                              ? Colors.grey.shade700
                              : full
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              joined
                                  ? 'You\'ve joined this event'
                                  : expired
                                  ? 'This event has ended'
                                  : full
                                  ? 'This event is full'
                                  : 'Event is open for registration',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: joined
                                    ? Colors.green.shade700
                                    : expired
                                    ? Colors.grey.shade700
                                    : full
                                    ? Colors.orange.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              joined
                                  ? 'You can view details or exit the event'
                                  : expired
                                  ? 'You can no longer join this event'
                                  : full
                                  ? 'No spots remaining'
                                  : 'Join this event to participate',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Overview card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            const Text('Overview',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(community.shortDescription,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            )),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Event details card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            const Text('Event Information',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                            icon: Icons.category,
                            label: 'Type',
                            value: community.typeOfEvent),
                        const Divider(height: 16),
                        _InfoRow(
                            icon: Icons.location_on,
                            label: 'Location',
                            value: community.location),
                        const Divider(height: 16),
                        _InfoRow(
                            icon: Icons.people,
                            label: 'Participants',
                            value: '$joinCount of ${community.capacity}'),
                        const Divider(height: 16),
                        _InfoRow(
                            icon: Icons.event,
                            label: 'Starts',
                            value: dateFmt.format(community.startDate)),
                        const Divider(height: 16),
                        _InfoRow(
                            icon: Icons.event_busy,
                            label: 'Ends',
                            value: dateFmt.format(community.endDate)),

                        // Capacity progress bar
                        const SizedBox(height: 16),
                        Text(
                          'Capacity: $joinCount/${community.capacity} ${expired ? '' : '(${remainingSpots} spots left)'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: community.capacity > 0 ? joinCount / community.capacity : 0,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                joinCount >= community.capacity * 0.8
                                    ? Colors.orange.shade700
                                    : Colors.green.shade600
                            ),
                            minHeight: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Details section
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.article, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            const Text('Details',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          community.description,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Terms & Conditions section
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gavel, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            const Text('Terms & Conditions',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          community.termsAndConditions,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    icon: Icon(btnIcon),
                    label: Text(
                      btnLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        foregroundColor: Colors.white,
                        elevation: btnAction != null ? 3 : 0,
                        shadowColor: btnAction != null ? btnColor.withOpacity(0.5) : Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: btnAction,
                  ),
                ),

                const SizedBox(height: 24),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.event_available, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('Confirm Join'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Do you want to join "${community.title}"?'),
              const SizedBox(height: 12),
              Text(
                'By joining this event, you agree to follow the event guidelines and terms.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // close dialog
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();                // close dialog
                await repo.joinEvent(email, community.id!);       // update local+remote
                Navigator.of(context).pop();                     // pop detail screen
                onJoinConfirmed();                               // refresh list
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Join Event'),
            ),
          ],
        );
      },
    );
  }

  void _confirmExit(BuildContext context, RepositoryService repo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Confirm Exit'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to exit "${community.title}"?'),
              const SizedBox(height: 12),
              Text(
                'You can rejoin later if spaces are still available.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // close dialog
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();                    // close dialog
                await repo.exitEvent(email, community.id!);           // update local+remote
                Navigator.of(context).pop();                         // pop detail screen
                onExitConfirmed();                                   // refresh list
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Exit Event'),
            ),
          ],
        );
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.green.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}