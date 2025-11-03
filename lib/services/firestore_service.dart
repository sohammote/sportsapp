
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final db = FirebaseFirestore.instance;

  // Collection refs
  CollectionReference profiles() => db.collection('profiles');
  CollectionReference events() => db.collection('events');
  CollectionReference rewards() => db.collection('rewards');
  CollectionReference rewardConfigs() => db.collection('rewardConfigs');
  CollectionReference tokens() => db.collection('tokens');
  CollectionReference attendance(String eventId) => db.collection('attendance').doc(eventId).collection('logs');
  CollectionReference ledgers(String uid) => db.collection('ledgers').doc(uid).collection('entries');
  CollectionReference rewardTokens() => db.collection('rewardTokens');
  CollectionReference redemptions() => db.collection('redemptions');

  Future<void> ensureProfile(String uid, String email) async {
    final doc = profiles().doc(uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'email': email,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
