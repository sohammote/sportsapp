
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final query = FirebaseFirestore.instance
        .collectionGroup('logs')
        .where('uid', isEqualTo: uid)
        .orderBy('at', descending: true)
        .limit(50);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No attendance yet'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final at = (d['at'] as Timestamp?)?.toDate().toLocal();
              return ListTile(
                title: Text('Event log: ${docs[i].reference.parent.parent?.id ?? ''}'),
                subtitle: Text('${d['method']} • ${at ?? ''}'),
              );
            },
          );
        },
      ),
    );
  }
}
