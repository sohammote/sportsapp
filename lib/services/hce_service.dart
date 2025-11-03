
import 'package:flutter/services.dart';

/// Bridge to Android HostApduService: start/stop broadcasting a token.
/// On iOS this will be a no-op.
class HceService {
  static const _channel = MethodChannel('nfc_hce/channel');

  Future<void> startAttendanceBroadcast(String base64urlPayload, {int ttlSeconds = 30}) async {
    await _channel.invokeMethod('startAttendance', {
      'payload': base64urlPayload,
      'ttlSeconds': ttlSeconds,
    });
  }

  Future<void> startRewardBroadcast(String base64urlPayload, {int ttlSeconds = 30}) async {
    await _channel.invokeMethod('startReward', {
      'payload': base64urlPayload,
      'ttlSeconds': ttlSeconds,
    });
  }

  Future<void> stopBroadcast() async {
    await _channel.invokeMethod('stop');
  }
}
