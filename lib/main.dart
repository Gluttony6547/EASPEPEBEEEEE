import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_schema.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/bottom_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SugarPalsApp());
}

Future<void> seedChallenges() async {
  final db = FirebaseFirestore.instance;

  // Cek dulu apakah sudah ada data
  final existing = await db.collection(FSCollection.challenges).limit(1).get();
  if (existing.docs.isNotEmpty) {
    print('Challenges sudah ada, skip seed.');
    return;
  }

  final challenges = [
    {FSField.title: '7 Hari Tanpa Boba',       FSField.description: 'Hindari minuman manis selama 7 hari',          FSField.targetSugarGram: 30, FSField.durationDays: 7,  FSField.badgeIcon: 'cup_off'},
    {FSField.title: 'Minggu Sehat',             FSField.description: 'Jaga gula di bawah 50g setiap hari',           FSField.targetSugarGram: 50, FSField.durationDays: 7,  FSField.badgeIcon: 'leaf'},
    {FSField.title: 'Tantangan 3 Hari',         FSField.description: 'Konsumsi gula di bawah 25g per hari',          FSField.targetSugarGram: 25, FSField.durationDays: 3,  FSField.badgeIcon: 'star'},
    {FSField.title: 'Diet Gula 14 Hari',        FSField.description: 'Konsistensi 2 minggu dengan batas 40g/hari',   FSField.targetSugarGram: 40, FSField.durationDays: 14, FSField.badgeIcon: 'trophy'},
    {FSField.title: 'Detoks Weekend',           FSField.description: 'Gula di bawah 20g di Sabtu dan Minggu',        FSField.targetSugarGram: 20, FSField.durationDays: 2,  FSField.badgeIcon: 'heart'},
  ];

  for (final c in challenges) {
    await db.collection(FSCollection.challenges).add(c);
  }
  print('Seed selesai — ${challenges.length} tantangan ditambahkan.');
}

class SugarPalsApp extends StatelessWidget {
  const SugarPalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SugarPals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Cek status login — kalau sudah login langsung ke home
      home: StreamBuilder(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) return const BottomNavBar();
          return const LoginScreen();
        },
      ),
    );
  }
}