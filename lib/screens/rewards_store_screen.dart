
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RewardsStoreScreen extends ConsumerWidget {
  const RewardsStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = FirebaseFirestore.instance.collection('rewards').where('active', isEqualTo: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards Store')),
      body: StreamBuilder<QuerySnapshot>(
        stream: col.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No rewards yet'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(d['title'] ?? ''),
                subtitle: Text(d['description'] ?? ''),
                trailing: Text('${d['costPoints'] ?? 0} pts'),
              );
            },
          );
        },
      ),
    );
  }
}
