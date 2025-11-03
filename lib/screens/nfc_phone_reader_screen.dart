
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class NfcPhoneReaderScreen extends ConsumerStatefulWidget {
  const NfcPhoneReaderScreen({super.key});

  @override
  ConsumerState<NfcPhoneReaderScreen> createState() => _NfcPhoneReaderScreenState();
}

class _NfcPhoneReaderScreenState extends ConsumerState<NfcPhoneReaderScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone-to-Phone NFC (Reader)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Hold your phone near the admin phone broadcasting HCE to read token.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                setState(() => _status = 'Reading attendance token via HCE...');
                try {
                  await ref.read(nfcReaderServiceProvider).readPhoneHceAttendance(uid: uid);
                  setState(() => _status = 'Attendance recorded!');
                } catch (e) {
                  setState(() => _status = 'Failed: $e');
                }
              },
              child: const Text('Read Attendance Token'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () async {
                setState(() => _status = 'Reading reward token via HCE...');
                try {
                  await ref.read(nfcReaderServiceProvider).readPhoneHceReward(uid: uid);
                  setState(() => _status = 'Reward redeemed!');
                } catch (e) {
                  setState(() => _status = 'Failed: $e');
                }
              },
              child: const Text('Read Reward Token'),
            ),
            const SizedBox(height: 16),
            if (_status != null) Text(_status!),
          ],
        ),
      ),
    );
  }
}
