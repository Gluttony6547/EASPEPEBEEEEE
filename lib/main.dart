import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_constants.dart';
import 'firebase_options.dart';
import 'navigation_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/challenge_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/risk_screen.dart';
import 'screens/sugar_log_screen.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  await initializeDateFormatting('id_ID');
  Intl.defaultLocale = 'id_ID';

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService.instance.initialize();

  runApp(const GulaDarahkuApp());
}

class GulaDarahkuApp extends StatelessWidget {
  const GulaDarahkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF173528),
          primary: const Color(0xFF173528),
          secondary: const Color(0xFF2F6B47),
          tertiary: const Color(0xFFD79036),
          error: const Color(0xFFD7654C),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F5EE),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF13251F),
          titleTextStyle: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF13251F),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFCF6),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE7E0D6)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFCF6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE7E0D6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE7E0D6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF173528), width: 1.5),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPanel(message: 'Menyiapkan sesi...');
        }
        final user = snapshot.data;
        if (user == null) return const AuthScreen();
        return ProfileGate(user: user);
      },
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.user});

  final User user;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  @override
  void initState() {
    super.initState();
    unawaited(NotificationService.instance.syncToken(widget.user.uid));
  }

  @override
  Widget build(BuildContext context) {
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPanel(message: 'Mengambil profil...');
        }
        final data = snapshot.data?.data();
        if (data == null || data['profileCompleted'] != true) {
          return OnboardingScreen(user: widget.user);
        }
        return GulaNavigationShell(
          tabs: [
            NavigationTab(
              label: 'Beranda',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              child: HomeScreen(user: widget.user),
            ),
            NavigationTab(
              label: 'Risiko',
              icon: Icons.health_and_safety_outlined,
              selectedIcon: Icons.health_and_safety,
              child: RiskScreen(user: widget.user),
            ),
            NavigationTab(
              label: 'Log Gula',
              icon: Icons.restaurant_menu_outlined,
              selectedIcon: Icons.restaurant_menu,
              child: SugarLogScreen(user: widget.user),
            ),
            NavigationTab(
              label: 'Tantangan',
              icon: Icons.emoji_events_outlined,
              selectedIcon: Icons.emoji_events,
              child: ChallengeScreen(user: widget.user),
            ),
          ],
        );
      },
    );
  }
}

class SplashPanel extends StatelessWidget {
  const SplashPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
