import 'package:cloud_firestore/cloud_firestore.dart';


class FirestoreService {
  final db = FirebaseFirestore.instance;


  // ── Collection refs ──
  CollectionReference profiles() => db.collection('profiles');
  CollectionReference events() => db.collection('events');
  CollectionReference rewards() => db.collection('rewards');
  CollectionReference rewardConfigs() => db.collection('rewardConfigs');
  CollectionReference tokens() => db.collection('tokens');
  CollectionReference attendance(String eventId) =>
      db.collection('attendance').doc(eventId).collection('logs');
  CollectionReference ledgers(String uid) =>
      db.collection('ledgers').doc(uid).collection('entries');
  CollectionReference rewardTokens() => db.collection('rewardTokens');
  CollectionReference redemptions() => db.collection('redemptions');

  // ── Ensure user profile exists with all fields ──
  Future<void> ensureProfile(String uid, String email) async {
    final doc = profiles().doc(uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'email': email,
        'isAdmin': false,
        'points': 0,
        'totalAttendance': 0,
        'name': email.split('@')[0],
        'streak': 0,
        'badges': [],
        'lastCheckIn': null,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ── Award points to user after check-in ──
  Future<void> awardPoints({
    required String uid,
    required int points,
    required String eventId,
    required String tokenId,
  }) async {
    final batch = db.batch();

    final profileRef = profiles().doc(uid);
    batch.update(profileRef, {
      'points': FieldValue.increment(points),
      'totalAttendance': FieldValue.increment(1),
    });

    final ledgerRef = ledgers(uid).doc();
    batch.set(ledgerRef, {
      'points': points,
      'type': 'earn',
      'reason': 'Attended event',
      'eventId': eventId,
      'refId': tokenId,
      'at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Deduct points when user redeems a reward ──
  Future<void> deductPoints({
    required String uid,
    required int points,
    required String rewardId,
    required String tokenId,
    required String rewardTitle,
  }) async {
    final profileSnap = await profiles().doc(uid).get();
    final data = profileSnap.data() as Map<String, dynamic>?;
    final currentPoints = (data?['points'] ?? 0) as int;

    if (currentPoints < points) {
      throw Exception(
          'Not enough points. You have $currentPoints but need $points.');
    }

    final batch = db.batch();

    batch.update(profiles().doc(uid), {
      'points': FieldValue.increment(-points),
    });

    final ledgerRef = ledgers(uid).doc();
    batch.set(ledgerRef, {
      'points': -points,
      'type': 'spend',
      'reason': 'Redeemed: $rewardTitle',
      'rewardId': rewardId,
      'refId': tokenId,
      'at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Get leaderboard top 20 users by points ──
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final snap = await profiles()
        .orderBy('points', descending: true)
        .limit(20)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'uid': doc.id,
        'name': data['name'] ?? 'Unknown',
        'points': data['points'] ?? 0,
        'totalAttendance': data['totalAttendance'] ?? 0,
        'email': data['email'] ?? '',
      };
    }).toList();
  }
}