// lib/admin_main_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'community_repository_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';

import 'admin_community_add_page.dart';
import 'admin_community_edit_page.dart';
import 'admin_community_score.dart';
import 'admin_community_check_user_page.dart';

/* ────────────────────────────────────────────────────────────────
   ADMIN  ▸  DASHBOARD
 ──────────────────────────────────────────────────────────────── */
class AdminMainPage extends StatefulWidget {
  const AdminMainPage({Key? key}) : super(key: key);

  @override
  _AdminMainPageState createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  final _repo = RepositoryService.instance;
  late Future<void> _initialSync;

  // Dashboard stats
  int _totalEvents = 0;
  int _upcomingEvents = 0;
  int _totalParticipants = 0;

  @override
  void initState() {
    super.initState();
    _initialSync = _loadData();
  }

  Future<void> _loadData() async {
    await _repo.syncAllAdmin();

    // Load additional stats
    final events = await _repo.getCommunities();
    final now = DateTime.now();

    setState(() {
      _totalEvents = events.length;
      _upcomingEvents = events.where((e) => e.startDate.isAfter(now)).length;

      // This would be better implemented with a dedicated API call
      // This is a simplified version for demonstration
      _totalParticipants = events.length * 5; // Placeholder value
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialSync,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 16),
                  Text("Loading admin dashboard...",
                      style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
          );
        }
        return _buildScaffold();
      },
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,              // manual refresh
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,                // pull-to-refresh
        color: Colors.green[700],
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // needed for RefreshIndicator
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStats(),
              _buildActionCards(),
            ],
          ),
        ),
      ),
    );

  }


  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Events',
                  _totalEvents.toString(),
                  Colors.green[400]!,
                  Icons.event,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Upcoming Events',
                  _upcomingEvents.toString(),
                  Colors.green[600]!,
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Participants',
                  _totalParticipants.toString(),
                  Colors.green[800]!,
                  Icons.people,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'Create a New Event',
            'Create and publish a new community event',
            Icons.add_circle_outline,
                () => Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const AddEventPage()),
            ).then((created) {
              // after pop, re-sync if they actually created something (or just always)
              if (created == true) {
                setState(() {
                  _initialSync = _loadData();
                });
              }
            }),
          ),

          _buildActionCard(
            'Create a New Event',
            'Create and publish a new community event',
            Icons.add_circle_outline,
                () => Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const AddEventPage()),
            ).then((created) {
              // after pop, re-sync if they actually created something (or just always)
              if (created == true) {
                setState(() {
                  _initialSync = _loadData();
                });
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      String title, String description, IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.green[700], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.green[700],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────────
   ADMIN  ▸  EVENT LIST (current & past)
 ──────────────────────────────────────────────────────────────── */
class EditEventListPage extends StatefulWidget {
  const EditEventListPage({Key? key}) : super(key: key);

  @override
  State<EditEventListPage> createState() => _EditEventListPageState();
}

class _EditEventListPageState extends State<EditEventListPage> {
  final _repo = RepositoryService.instance;
  late Future<List<CommunityMain>> _eventsFuture;

  String _searchTerm = '';
  String _selectedType = 'All';

  final _allTypes = [
    'All',
    'Workshop',
    'Seminar',
    'Meetup',
    'Competition',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final future = _repo.getCommunities();
    setState(() {
      _eventsFuture = future;
    });
  }

  Future<void> _pullRefresh() async {
    await _repo.syncAllAdmin();
    _reload();
    await _eventsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manage Events'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: RefreshIndicator(
        color: Colors.green,
        onRefresh: _pullRefresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildFilterChips(),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<CommunityMain>>(
                  future: _eventsFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Error: ${snap.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    }

                    var events = snap.data ?? [];
                    events = events.where((e) {
                      final term = _searchTerm.toLowerCase();
                      final byText = e.title.toLowerCase().contains(term) ||
                          e.shortDescription.toLowerCase().contains(term);
                      final byType = _selectedType == 'All' ||
                          e.typeOfEvent == _selectedType;
                      return byText && byType;
                    }).toList();

                    final current = events.where((e) => !e.endDate.isBefore(now)).toList();
                    final past = events.where((e) => e.endDate.isBefore(now)).toList();

                    if (current.isEmpty && past.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search or filter',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      children: [
                        if (current.isNotEmpty) ...[
                          _buildSectionHeader('Current Events', Icons.event_available),
                          const SizedBox(height: 8),
                          ...current.map((e) => _buildEventCard(e)),
                        ],
                        if (past.isNotEmpty) ...[
                          _buildSectionHeader('Past Events', Icons.event_busy),
                          const SizedBox(height: 8),
                          ...past.map((e) => _buildEventCard(e)),
                        ],
                        // Add extra padding at the bottom
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEventPage()),
        ).then((_) => _reload()),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          prefixIcon: Icon(Icons.search, color: Colors.green[700]),
          hintText: 'Search events…',
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onChanged: (t) => setState(() => _searchTerm = t),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _allTypes.map((type) {
          final selected = _selectedType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                type,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: selected,
              backgroundColor: Colors.white,
              selectedColor: Colors.green[600],
              checkmarkColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              onSelected: (_) => setState(() => _selectedType = type),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[700], size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CommunityMain event) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final startDate = dateFormat.format(event.startDate);
    final endDate = dateFormat.format(event.endDate);
    final dateText = startDate == endDate
        ? 'On $startDate'
        : '$startDate - $endDate';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<List<JoinEventModel>>(
        future: _repo.getJoinsForCommunity(event.id!),
        builder: (_, snap) {
          final joined = (snap.data ?? const <JoinEventModel>[])
              .where((j) => j.status == 'joined')
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event type badge
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.only(right: 12, top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    event.typeOfEvent,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ),

              // Main content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          dateText,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people,
                            size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          '$joined participants',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    if (event.shortDescription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        event.shortDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Manual leaderboard button
                    if (event.existLeaderboard == 'Yes' &&
                        event.typeOfLeaderboard == 'Manually Input Score')
                      _buildActionButton(
                        Icons.assessment_outlined,
                        'Scores',
                        Colors.blue[700]!,
                            () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScoreInputScreen(community: event),
                          ),
                        ),
                      ),

                    // Participants button
                    _buildActionButton(
                      Icons.group,
                      'Participants',
                      Colors.amber[700]!,
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParticipantsScreen(community: event),
                        ),
                      ),
                    ),

                    // Edit button
                    _buildActionButton(
                      Icons.edit,
                      'Edit',
                      Colors.green[700]!,
                          () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditEventPage(event: event),
                          ),
                        );
                        if (updated == true) setState(_reload);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton.icon(
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: TextStyle(color: color),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: onPressed,
      ),
    );
  }
}