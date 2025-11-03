
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payload_codec.dart';

class QrService {
  final _db = FirebaseFirestore.instance;

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

    // Create attendance doc with ID equal to tokenId per rule
    await _db.collection('attendance').doc(eventId).collection('logs').doc(tokenId).set({
      'uid': uid,
      'at': FieldValue.serverTimestamp(),
      'method': method,
    });
  }

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

    await _db.collection('redemptions').doc(tokenId).set({
      'uid': uid,
      'rewardId': rewardId,
      'at': FieldValue.serverTimestamp(),
      'method': method,
    });
  }
}
