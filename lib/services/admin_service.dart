
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firestore_service.dart';
import 'package:sportsapp/providers.dart';

typedef Reader = T Function<T>(ProviderListenable<T>);

class AdminService {
  AdminService(this._read);
  final Reader _read;

  FirebaseFirestore get _db => _read(firestoreServiceProvider).db;

  String _randId([int len = 20]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<String> createEvent({
    required String ownerUid,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final doc = _db.collection('events').doc();
    await doc.set({
      'ownerUid': ownerUid,
      'name': name,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
    });
    // Add owner membership
    await _db.collection('eventMembers').doc(doc.id).collection('members').doc(ownerUid).set({
      'role': 'owner',
    });
    return doc.id;
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
    return _db.collection('rewardTokens').doc(tokenId).update({'isActive': false});
  }
}
