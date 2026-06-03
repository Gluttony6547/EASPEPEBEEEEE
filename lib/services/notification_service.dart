import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // Minta izin notifikasi
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Simpan token FCM ke Firestore
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(token);

    // Handle notifikasi saat app di foreground
    FirebaseMessaging.onMessage.listen((message) {
      print('Notif diterima: ${message.notification?.title}');
    });

    // Refresh token otomatis
    _fcm.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token});
  }
}