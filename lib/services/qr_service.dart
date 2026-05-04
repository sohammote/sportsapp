import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'payload_codec.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'badge_service.dart';

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

    // Step 1 — Check if this exact token was already used
    final existing = await _db
        .collection('attendance')
        .doc(eventId)
        .collection('logs')
        .doc(tokenId)
        .get();
    if (existing.exists) {
      throw Exception('You have already checked in with this QR code.');
    }

    // Step 2 — Check if user already attended THIS event (any token)
    final userEventLogs = await _db
        .collection('attendance')
        .doc(eventId)
        .collection('logs')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (userEventLogs.docs.isNotEmpty) {
      throw Exception(
          'You have already checked in to this event. Each event allows one check-in per person.');
    }

    // Step 3 — Get event points value
    final eventSnap =
    await _db.collection('events').doc(eventId).get();
    final eventData = eventSnap.data() as Map<String, dynamic>?;
    final pointsPerAttendance =
    (eventData?['pointsPerAttendance'] ?? 10) as int;

    // Step 4 — Write attendance log
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

    // Step 5 — Award points + increment attendance count
    await _firestoreService.awardPoints(
      uid: uid,
      points: pointsPerAttendance,
      eventId: eventId,
      tokenId: tokenId,
    );

    // Step 6 — Show local notification
    final eventName = eventData?['name'] as String? ?? 'the event';
    await NotificationService().showCheckInSuccessNotification(
      eventName: eventName,
      points: pointsPerAttendance,
    );

    // Step 7 — Update streak + check badges
    final badgeService = BadgeService();
    final newStreak = await badgeService.updateStreak(uid);

    // Get updated profile stats for badge check
    final profileSnap =
    await _db.collection('profiles').doc(uid).get();
    final profileData =
    profileSnap.data() as Map<String, dynamic>?;
    final totalAttendance =
    (profileData?['totalAttendance'] ?? 0) as int;
    final totalPoints = (profileData?['points'] ?? 0) as int;

    await badgeService.checkAndAwardBadges(
      uid: uid,
      totalAttendance: totalAttendance,
      totalPoints: totalPoints,
      currentStreak: newStreak,
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
      debugPrint('Warning: Redemption written but points deduction failed: $e');
    }

    // Step 6 — Show local notification
    await NotificationService().showRewardRedeemedNotification(
      rewardTitle: rewardTitle,
      pointsSpent: costPoints,
    );
  }
}