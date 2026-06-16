import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'gula_alerts',
    'Sugar Pals Alerts',
    description: 'Notifikasi untuk konsumsi gula dan pesan Firebase.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
        // Inisialisasi timezone
    tz.initializeTimeZones();
    final timezoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timezoneName));
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(initSettings);  // ← positional, bukan named

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

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
    // 'id' → tidak ada, 'title' → tidak ada, 'notificationDetails' → 'details'
    await _localNotifications.show(
      2001,
      'Batas gula harian terlewati',
      'Hari ini ${totalGram.toStringAsFixed(1)}g dari target ${targetGram.toStringAsFixed(0)}g.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gula_alerts',
          'Sugar Pals Alerts',
          channelDescription:
              'Notifikasi untuk konsumsi gula dan pesan Firebase.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Dipanggil saat challenge berhasil diselesaikan
Future<void> showChallengeCompleted(String challengeTitle) async {
  await _localNotifications.show(
    3001,
    '🏆 Challenge selesai!',
    'Kamu berhasil menyelesaikan "$challengeTitle". Badge baru diraih!',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'gula_alerts',
        'Sugar Pals Alerts',
        channelDescription:
            'Notifikasi untuk konsumsi gula dan pesan Firebase.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

/// Dipanggil saat streak hari ini belum tercapai (reminder malam)
Future<void> showChallengeStreakReminder(String challengeTitle) async {
  await _localNotifications.show(
    3002,
    '⏰ Jangan lupa log gulamu!',
    'Challenge "$challengeTitle" butuh log gula hari ini sebelum tengah malam.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'gula_alerts',
        'Sugar Pals Alerts',
        channelDescription:
            'Notifikasi untuk konsumsi gula dan pesan Firebase.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

/// Dipanggil saat target harian challenge berhasil dipenuhi
Future<void> showChallengeStreakSuccess(
  String challengeTitle,
  int progressDays,
  int durationDays,
) async {
  await _localNotifications.show(
    3003,
    '🔥 Streak bertambah!',
    '$progressDays dari $durationDays hari berhasil di "$challengeTitle". Pertahankan!',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'gula_alerts',
        'Sugar Pals Alerts',
        channelDescription:
            'Notifikasi untuk konsumsi gula dan pesan Firebase.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

/// Schedule reminder jam 21.00 malam ini
/// Dipanggil saat user punya challenge aktif
Future<void> scheduleEveningReminder(String challengeTitle) async {
  // Batalkan reminder sebelumnya dulu
  await _localNotifications.cancel(3004);

  final now = tz.TZDateTime.now(tz.local);
  var scheduledTime = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    21, // jam 21.00
    0,
  );

  // Kalau jam 21.00 hari ini sudah lewat, schedule besok
  if (scheduledTime.isBefore(now)) {
    scheduledTime = scheduledTime.add(const Duration(days: 1));
  }

  await _localNotifications.zonedSchedule(
    3004,
    '⏰ Jangan lupa log gulamu!',
    'Challenge "$challengeTitle" butuh log gula hari ini sebelum tengah malam.',
    scheduledTime,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'gula_alerts',
        'Sugar Pals Alerts',
        channelDescription:
            'Notifikasi untuk konsumsi gula dan pesan Firebase.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:   // ← tambahkan ini
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

/// Batalkan reminder saat tidak ada challenge aktif
Future<void> cancelEveningReminder() async {
  await _localNotifications.cancel(3004);
}


  Future<void> _showRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Sugar Pals';
    final body =
        notification?.body ?? message.data['body'] ?? 'Ada pesan baru.';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gula_alerts',
          'Sugar Pals Alerts',
          channelDescription:
              'Notifikasi untuk konsumsi gula dan pesan Firebase.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}