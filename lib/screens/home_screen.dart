import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_constants.dart';
import '../domain/health_logic.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final today = dayKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDoc.snapshots(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data?.data() ?? {};
          final name = profile['name'] ?? 'Pengguna';
          final target =
              (profile['dailySugarTargetGram'] as num?)?.toDouble() ??
              AppConstants.defaultSugarTargetGram;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroSummary(name: name.toString(), target: target),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userDoc
                    .collection('sugarLogs')
                    .where('dayKey', isEqualTo: today)
                    .snapshots(),
                builder: (context, snapshot) {
                  final logs =
                      snapshot.data?.docs.map((doc) => doc.data()).toList() ??
                      [];
                  final total = totalSugarForDay(logs, today);
                  return _MetricCard(
                    icon: Icons.restaurant_menu,
                    title: 'Gula hari ini',
                    value: '${total.toStringAsFixed(1)}g',
                    detail: 'Target ${target.toStringAsFixed(0)}g',
                    color: total > target
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userDoc
                    .collection('riskAssessments')
                    .orderBy('createdAt', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  final latest = snapshot.data?.docs.firstOrNull?.data();
                  return _MetricCard(
                    icon: Icons.health_and_safety,
                    title: 'Risiko terakhir',
                    value: latest == null ? '-' : latest['level'].toString(),
                    detail: latest == null
                        ? 'Belum ada assessment'
                        : 'Skor ${latest['score']} - BMI ${((latest['bmi'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}',
                    color: Theme.of(context).colorScheme.secondary,
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userDoc
                    .collection('challenges')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  final active = snapshot.data?.docs.length ?? 0;
                  return _MetricCard(
                    icon: Icons.emoji_events,
                    title: 'Tantangan aktif',
                    value: active.toString(),
                    detail: 'Challenge streak hidup sehat',
                    color: Theme.of(context).colorScheme.tertiary,
                  );
                },
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catatan SDG',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '${AppConstants.sdgLabel}. Fokus app ini adalah edukasi pencegahan penyakit tidak menular melalui pemantauan konsumsi gula.',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat(
                          'EEEE, d MMMM yyyy',
                          'id_ID',
                        ).format(DateTime.now()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.name, required this.target});

  final String name;
  final double target;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, $name',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Target gula harian kamu ${target.toStringAsFixed(0)}g.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            AppConstants.educationDisclaimer,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(detail),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
