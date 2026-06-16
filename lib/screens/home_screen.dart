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
            tooltip: 'Edit profil',
            onPressed: () => _showProfileForm(context, userDoc),
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
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
          final weeklyExerciseTarget =
              (profile['weeklyExerciseTargetMinutes'] as num?)?.toDouble() ??
              AppConstants.defaultWeeklyExerciseTargetMinutes;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                    .collection('activityLogs')
                    .where('dayKey', isEqualTo: today)
                    .snapshots(),
                builder: (context, snapshot) {
                  final activities =
                      snapshot.data?.docs.map((doc) => doc.data()).toList() ??
                      [];
                  final distance = activities.fold<double>(
                    0,
                    (runningTotal, data) =>
                        runningTotal +
                        ((data['distanceKm'] as num?)?.toDouble() ?? 0),
                  );
                  final calories = activities.fold<double>(
                    0,
                    (runningTotal, data) =>
                        runningTotal +
                        ((data['estimatedCaloriesBurned'] as num?)
                                ?.toDouble() ??
                            0),
                  );
                  return _MetricCard(
                    icon: Icons.directions_run,
                    title: 'Aktivitas hari ini',
                    value: '${calories.toStringAsFixed(0)} kkal',
                    detail:
                        '${distance.toStringAsFixed(1)} km jalan/lari. Estimasi berbasis MET.',
                    color: const Color(0xFF2F6B47),
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userDoc.collection('activityLogs').snapshots(),
                builder: (context, snapshot) {
                  final logs =
                      snapshot.data?.docs.map((doc) => doc.data()).toList() ??
                      [];
                  final completed = totalActivityDurationForWeek(
                    logs,
                    weekDate: DateTime.now(),
                  );
                  return _WeeklyExerciseCard(
                    completedMinutes: completed,
                    targetMinutes: weeklyExerciseTarget,
                    weekDate: DateTime.now(),
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

  Future<void> _showProfileForm(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> userDoc,
  ) async {
    final snapshot = await userDoc.get();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileFormSheet(
        userDoc: userDoc,
        initialData: snapshot.data() ?? {},
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

class _WeeklyExerciseCard extends StatelessWidget {
  const _WeeklyExerciseCard({
    required this.completedMinutes,
    required this.targetMinutes,
    required this.weekDate,
  });

  final double completedMinutes;
  final double targetMinutes;
  final DateTime weekDate;

  @override
  Widget build(BuildContext context) {
    final safeTarget = targetMinutes <= 0
        ? AppConstants.defaultWeeklyExerciseTargetMinutes
        : targetMinutes;
    final ratio = (completedMinutes / safeTarget).clamp(0.0, 1.0);
    final start = weekStart(weekDate);
    final end = weekEnd(weekDate);
    final completedText = completedMinutes.toStringAsFixed(0);
    final targetText = safeTarget.toStringAsFixed(0);
    const color = Color(0xFF2F6B47);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE1F1E8),
                  foregroundColor: color,
                  child: Icon(Icons.timeline_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olahraga minggu ini',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM').format(end)}',
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$completedText/$targetText menit',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: ratio,
              color: color,
              backgroundColor: const Color(0xFFE7E0D6),
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFormSheet extends StatefulWidget {
  const _ProfileFormSheet({required this.userDoc, required this.initialData});

  final DocumentReference<Map<String, dynamic>> userDoc;
  final Map<String, dynamic> initialData;

  @override
  State<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<_ProfileFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _sugarTargetController;
  late final TextEditingController _weeklyExerciseController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: ((data['heightCm'] as num?)?.toDouble() ?? 170).toStringAsFixed(0),
    );
    _weightController = TextEditingController(
      text: ((data['weightKg'] as num?)?.toDouble() ?? 65).toStringAsFixed(0),
    );
    _sugarTargetController = TextEditingController(
      text:
          ((data['dailySugarTargetGram'] as num?)?.toDouble() ??
                  AppConstants.defaultSugarTargetGram)
              .toStringAsFixed(0),
    );
    _weeklyExerciseController = TextEditingController(
      text:
          ((data['weeklyExerciseTargetMinutes'] as num?)?.toDouble() ??
                  AppConstants.defaultWeeklyExerciseTargetMinutes)
              .toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _sugarTargetController.dispose();
    _weeklyExerciseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await widget.userDoc.set({
        'name': _nameController.text.trim(),
        'heightCm': parseLocalizedDouble(_heightController.text)!,
        'weightKg': parseLocalizedDouble(_weightController.text)!,
        'dailySugarTargetGram': parseLocalizedDouble(
          _sugarTargetController.text,
        )!,
        'weeklyExerciseTargetMinutes': parseLocalizedDouble(
          _weeklyExerciseController.text,
        )!,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit profil',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'Nama wajib diisi.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Tinggi (cm)',
                            prefixIcon: Icon(Icons.height),
                          ),
                          validator: _positiveNumberValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Berat (kg)',
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
                          validator: _positiveNumberValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sugarTargetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Target gula harian (gram)',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    validator: _positiveNumberValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weeklyExerciseController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Target olahraga mingguan (menit)',
                      prefixIcon: Icon(Icons.timeline_outlined),
                    ),
                    validator: _positiveNumberValidator,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Simpan profil'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _positiveNumberValidator(String? value) {
  final number = parseLocalizedDouble(value);
  if (number == null || number <= 0) return 'Masukkan angka valid.';
  return null;
}
