
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'payload_codec.dart';

class NfcReaderService {
  final _db = FirebaseFirestore.instance;

  // Reader mode for HCE (APDU / ISO-DEP)
  // AID example: F01234567890
  static const String aidHex = 'F01234567890';
  static const int INS_GET_ATT = 0xA1;
  static const int INS_GET_REW = 0xB1;

  Future<void> readPhoneHceAttendance({required String uid}) async {
    NFCTag tag = await FlutterNfcKit.poll(
      iosMultipleTagMessage: 'Hold near the other phone',
      androidCheckNDEF: false,
    );

    // Send SELECT APDU to HCE service
    final select = _buildSelectApdu(aidHex);
    await FlutterNfcKit.transceive(select);

    // Send GET_ATTENDANCE_TOKEN
    final getAtt = _buildIns(INS_GET_ATT);
    final resp = await FlutterNfcKit.transceive(getAtt);
    final payload = _parseResponse(resp);
    final map = PayloadCodec.decode(payload);
    if (map['k'] != 'att') throw Exception('Unexpected payload kind');
    final tokenId = map['t'] as String;
    final eventId = map['e'] as String;

    await _db.collection('attendance').doc(eventId).collection('logs').doc(tokenId).set({
      'uid': uid,
      'at': FieldValue.serverTimestamp(),
      'method': 'nfc-hce',
    });

    await FlutterNfcKit.finish();
  }

  Future<void> readPhoneHceReward({required String uid}) async {
    await FlutterNfcKit.poll(androidCheckNDEF: false);
    await FlutterNfcKit.transceive(_buildSelectApdu(aidHex));
    final resp = await FlutterNfcKit.transceive(_buildIns(INS_GET_REW));
    final payload = _parseResponse(resp);
    final map = PayloadCodec.decode(payload);
    if (map['k'] != 'rew') throw Exception('Unexpected payload kind');
    final tokenId = map['t'] as String;
    final rewardId = map['r'] as String;

    await _db.collection('redemptions').doc(tokenId).set({
      'uid': uid,
      'rewardId': rewardId,
      'at': FieldValue.serverTimestamp(),
      'method': 'nfc-hce',
    });

    await FlutterNfcKit.finish();
  }

  // NDEF read/write with nfc_manager is handled in NfcWriteService for tag fallback.

  // ---------- APDU helpers ----------
  String _buildSelectApdu(String aidHex) {
    final aidBytes = _hexToBytes(aidHex);
    final header = Uint8List.fromList([0x00, 0xA4, 0x04, 0x00, aidBytes.length]);
    final cmd = Uint8List(header.length + aidBytes.length + 1);
    cmd.setAll(0, header);
    cmd.setAll(header.length, aidBytes);
    cmd[cmd.length - 1] = 0x00; // Le
    return _bytesToHex(cmd);
  }

  String _buildIns(int ins) {
    final cmd = Uint8List.fromList([0x80, ins, 0x00, 0x00, 0x00]);
    return _bytesToHex(cmd);
  }

  String _parseResponse(String hex) {
    // Response: <payload base64url utf8 bytes> || 0x90 0x00
    final bytes = _hexToBytes(hex);
    if (bytes.length < 2 || bytes[bytes.length - 2] != 0x90 || bytes[bytes.length - 1] != 0x00) {
      throw Exception('APDU failed');
    }
    final payloadBytes = bytes.sublist(0, bytes.length - 2);
    return String.fromCharCodes(payloadBytes);
  }

  Uint8List _hexToBytes(String hex) {
    final sanitized = hex.replaceAll(' ', '');
    final out = Uint8List(sanitized.length ~/ 2);
    for (int i = 0; i < sanitized.length; i += 2) {
      out[i ~/ 2] = int.parse(sanitized.substring(i, i + 2), radix: 16);
    }
    return out;
  }

  String _bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString().toUpperCase();
  }
}
