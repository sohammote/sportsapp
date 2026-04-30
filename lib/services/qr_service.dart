import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'payload_codec.dart';
import 'firestore_service.dart';

class QrService {
  final _db = FirebaseFirestore.instance;
  final _firestoreService = FirestoreService();

  // ── QR Attendance check-in + award points ──
  Future<void> consumeAttendanceFromUri({
    required Uri uri,
    required String uid,
    required String method,
  }) async {
    final d = uri.queryParameters['d'];
    if (d == null) throw ArgumentError('Missing payload');
    final map = PayloadCodec.decode(d);
    if (map['k'] != 'att') throw ArgumentError('Not an attendance payload');
    final tokenId = map['t'] as String;
    final eventId = map['e'] as String;

    // Check if already checked in with this token
    final existing = await _db
        .collection('attendance')
        .doc(eventId)
        .collection('logs')
        .doc(tokenId)
        .get();
    if (existing.exists) {
      throw Exception('You have already checked in with this QR code.');
    }

    // Get event points value
    final eventSnap = await _db.collection('events').doc(eventId).get();
    final eventData = eventSnap.data() as Map<String, dynamic>?;
    final pointsPerAttendance = (eventData?['pointsPerAttendance'] ?? 10) as int;

    // Write attendance log
    await _db
        .collection('attendance')
        .doc(eventId)
        .collection('logs')
        .doc(tokenId)
        .set({
      'uid': uid,
      'at': FieldValue.serverTimestamp(),
      'method': method,
      'pointsAwarded': pointsPerAttendance,
    });

    // Award points + increment attendance count
    await _firestoreService.awardPoints(
      uid: uid,
      points: pointsPerAttendance,
      eventId: eventId,
      tokenId: tokenId,
    );
  }

  // ── QR Reward redemption + deduct points ──
  Future<void> redeemRewardFromUri({
    required Uri uri,
    required String uid,
    required String method,
  }) async {
    final d = uri.queryParameters['d'];
    if (d == null) throw ArgumentError('Missing payload');
    final map = PayloadCodec.decode(d);
    if (map['k'] != 'rew') throw ArgumentError('Not a reward payload');
    final tokenId = map['t'] as String;
    final rewardId = map['r'] as String;

    // Step 1 — Check if already redeemed
    final existing =
    await _db.collection('redemptions').doc(tokenId).get();
    if (existing.exists) {
      throw Exception('This reward has already been redeemed.');
    }

    // Step 2 — Get reward details
    final rewardSnap =
    await _db.collection('rewards').doc(rewardId).get();
    final rewardData = rewardSnap.data() as Map<String, dynamic>?;
    if (rewardData == null) throw Exception('Reward not found.');
    final costPoints = (rewardData['costPoints'] ?? 0) as int;
    final rewardTitle = rewardData['title'] as String? ?? 'Reward';

    // Step 3 — Check user has enough points BEFORE doing anything
    final profileSnap =
    await _db.collection('profiles').doc(uid).get();
    final profileData = profileSnap.data() as Map<String, dynamic>?;
    final currentPoints = (profileData?['points'] ?? 0) as int;
    if (currentPoints < costPoints) {
      throw Exception(
          'Not enough points. You have $currentPoints but need $costPoints.');
    }

    // Step 4 — Write redemption document FIRST (safe — if this fails, no points lost)
    await _db.collection('redemptions').doc(tokenId).set({
      'uid': uid,
      'rewardId': rewardId,
      'rewardTitle': rewardTitle,
      'pointsSpent': costPoints,
      'at': FieldValue.serverTimestamp(),
      'method': method,
    });

    // Step 5 — Deduct points ONLY after redemption is confirmed written
    try {
      await _firestoreService.deductPoints(
        uid: uid,
        points: costPoints,
        rewardId: rewardId,
        tokenId: tokenId,
        rewardTitle: rewardTitle,
      );
    } catch (e) {
      // If points deduction fails, redemption is already written
      // Log the error but don't re-throw — reward was given
      // Admin can manually adjust points if needed
      debugPrint('Warning: Redemption written but points deduction failed: $e');
    }
  }
}