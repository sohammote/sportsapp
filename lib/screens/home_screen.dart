
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../routes.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, Routes.history),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: ref.read(firestoreServiceProvider).profiles().doc(user.uid).snapshots(),
        builder: (ctx, snap) {
          final isAdmin = (snap.data?.data() as Map?)?['isAdmin'] == true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Welcome ${user.email}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, Routes.qrScanner),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR for Check-in / Rewards'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, Routes.nfcPhoneReader),
                icon: const Icon(Icons.nfc),
                label: const Text('Phone-to-Phone NFC (Reader)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, Routes.nfcTag),
                icon: const Icon(Icons.contactless),
                label: const Text('NFC Tag Read/Write (Fallback)'),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pushNamed(context, Routes.rewards),
                icon: const Icon(Icons.storefront),
                label: const Text('Rewards Store'),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, Routes.adminPanel),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Admin Panel'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
