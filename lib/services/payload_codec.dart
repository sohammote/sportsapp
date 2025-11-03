
import 'dart:convert';

/// Compact attendance payload: {k:"att", t:"<tokenId>", e:"<eventId>"}
/// Compact reward payload:     {k:"rew", t:"<tokenId>", r:"<rewardId>"}
/// URI: sportsapp://checkin?d=<base64url> or sportsapp://reward?d=<base64url>
class PayloadCodec {
  static String encodeAttendance({required String tokenId, required String eventId}) {
    final map = {'k': 'att', 't': tokenId, 'e': eventId};
    final jsonStr = json.encode(map);
    return base64Url.encode(utf8.encode(jsonStr));
  }

  static String encodeReward({required String tokenId, required String rewardId}) {
    final map = {'k': 'rew', 't': tokenId, 'r': rewardId};
    final jsonStr = json.encode(map);
    return base64Url.encode(utf8.encode(jsonStr));
  }

  static Map<String, dynamic> decode(String base64url) {
    final jsonStr = utf8.decode(base64Url.decode(base64url));
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  static Uri buildAttendanceUri(String tokenId, String eventId) =>
      Uri.parse('sportsapp://checkin?d=${encodeAttendance(tokenId: tokenId, eventId: eventId)}');

  static Uri buildRewardUri(String tokenId, String rewardId) =>
      Uri.parse('sportsapp://reward?d=${encodeReward(tokenId: tokenId, rewardId: rewardId)}');
}
