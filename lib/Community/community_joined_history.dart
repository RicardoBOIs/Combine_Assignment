// my_joined_events_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'community_main_model.dart';
import 'community_repository_service.dart';

class MyJoinedEventsScreen extends StatelessWidget {
  final String email;
  const MyJoinedEventsScreen({Key? key, required this.email}) : super(key: key);

  Future<List<CommunityMain>> _load() async {
    final repo   = RepositoryService.instance;
    final joins  = await repo.getJoinsForUser(email);
    final ids    = joins.where((j) => j.status == 'joined')
        .map((j) => j.communityID)
        .toSet();
    if (ids.isEmpty) return [];
    final all    = await repo.getCommunities();
    return all.where((c) => ids.contains(c.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder<List<CommunityMain>>(
        future: _load(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return const Center(child: Text('You haven’t joined any events.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final e = events[i];
              final img = (e.imagePath != null && File(e.imagePath!).existsSync())
                  ? Image.file(File(e.imagePath!), fit: BoxFit.cover)
                  : Image.asset('assets/images/default.jpg', fit: BoxFit.cover);
              return Card(
                child: ListTile(
                  leading: SizedBox(width: 60, height: 60, child: img),
                  title: Text(e.title),
                  subtitle: Text(
                      'Ends: ${fmt.format(e.endDate)}\n'
                          '${e.shortDescription}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
