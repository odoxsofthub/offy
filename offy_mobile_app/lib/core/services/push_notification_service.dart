import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../navigation/app_router.dart';
import '../theme/app_colors.dart';
import 'token_storage.dart';

/// Android notification channel.
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'odox_mobile_default',
  'Employee App',
  description: 'Payslips, time off and expense updates.',
  importance: Importance.high,
);

class PushNotificationService {
  PushNotificationService({this.tokenStorage});

  /// Monochrome small icon (android/.../drawable/ic_stat_offy.xml); a colour
  /// launcher icon renders as a white/grey square on many Android phones.
  static const String _smallIcon = '@drawable/ic_stat_offy';

  final TokenStorage? tokenStorage;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _setUpLocalNotifications();

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _openFromPayload(message.data),
    );

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _openFromPayload(initial.data);
  }

  Future<void> _setUpLocalNotifications() async {
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map) {
            _openFromPayload(Map<String, dynamic>.from(data));
          }
        } on FormatException catch (e) {
          log('PushNotificationService: Failed to parse payload JSON: $e');
        } catch (e) {
          log('PushNotificationService: Error processing payload: $e');
        }
      },
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    log('Push received in foreground: ${message.data}');

    if (!Platform.isAndroid) return;

    final token = await tokenStorage?.readBearerToken();
    if (token == null || token.isEmpty) {
      log('User logged out; ignoring foreground push notification.');
      return;
    }

    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      _notificationId(message),
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          color: AppColors.main,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Stable id derived from the message.
  int _notificationId(RemoteMessage message) {
    final type = message.data['type'] ?? '';
    final recordId = message.data['payslip_id'] ??
        message.data['leave_id'] ??
        message.data['expense_id'] ??
        '';
    final key = '$type:$recordId';
    return key.hashCode & 0x7fffffff;
  }

  /// Route from a tapped notification.
  void _openFromPayload(Map<String, dynamic> data) {
    log('Notification tapped: $data');
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamed(AppRouter.notification);
  }

  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    log('User granted permission: ${settings.authorizationStatus}');

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<String?> getToken() async {
    try {
      final token = await _fcm.getToken();
      log('FCM Token: $token');
      return token;
    } catch (e) {
      log('Failed to get FCM token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      log('FCM Token deleted successfully');
    } catch (e) {
      log('Failed to delete FCM token: $e');
    }
  }
}
