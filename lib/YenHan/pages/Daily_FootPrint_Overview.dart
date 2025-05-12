import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FootprintAdminPage extends StatelessWidget {
  const FootprintAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance
        .collection('daily_Carbon_FootPrint_record');   // top level

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users • Daily Footprints'),
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: col.get(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final userDocs = snap.data!.docs;                  // one per user
          if (userDocs.isEmpty) {
            return const Center(child: Text('No data yet'));
          }

          return ListView.builder(
            itemCount: userDocs.length,
            itemBuilder: (_, i) {
              final email = userDocs[i].id;                  // doc-id == e-mail
              return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: col.doc(email).collection('days').get(),
                builder: (c, s) {
                  if (!s.hasData) {
                    return const ListTile(title: Text('…'));
                  }
                  final days = s.data!.docs;
                  days.sort((a, b) => b.id.compareTo(a.id)); // newest first
                  final latest = days.isEmpty
                      ? '—'
                      : '${days.first.id} • '
                      '${(days.first['kgCO2e'] as num).toStringAsFixed(2)} kg';

                  return ExpansionTile(
                    leading: const Icon(Icons.person),
                    title: Text(email),
                    subtitle: Text('latest: $latest'),
                    children: [
                      for (final d in days)
                        ListTile(
                          dense: true,
                          title: Text(d.id),                            // yyyy-MM-dd
                          trailing: Text(
                            '${(d['kgCO2e'] as num).toStringAsFixed(2)} kg',
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
