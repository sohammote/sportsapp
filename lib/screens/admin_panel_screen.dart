
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/payload_codec.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  final _eventName = TextEditingController();
  DateTime _start = DateTime.now().add(const Duration(minutes: 1));
  DateTime _end = DateTime.now().add(const Duration(hours: 1));
  String? _eventId;

  String? _lastAttendanceToken;
  String? _lastRewardToken;
  String? _status;

  @override
  void dispose() {
    _eventName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Events', style: Theme.of(context).textTheme.titleLarge),
          Row(
            children: [
              Expanded(child: TextField(controller: _eventName, decoration: const InputDecoration(labelText: 'Event name'))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final id = await ref.read(adminServiceProvider).createEvent(
                    ownerUid: user.uid,
                    name: _eventName.text.trim(),
                    startsAt: _start,
                    endsAt: _end,
                  );
                  setState(() => _eventId = id);
                },
                child: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_eventId != null) Text('Created event: $_eventId'),

          const Divider(height: 32),

          Text('Generate Attendance Token (one-time, TTL 60s)', style: Theme.of(context).textTheme.titleLarge),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Event ID'),
                  controller: TextEditingController(text: _eventId ?? ''),
                  onChanged: (v) => _eventId = v,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  if (_eventId == null || _eventId!.isEmpty) return;
                  final tokenId = await ref.read(adminServiceProvider).createAttendanceToken(
                    eventId: _eventId!,
                    createdBy: user.uid,
                    ttl: const Duration(seconds: 60),
                  );
                  setState(() => _lastAttendanceToken = tokenId);
                },
                child: const Text('Create Token'),
              ),
            ],
          ),
          if (_lastAttendanceToken != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                SelectableText('Attendance tokenId: $_lastAttendanceToken'),
                SelectableText('Attendance URI: ${PayloadCodec.buildAttendanceUri(_lastAttendanceToken!, _eventId!)}'),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final base64url = PayloadCodec.encodeAttendance(tokenId: _lastAttendanceToken!, eventId: _eventId!);
                        await ref.read(hceServiceProvider).startAttendanceBroadcast(base64url, ttlSeconds: 60);
                        setState(() => _status = 'Broadcasting HCE attendance for 60s');
                      },
                      child: const Text('Start HCE Broadcast'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(hceServiceProvider).stopBroadcast();
                        setState(() => _status = 'Stopped HCE');
                      },
                      child: const Text('Stop HCE'),
                    ),
                  ],
                ),
              ],
            ),

          const Divider(height: 32),
          Text('Rewards', style: Theme.of(context).textTheme.titleLarge),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  // Create a demo reward
                  final r = await ref.read(firestoreServiceProvider).rewards().add({
                    'title': 'Water Bottle',
                    'description': 'Branded bottle',
                    'costPoints': 50,
                    'active': true,
                    'createdBy': user.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  setState(() => _status = 'Created reward: ${r.id}');
                },
                child: const Text('Create Demo Reward'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  // Create reward token for first active reward
                  final rewards = await ref.read(firestoreServiceProvider).rewards().where('active', isEqualTo: true).limit(1).get();
                  if (rewards.docs.isEmpty) { setState(() => _status = 'No active rewards'); return; }
                  final rewardId = rewards.docs.first.id;
                  final tokenId = await ref.read(adminServiceProvider).createRewardToken(
                    rewardId: rewardId,
                    createdBy: user.uid,
                    ttl: const Duration(seconds: 60),
                  );
                  setState(() => _lastRewardToken = tokenId);
                },
                child: const Text('Issue Reward Token (TTL 60s)'),
              ),
            ],
          ),
          if (_lastRewardToken != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                SelectableText('Reward tokenId: $_lastRewardToken'),
                ElevatedButton(
                  onPressed: () async {
                    final base64url = PayloadCodec.encodeReward(tokenId: _lastRewardToken!, rewardId: 'AUTO');
                    await ref.read(hceServiceProvider).startRewardBroadcast(base64url, ttlSeconds: 60);
                    setState(() => _status = 'Broadcasting HCE reward for 60s');
                  },
                  child: const Text('Start HCE Reward Broadcast'),
                ),
              ],
            ),

          const SizedBox(height: 16),
          if (_status != null) Text(_status!, style: const TextStyle(color: Colors.blue)),
        ],
      ),
    );
  }
}
