import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../domain/health_logic.dart';

class RiskScreen extends StatelessWidget {
  const RiskScreen({super.key, required this.user});

  final User user;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('riskAssessments');

  Future<void> _delete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus?'),
        content: const Text('Data ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
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
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Assessment'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('Belum ada data. Tekan + untuk tambah.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final score = data['score'] ?? 0;
              final level = data['level'] ?? '-';
              final bmi = (data['bmi'] as num?)?.toDouble() ?? 0;

              final color = switch (level) {
                'Sangat Tinggi' || 'Tinggi' => Colors.red,
                'Sedang' => Colors.orange,
                _ => Colors.green,
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
                            backgroundColor: color.withValues(alpha: 0.2),
                            child: Icon(Icons.health_and_safety, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Risiko $level',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Skor: $score — BMI: ${bmi.toStringAsFixed(1)}',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showForm(
                              context,
                              existingId: doc.id,
                              existingData: data,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _delete(context, doc.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(data['recommendation']?.toString() ?? ''),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('Usia: ${data['age']}')),
                          Chip(
                            label: Text(
                              'Minuman: ${data['sugaryDrinksPerDay']}x/hari (${data['drinkIntensity'] ?? '-'})',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Aktivitas: ${data['activityMinutesPerWeek']} mnt/mgg',
                            ),
                          ),
                          Chip(
                            label: Text(
                              data['familyHistory'] == true ? 'Riwayat keluarga' : 'Tanpa riwayat',
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

  void _showForm(BuildContext context, {String? existingId, Map<String, dynamic>? existingData}) {
    final ageCtrl = TextEditingController(text: '${existingData?['age'] ?? 20}');
    final heightCtrl = TextEditingController(text: '${existingData?['heightCm'] ?? 170}');
    final weightCtrl = TextEditingController(text: '${existingData?['weightKg'] ?? 65}');
    final drinkCtrl = TextEditingController(text: '${existingData?['sugaryDrinksPerDay'] ?? 1}');
    final activityCtrl = TextEditingController(text: '${existingData?['activityMinutesPerWeek'] ?? 120}');
    var familyHistory = existingData?['familyHistory'] == true;
    var drinkIntensity = existingData?['drinkIntensity'] ?? 'ringan';
    var isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    existingId == null ? 'Tambah Assessment' : 'Edit Assessment',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Usia'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Tinggi (cm)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Berat (kg)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: drinkCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minuman manis per hari'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: drinkIntensity,
                    decoration: const InputDecoration(labelText: 'Tingkat kemanisan'),
                    items: [
                      DropdownMenuItem(
                        value: 'ringan',
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(color: Colors.black),
                            children: [
                              TextSpan(text: 'Ringan '),
                              TextSpan(
                                text: 'contoh: (teh manis, susu kotak)',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'sedang',
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(color: Colors.black),
                            children: [
                              TextSpan(text: 'Sedang '),
                              TextSpan(
                                text: 'contoh: (soda, Thai tea)',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'berat',
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(color: Colors.black),
                            children: [
                              TextSpan(text: 'Berat '),
                              TextSpan(
                                text: 'contoh: (boba, kopi susu)',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => drinkIntensity = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: activityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Aktivitas (menit/minggu)'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: familyHistory,
                    title: const Text('Riwayat diabetes keluarga'),
                    onChanged: (v) => setModalState(() => familyHistory = v),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                      setModalState(() => isSaving = true);

                      final age = int.tryParse(ageCtrl.text) ?? 20;
                      final height = double.tryParse(heightCtrl.text) ?? 170;
                      final weight = double.tryParse(weightCtrl.text) ?? 65;
                      final drinks = int.tryParse(drinkCtrl.text) ?? 1;
                      final activity = int.tryParse(activityCtrl.text) ?? 120;

                      final result = calculateRisk(
                        age: age,
                        heightCm: height,
                        weightKg: weight,
                        sugaryDrinksPerDay: drinks,
                        drinkIntensity: drinkIntensity,
                        activityMinutesPerWeek: activity,
                        familyHistory: familyHistory,
                      );

                      final payload = {
                        'age': age,
                        'heightCm': height,
                        'weightKg': weight,
                        'sugaryDrinksPerDay': drinks,
                        'drinkIntensity': drinkIntensity,
                        'activityMinutesPerWeek': activity,
                        'familyHistory': familyHistory,
                        'bmi': result.bmi,
                        'score': result.score,
                        'level': result.level,
                        'recommendation': result.recommendation,
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      if (existingId == null) {
                        await _collection.add({
                          ...payload,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      } else {
                        await _collection.doc(existingId).update(payload);
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(existingId == null ? 'Simpan' : 'Update'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}