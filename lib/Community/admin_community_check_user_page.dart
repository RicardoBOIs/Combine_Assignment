// admin_community_check_user_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'community_repository_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';

/// Lightweight DTO we show in the list
class Participant {
  final String email;
  final String username;
  final String phone;
  final String location;
  final DateTime joinedAt;

  Participant({
    required this.email,
    required this.username,
    required this.phone,
    required this.location,
    required this.joinedAt,
  });
}

/// Shows every user whose **JoinEvent.status == 'joined'** for a community.
/// *Users* are fetched with **getAllUsers()** (Firebase-first, SQLite fallback).
class ParticipantsScreen extends StatefulWidget {
  final CommunityMain community;
  const ParticipantsScreen({Key? key, required this.community}) : super(key: key);

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final _repo = RepositoryService.instance;

  late Future<List<Participant>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Participant>> _load() async {
    final id = widget.community.id!;
    //-------------------------------------------------------------
    // 1️⃣ Joined rows
    //-------------------------------------------------------------
    final joins =
    (await _repo.getJoinsForCommunity(id)).where((j) => j.status == 'joined');

    if (joins.isEmpty) return [];

    //-------------------------------------------------------------
    // 2️⃣ All user profiles – Firebase first, then SQLite
    //-------------------------------------------------------------
    final users = await _repo.getAllUsers();               // <— key line
    final byEmail = {for (var u in users) u['email'] as String: u};

    //-------------------------------------------------------------
    // 3️⃣ Build participant objects (fallback if a user is missing)
    //-------------------------------------------------------------
    final list = <Participant>[];
    for (final j in joins) {
      Map<String, dynamic>? u = byEmail[j.email];

      // if still missing, try per-user fetch once (rare)
      u ??= await _repo.getUser(j.email);

      list.add(
        Participant(
          email: j.email,
          username: u?['username'] as String? ?? j.email,
          phone: u?['phone'] as String? ?? '—',
          location: u?['location'] as String? ?? '—',
          joinedAt: j.joinedAt is DateTime
              ? j.joinedAt as DateTime
              : DateTime.parse(j.joinedAt.toString()),
        ),
      );
    }
    return list;
  }

  Future<void> _refresh() async => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.community.title} Participants'),
        backgroundColor: Colors.green,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Participant>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final data = snap.data ?? [];

            //---------------------------------------------------------
            // filter by search
            //---------------------------------------------------------
            final term = _search.toLowerCase();
            final filtered = data.where((p) {
              return p.username.toLowerCase().contains(term) ||
                  p.email.toLowerCase().contains(term) ||
                  p.phone.toLowerCase().contains(term);
            }).toList();

            if (filtered.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No participants match.')),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: filtered.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search participants…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  );
                }
                final p = filtered[i - 1];
                final joinedStr =
                DateFormat('MMM d, yyyy – h:mm a').format(p.joinedAt);
                return ListTile(
                  leading: CircleAvatar(child: Text('$i')),
                  title: Text(p.username),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.email),
                      Text(p.phone),
                      Text(p.location),
                      const SizedBox(height: 4),
                      Text('Joined: $joinedStr',
                          style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  isThreeLine: true,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
