// lib/admin_main_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'community_repository_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';

import 'admin_community_add_page.dart';
import 'admin_community_edit_page.dart';
import 'admin_community_score.dart';
import 'admin_community_check_user_page.dart';
// <-- make sure this file exists
import '../../../YenHan/pages/login_page.dart';

/* ────────────────────────────────────────────────────────────────
   ADMIN  ▸  DASHBOARD
 ──────────────────────────────────────────────────────────────── */
class AdminMainPage extends StatelessWidget {
  const AdminMainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New Event'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEventPage()),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Manage Events'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditEventListPage()),
              ),
            ),
          ],
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
  final _repo            = RepositoryService.instance;
  late  Future<List<CommunityMain>> _eventsFuture;

  String _searchTerm  = '';
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
    _load();
  }

  void _load() => _eventsFuture = _repo.getCommunities();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Events'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            // —— search
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search events…',
                border: OutlineInputBorder(),
              ),
              onChanged: (t) => setState(() => _searchTerm = t),
            ),
            const SizedBox(height: 8),
            // —— type filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _allTypes.map((type) {
                  final sel = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: sel,
                      selectedColor: Colors.green.shade300,
                      onSelected: (_) => setState(() => _selectedType = type),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // —— list of events
            Expanded(
              child: FutureBuilder<List<CommunityMain>>(
                future: _eventsFuture,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  // text + chip filter
                  var events = snap.data ?? [];
                  events = events.where((e) {
                    final term = _searchTerm.toLowerCase();
                    final byText = e.title.toLowerCase().contains(term) ||
                        e.shortDescription.toLowerCase().contains(term);
                    final byType = _selectedType == 'All' ||
                        e.typeOfEvent == _selectedType;
                    return byText && byType;
                  }).toList();

                  final current = events.where((e) => !e.endDate.isBefore(now));
                  final past    = events.where((e) =>  e.endDate.isBefore(now));

                  if (current.isEmpty && past.isEmpty) {
                    return const Center(child: Text('No events found'));
                  }

                  return ListView(
                    children: [
                      if (current.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Current Events',
                              style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                        ),
                        for (var e in current) _buildTile(e),
                      ],
                      if (past.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Past Events',
                              style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                        ),
                        for (var e in past) _buildTile(e),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// one line = one event
  Widget _buildTile(CommunityMain ev) {
    final dateText = 'Starts ${DateFormat('MMM d, yyyy').format(ev.startDate)}';

    return FutureBuilder<List<JoinEventModel>>(
      future: _repo.getJoinsForCommunity(ev.id!),
      builder: (_, snap) {
        final joined = (snap.data ?? const <JoinEventModel>[])
            .where((j) => j.status == 'joined')
            .length;

        return ListTile(
          leading: const Icon(Icons.event),
          title: Text(ev.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateText),
              const SizedBox(height: 2),
              Text('$joined joined'),
            ],
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              // manual leaderboard button
              if (ev.existLeaderboard == 'Yes' &&
                  ev.typeOfLeaderboard == 'Manually Input Score')
                IconButton(
                  icon: const Icon(Icons.assessment_outlined),
                  tooltip: 'Input Scores',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ScoreInputScreen(community: ev)),
                  ),
                ),
              // participants button
              IconButton(
                icon: const Icon(Icons.group),
                tooltip: 'View Participants',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ParticipantsScreen(community: ev)),
                ),
              ),
              // edit button
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Event',
                onPressed: () async {
                  final updated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => EditEventPage(event: ev)),
                  );
                  if (updated == true) setState(_load);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
