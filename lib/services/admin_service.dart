import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firestore_service.dart';
import 'package:sportsapp/providers.dart';

typedef Reader = T Function<T>(ProviderListenable<T>);

class AdminService {
  AdminService(this._read);
  final Reader _read;

  FirebaseFirestore get _db => _read(firestoreServiceProvider).db;

  String _randId([int len = 20]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ── Create event with points per attendance ──
  Future<String> createEvent({
    required String ownerUid,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
    int pointsPerAttendance = 10,
  }) async {
    final doc = _db.collection('events').doc();
    await doc.set({
      'ownerUid': ownerUid,
      'name': name,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'pointsPerAttendance': pointsPerAttendance,
    });
    await _db
        .collection('eventMembers')
        .doc(doc.id)
        .collection('members')
        .doc(ownerUid)
        .set({'role': 'owner'});
    return doc.id;
  }

  // ── Create reward (no image for now) ──
  Future<String> createReward({
    required String title,
    required String description,
    required int costPoints,
    required String createdBy,
  }) async {
    final doc = _db.collection('rewards').doc();
    await doc.set({
      'title': title,
      'description': description,
      'costPoints': costPoints,
      'active': true,
      'imageUrl': null,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ── Update reward ──
  Future<void> updateReward({
    required String rewardId,
    required String title,
    required String description,
    required int costPoints,
  }) async {
    await _db.collection('rewards').doc(rewardId).update({
      'title': title,
      'description': description,
      'costPoints': costPoints,
    });
  }

  // ── Delete reward ──
  Future<void> deleteReward(String rewardId) async {
    await _db.collection('rewards').doc(rewardId).delete();
  }

  Future<String> createAttendanceToken({
    required String eventId,
    required String createdBy,
    required Duration ttl,
  }) async {
    final tokenId = _randId(24);
    final expiresAt = DateTime.now().toUtc().add(ttl);
    await _db.collection('tokens').doc(tokenId).set({
      'eventId': eventId,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': true,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return tokenId;
  }

  Future<String> createRewardToken({
    required String rewardId,
    required String createdBy,
    required Duration ttl,
    String? intendedUid,
  }) async {
    final tokenId = _randId(24);
    final expiresAt = DateTime.now().toUtc().add(ttl);
    await _db.collection('rewardTokens').doc(tokenId).set({
      'rewardId': rewardId,
      'uid': intendedUid,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': true,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return tokenId;
  }

  Future<void> deactivateToken(String tokenId) {
    return _db.collection('tokens').doc(tokenId).update({'isActive': false});
  }

  Future<void> deactivateRewardToken(String tokenId) {
    return _db
        .collection('rewardTokens')
        .doc(tokenId)
        .update({'isActive': false});
  }
}