// admin_community_score.dart
import 'package:flutter/material.dart';
import 'community_repository_service.dart';
import 'community_main_model.dart';
import 'join_event_model.dart';
import 'ranking_model.dart';

/// Admin page that lets you enter / edit scores with enhanced green theme.
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

  // Design constants - Green theme
  final Color _primaryGreen = Colors.green;
  final Color _darkGreen = Colors.green.shade700;
  final Color _lightGreen = Colors.green.shade100;
  final Color _accentGreen = Colors.lightGreen;

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

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    );

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

    // Close loading dialog and navigate back
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Navigate back

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Scores saved successfully'),
          backgroundColor: _darkGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scores • ${widget.community.title}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _darkGreen,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Score Management Help'),
                  content: const Text(
                    'Tap on a user to edit their score.\n\n'
                        'Enter a positive number to set a score.\n'
                        'Enter 0 or leave blank to remove score.',
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Got it'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_darkGreen.withOpacity(0.1), Colors.white],
          ),
        ),
        child: FutureBuilder<void>(
          future: _init,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryGreen),
                ),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading data',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text('${snap.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _init = _load();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
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
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: _primaryGreen),
                      hintText: 'Search by name, email or phone...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _lightGreen),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _lightGreen),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryGreen, width: 2),
                      ),
                      fillColor: _lightGreen.withOpacity(0.2),
                      filled: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                Expanded(
                  child: joins.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No participants found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (_search.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _search = ''),
                            child: const Text('Clear search'),
                          ),
                      ],
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: joins.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final j = joins[i];
                      final u = _userByEmail[j.email]!;
                      final editing = _editing == j.email;
                      final score = _ctrl[j.email]!.text.isEmpty
                          ? 0
                          : int.tryParse(_ctrl[j.email]!.text) ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: editing ? 3 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: editing
                              ? BorderSide(color: _primaryGreen, width: 2)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              setState(() => _editing = editing ? null : j.email),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: score > 0
                                      ? _accentGreen
                                      : Colors.grey.shade300,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: score > 0
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u['username'] as String,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.email_outlined,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              j.email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if ((u['phone'] as String).isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.phone_outlined,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                u['phone'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                editing
                                    ? SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: _ctrl[j.email],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Score',
                                      labelStyle: TextStyle(color: _primaryGreen),
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: _primaryGreen,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    autofocus: true,
                                  ),
                                )
                                    : Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: score > 0
                                        ? _lightGreen
                                        : Colors.grey.shade200,
                                  ),
                                  child: Center(
                                    child: Text(
                                      score.toString(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: score > 0
                                            ? _darkGreen
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, -2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
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