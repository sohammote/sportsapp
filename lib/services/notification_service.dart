import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

// ── Background message handler (must be top-level) ──
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance =
  NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // ── Android notification channel ──
  static const _channelId = 'sportsapp_main';
  static const _channelName = 'Sports Attendance';
  static const _channelDesc =
      'Notifications for events, points and rewards';

  // ── FCM V2 scope ──
  static const _fcmScope =
      'https://www.googleapis.com/auth/firebase.messaging';

  // ── Initialize everything ──
  Future<void> initialize() async {
    await _requestPermissions();
    await _initLocalNotifications();
    await _saveToken();
    await _subscribeToTopics();
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  // ── Request permissions ──
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        'Notification permission: ${settings.authorizationStatus}');
  }

  // ── Initialize local notifications ──
  Future<void> _initLocalNotifications() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    // Create Android channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // ── Save FCM token to Firestore ──
  Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(uid)
          .update({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM token saved');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // ── Subscribe to topics ──
  Future<void> _subscribeToTopics() async {
    await _messaging.subscribeToTopic('all_users');
    await _messaging.subscribeToTopic('new_events');
    await _messaging.subscribeToTopic('new_rewards');
    debugPrint('Subscribed to FCM topics');
  }

  // ── Handle token refresh ──
  Future<void> _onTokenRefresh(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('profiles')
        .doc(uid)
        .update({'fcmToken': token});
  }

  // ── Handle foreground FCM message ──
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _showLocalNotification(
      title: notification.title ?? 'Sports Attendance',
      body: notification.body ?? '',
      payload: message.data['route'],
    );
  }

  // ── Handle notification tap ──
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
  }

  // ── Sign out cleanup ──
  Future<void> onSignOut() async {
    await _messaging.unsubscribeFromTopic('all_users');
    await _messaging.unsubscribeFromTopic('new_events');
    await _messaging.unsubscribeFromTopic('new_rewards');
    await _messaging.deleteToken();
  }

  // ═══════════════════════════════════════════
  // LOCAL NOTIFICATIONS
  // ═══════════════════════════════════════════

  Future<void> showCheckInSuccessNotification({
    required String eventName,
    required int points,
  }) async {
    await _showLocalNotification(
      title: '✅ Check-in Successful!',
      body: 'You checked in to $eventName and earned $points pts',
      payload: '/history',
    );
  }

  Future<void> showRewardRedeemedNotification({
    required String rewardTitle,
    required int pointsSpent,
  }) async {
    await _showLocalNotification(
      title: '🎁 Reward Redeemed!',
      body: 'You redeemed "$rewardTitle" for $pointsSpent points',
      payload: '/rewards',
    );
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(id, title, body, details,
        payload: payload);
  }

  // ═══════════════════════════════════════════
  // FCM V2 — SEND TO TOPIC (Push to all users)
  // Uses service_account.json for OAuth2 auth
  // ═══════════════════════════════════════════

  // ── Get OAuth2 access token from service account ──
  Future<String?> _getAccessToken() async {
    try {
      // Load service account JSON from assets
      final jsonStr = await rootBundle
          .loadString('assets/service_account.json');
      final jsonMap =
      json.decode(jsonStr) as Map<String, dynamic>;

      final credentials =
      ServiceAccountCredentials.fromJson(jsonMap);

      final client = await clientViaServiceAccount(
        credentials,
        [_fcmScope],
      );

      final token = client.credentials.accessToken.data;
      client.close();
      return token;
    } catch (e) {
      debugPrint('Error getting FCM access token: $e');
      return null;
    }
  }

  // ── Get Firebase project ID from service account ──
  Future<String?> _getProjectId() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/service_account.json');
      final jsonMap =
      json.decode(jsonStr) as Map<String, dynamic>;
      return jsonMap['project_id'] as String?;
    } catch (e) {
      debugPrint('Error reading project ID: $e');
      return null;
    }
  }

  // ── Core FCM V2 topic sender ──
  Future<bool> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('Could not get FCM access token');
        return false;
      }

      final projectId = await _getProjectId();
      if (projectId == null) {
        debugPrint('Could not get project ID');
        return false;
      }

      final url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final payload = {
        'message': {
          'topic': topic,
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'notification': {
              'channel_id': _channelId,
              'sound': 'default',
              'priority': 'high',
            },
            'priority': 'high',
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
                'badge': 1,
              },
            },
          },
          'data': data ?? {},
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM V2 notification sent to topic: $topic');
        return true;
      } else {
        debugPrint(
            '❌ FCM V2 error: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('FCM V2 send error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // PUSH NOTIFICATION TRIGGERS
  // ═══════════════════════════════════════════

  // ── Send notification to a specific device token ──
  Future<bool> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) return false;

      final projectId = await _getProjectId();
      if (projectId == null) return false;

      final url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final payload = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'notification': {
              'channel_id': _channelId,
              'sound': 'default',
              'priority': 'high',
            },
            'priority': 'high',
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
                'badge': 1,
              },
            },
          },
          'data': data ?? {},
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token notification sent');
        return true;
      } else {
        debugPrint(
            '❌ FCM token error: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('FCM token send error: $e');
      return false;
    }
  }

  // ── New event created ──
  Future<void> notifyNewEvent({
    required String eventName,
    required String startTime,
    required int points,
  }) async {
    await sendTopicNotification(
      topic: 'new_events',
      title: '📅 New Event: $eventName',
      body: 'Starting $startTime · Earn $points pts for attending!',
      data: {'route': '/events-calendar'},
    );
  }

  // ── Event updated ──
  Future<void> notifyEventUpdated({
    required String eventName,
  }) async {
    await sendTopicNotification(
      topic: 'new_events',
      title: '✏️ Event Updated: $eventName',
      body:
      'Details for "$eventName" have been updated. Check the calendar!',
      data: {'route': '/events-calendar'},
    );
  }

  // ── Event deleted ──
  Future<void> notifyEventDeleted({
    required String eventName,
  }) async {
    await sendTopicNotification(
      topic: 'new_events',
      title: '❌ Event Cancelled: $eventName',
      body: '"$eventName" has been cancelled.',
      data: {'route': '/events-calendar'},
    );
  }

  // ── New reward added ──
  Future<void> notifyNewReward({
    required String rewardTitle,
    required int costPoints,
  }) async {
    await sendTopicNotification(
      topic: 'new_rewards',
      title: '🎁 New Reward Available!',
      body:
      '"$rewardTitle" is now in the store for $costPoints pts!',
      data: {'route': '/rewards'},
    );
  }
}