import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  // ── Collection refs ──
  CollectionReference groups() => _db.collection('groups');
  CollectionReference joinRequests() =>
      _db.collection('joinRequests');
  CollectionReference messages(String groupId) =>
      _db.collection('groups').doc(groupId).collection('messages');
  CollectionReference members(String groupId) =>
      _db.collection('groups').doc(groupId).collection('members');

  // ── Create community group (auto all users) ──
  Future<String> createCommunityGroup({
    required String name,
    required String description,
    required String createdBy,
  }) async {
    final doc = groups().doc();
    await doc.set({
      'name': name,
      'description': description,
      'type': 'community',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'memberCount': 1,
    });
    // Add creator as admin member
    await members(doc.id).doc(createdBy).set({
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ── Create event group ──
  Future<String> createEventGroup({
    required String name,
    required String description,
    required String createdBy,
    String? eventId,
  }) async {
    final doc = groups().doc();
    await doc.set({
      'name': name,
      'description': description,
      'type': 'event',
      'eventId': eventId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'memberCount': 1,
    });
    await members(doc.id).doc(createdBy).set({
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ── Request to join a group ──
  Future<void> requestToJoin({
    required String groupId,
    required String uid,
    required String userName,
  }) async {
    // Check if already a member
    final memberSnap = await members(groupId).doc(uid).get();
    if (memberSnap.exists) throw Exception('Already a member');

    // Check if request already pending
    final existing = await joinRequests()
        .where('groupId', isEqualTo: groupId)
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Request already pending');
    }

    await joinRequests().add({
      'groupId': groupId,
      'uid': uid,
      'userName': userName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Approve join request ──
  Future<void> approveRequest({
    required String requestId,
    required String groupId,
    required String uid,
  }) async {
    final batch = _db.batch();

    // Update request status
    batch.update(joinRequests().doc(requestId), {
      'status': 'approved',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    // Add to members
    batch.set(members(groupId).doc(uid), {
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Increment member count
    batch.update(groups().doc(groupId), {
      'memberCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ── Reject join request ──
  Future<void> rejectRequest(String requestId) async {
    await joinRequests().doc(requestId).update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Auto-join community groups ──
  Future<void> autoJoinCommunityGroups(
      String uid, String userName) async {
    final communityGroups = await groups()
        .where('type', isEqualTo: 'community')
        .get();

    for (final group in communityGroups.docs) {
      final memberSnap =
      await members(group.id).doc(uid).get();
      if (!memberSnap.exists) {
        await members(group.id).doc(uid).set({
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        await groups().doc(group.id).update({
          'memberCount': FieldValue.increment(1),
        });
      }
    }
  }

  // ── Send message + notify all group members ──
  Future<void> sendMessage({
    required String groupId,
    required String uid,
    required String senderName,
    required String text,
    required String groupName,
  }) async {
    if (text.trim().isEmpty) return;

    // Write message to Firestore
    await messages(groupId).add({
      'uid': uid,
      'senderName': senderName,
      'text': text.trim(),
      'at': FieldValue.serverTimestamp(),
    });

    // Update last message on group
    await groups().doc(groupId).update({
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': senderName,
    });

    // ── Notify all other group members ──
    _notifyGroupMembers(
      groupId: groupId,
      senderUid: uid,
      senderName: senderName,
      groupName: groupName,
      message: text.trim(),
    );
  }

  // ── Fetch member tokens and send notifications ──
  Future<void> _notifyGroupMembers({
    required String groupId,
    required String senderUid,
    required String senderName,
    required String groupName,
    required String message,
  }) async {
    try {
      // Get all group members except sender
      final membersSnap = await members(groupId).get();
      final otherMemberUids = membersSnap.docs
          .map((d) => d.id)
          .where((id) => id != senderUid)
          .toList();

      if (otherMemberUids.isEmpty) return;

      // Get FCM tokens for each member
      final List<Future<void>> notifFutures = [];

      for (final memberUid in otherMemberUids) {
        notifFutures.add(_sendNotifToUser(
          uid: memberUid,
          title: '$senderName • $groupName',
          body: message,
          data: {'route': '/groups', 'groupId': groupId},
        ));
      }

      // Send all notifications in parallel
      await Future.wait(notifFutures);
    } catch (e) {
      debugPrint('Error notifying group members: $e');
    }
  }

  Future<void> _sendNotifToUser({
    required String uid,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final profileSnap =
      await _db.collection('profiles').doc(uid).get();
      final profileData =
      profileSnap.data() as Map<String, dynamic>?;
      final fcmToken =
      profileData?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) return;

      await NotificationService().sendToToken(
        token: fcmToken,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('Error sending notif to $uid: $e');
    }
  }

  // ── Delete message ──
  Future<void> deleteMessage(
      String groupId, String messageId) async {
    await messages(groupId).doc(messageId).delete();
  }

  // ── Leave group ──
  Future<void> leaveGroup(String groupId, String uid) async {
    await members(groupId).doc(uid).delete();
    await groups().doc(groupId).update({
      'memberCount': FieldValue.increment(-1),
    });
  }

  // ── Delete group ──
  Future<void> deleteGroup(String groupId) async {
    await groups().doc(groupId).delete();
  }

  // ── Check if user is member ──
  Future<bool> isMember(String groupId, String uid) async {
    final snap = await members(groupId).doc(uid).get();
    return snap.exists;
  }

  // ── Check pending request ──
  Future<bool> hasPendingRequest(
      String groupId, String uid) async {
    final snap = await joinRequests()
        .where('groupId', isEqualTo: groupId)
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Get user's groups ──
  Stream<QuerySnapshot> getUserGroups(String uid) {
    return _db
        .collectionGroup('members')
        .where(FieldPath.documentId, isEqualTo: uid)
        .snapshots();
  }

  // ── Get pending requests for admin ──
  Stream<QuerySnapshot> getPendingRequests() {
    return joinRequests()
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}