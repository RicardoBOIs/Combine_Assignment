import 'package:flutter/material.dart';
import '../../Willie/admin_community_main.dart';
import '../../YenHan/pages/admin_dashboard.dart';
import 'package:assignment_test/YenHan/pages/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:assignment_test/YenHan/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment_test/YenHan/pages/Daily_FootPrint_Overview.dart';

final FirebaseAuth firebaseAuth = FirebaseAuth.instance;



class AdminMain extends StatelessWidget {
  const AdminMain({Key? key}) : super(key: key);

  Future<void> _showAdminsPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AdminsManager()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green,
        actions: [

          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              firebaseAuth.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            tooltip: 'Logout',
          )
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Management Event'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminMainPage()),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Manage Tip & Education'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              ),
            ),
            const SizedBox(height: 16),
      ElevatedButton.icon(
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text('Manage Admin E-mails'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.green,
        ),
        onPressed: () => _showAdminsPage(context),
      ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.assessment),
              label: const Text('User footprints overview'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FootprintAdminPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

 // A lightweight page that lists current admins
 // and remove any entry directly from Firestore.

class _AdminsManager extends StatefulWidget {
  const _AdminsManager({Key? key}) : super(key: key);

  @override
  State<_AdminsManager> createState() => _AdminsManagerState();
}

class _AdminsManagerState extends State<_AdminsManager> {
  final _svc = FirestoreService();

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance
          .collection('Admin')
          .doc('Email')
          .collection('List');

  // ── add dialog ────────────────────────────────────────────────
  Future<void> _addEmail() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Admin E-mail'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'E-mail'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    final email = ctrl.text.trim();
    if (email.isEmpty) return;

    // duplicate check
    final exists = await _ref.doc(email).get();
    if (exists.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail already an admin')),
      );
      return;
    }

    // verify against Registered_users first
    final userDoc = await FirebaseFirestore.instance
        .collection('Registered_users')
        .doc(email)
        .get();
    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No such user in Registered_users')),
      );
      return;
    }

    await _svc.addAdmin(email);
  }

  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin E-mails'),
        backgroundColor: Colors.green,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEmail,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No admin e-mails yet'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final email = docs[i].id;
              return ListTile(
                title: Text(email),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirm Delete'),
                          content: const Text('Are you sure you want to delete this admin?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true) {
                      await _svc.removeAdmin(email);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
