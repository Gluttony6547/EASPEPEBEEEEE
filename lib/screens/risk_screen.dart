import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/health_logic.dart';

class RiskScreen extends StatelessWidget {
  const RiskScreen({super.key, required this.user});

  final User user;

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore
      .instance
      .collection('users')
      .doc(user.uid)
      .collection('riskAssessments');

  Future<void> _delete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus assessment?'),
        content: const Text('Data risiko ini akan dihapus dari Firestore.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _collection.doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalkulator Risiko')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRiskForm(context, collection: _collection),
        icon: const Icon(Icons.add),
        label: const Text('Assessment'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyRiskState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final score = data['score'] ?? 0;
              final level = data['level'] ?? '-';
              final bmi = (data['bmi'] as num?)?.toDouble() ?? 0;
              final color = switch (level) {
                'Tinggi' => Theme.of(context).colorScheme.error,
                'Sedang' => Theme.of(context).colorScheme.tertiary,
                _ => Theme.of(context).colorScheme.primary,
              };

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.14),
                            foregroundColor: color,
                            child: const Icon(Icons.health_and_safety),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Risiko $level',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Skor $score - BMI ${bmi.toStringAsFixed(1)}',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => showRiskForm(
                              context,
                              collection: _collection,
                              existingId: doc.id,
                              existingData: data,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            onPressed: () => _delete(context, doc.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(data['recommendation']?.toString() ?? ''),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Usia ${data['age']}')),
                          Chip(
                            label: Text(
                              'Minuman manis ${data['sugaryDrinksPerDay']}/hari',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Aktivitas ${data['activityMinutesPerWeek']} mnt/minggu',
                            ),
                          ),
                          Chip(
                            label: Text(
                              data['familyHistory'] == true
                                  ? 'Riwayat keluarga'
                                  : 'Tanpa riwayat keluarga',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyRiskState extends StatelessWidget {
  const _EmptyRiskState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada assessment risiko',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol Assessment untuk membuat data CRUD pertama.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showRiskForm(
  BuildContext context, {
  required CollectionReference<Map<String, dynamic>> collection,
  String? existingId,
  Map<String, dynamic>? existingData,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RiskFormSheet(
      collection: collection,
      existingId: existingId,
      existingData: existingData,
    ),
  );
}

class _RiskFormSheet extends StatefulWidget {
  const _RiskFormSheet({
    required this.collection,
    this.existingId,
    this.existingData,
  });

  final CollectionReference<Map<String, dynamic>> collection;
  final String? existingId;
  final Map<String, dynamic>? existingData;

  @override
  State<_RiskFormSheet> createState() => _RiskFormSheetState();
}

class _RiskFormSheetState extends State<_RiskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _drinkController;
  late final TextEditingController _activityController;
  late bool _familyHistory;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData ?? {};
    _ageController = TextEditingController(text: '${data['age'] ?? 20}');
    _heightController = TextEditingController(
      text: '${data['heightCm'] ?? 170}',
    );
    _weightController = TextEditingController(
      text: '${data['weightKg'] ?? 65}',
    );
    _drinkController = TextEditingController(
      text: '${data['sugaryDrinksPerDay'] ?? 1}',
    );
    _activityController = TextEditingController(
      text: '${data['activityMinutesPerWeek'] ?? 120}',
    );
    _familyHistory = data['familyHistory'] == true;
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _drinkController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final age = int.parse(_ageController.text);
    final height = double.parse(_heightController.text);
    final weight = double.parse(_weightController.text);
    final drinks = int.parse(_drinkController.text);
    final activity = int.parse(_activityController.text);
    final result = calculateRisk(
      age: age,
      heightCm: height,
      weightKg: weight,
      sugaryDrinksPerDay: drinks,
      activityMinutesPerWeek: activity,
      familyHistory: _familyHistory,
    );

    final payload = {
      'age': age,
      'heightCm': height,
      'weightKg': weight,
      'sugaryDrinksPerDay': drinks,
      'activityMinutesPerWeek': activity,
      'familyHistory': _familyHistory,
      'bmi': result.bmi,
      'score': result.score,
      'level': result.level,
      'recommendation': result.recommendation,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.existingId == null) {
      await widget.collection.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await widget.collection.doc(widget.existingId).update(payload);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existingId == null
                    ? 'Tambah assessment'
                    : 'Edit assessment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Usia',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      validator: _positiveIntValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _drinkController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minuman manis/hari',
                        prefixIcon: Icon(Icons.local_drink_outlined),
                      ),
                      validator: _zeroOrPositiveIntValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
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
                      keyboardType: TextInputType.number,
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
                controller: _activityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aktivitas fisik (menit/minggu)',
                  prefixIcon: Icon(Icons.directions_run),
                ),
                validator: _zeroOrPositiveIntValidator,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _familyHistory,
                contentPadding: EdgeInsets.zero,
                title: const Text('Ada riwayat diabetes keluarga'),
                secondary: const Icon(Icons.family_restroom),
                onChanged: (value) => setState(() => _familyHistory = value),
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
                label: Text(widget.existingId == null ? 'Simpan' : 'Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _positiveNumberValidator(String? value) {
  final number = double.tryParse(value ?? '');
  if (number == null || number <= 0) return 'Masukkan angka valid.';
  return null;
}

String? _positiveIntValidator(String? value) {
  final number = int.tryParse(value ?? '');
  if (number == null || number <= 0) return 'Masukkan angka valid.';
  return null;
}

String? _zeroOrPositiveIntValidator(String? value) {
  final number = int.tryParse(value ?? '');
  if (number == null || number < 0) return 'Masukkan angka valid.';
  return null;
}
