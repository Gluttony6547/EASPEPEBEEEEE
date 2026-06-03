import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'gula_alerts',
    'GulaDarahku Alerts',
    description: 'Notifikasi untuk konsumsi gula dan pesan Firebase.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(settings: initSettings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessage.listen(_showRemoteMessage);
  }

  Future<void> syncToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': newToken,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> showSugarWarning({
    required double totalGram,
    required double targetGram,
  }) async {
    await _localNotifications.show(
      id: 2001,
      title: 'Batas gula harian terlewati',
      body:
          'Hari ini ${totalGram.toStringAsFixed(1)}g dari target ${targetGram.toStringAsFixed(0)}g.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'gula_alerts',
          'GulaDarahku Alerts',
          channelDescription:
              'Notifikasi untuk konsumsi gula dan pesan Firebase.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> _showRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'GulaDarahku';
    final body =
        notification?.body ?? message.data['body'] ?? 'Ada pesan baru.';

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'gula_alerts',
          'GulaDarahku Alerts',
          channelDescription:
              'Notifikasi untuk konsumsi gula dan pesan Firebase.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
