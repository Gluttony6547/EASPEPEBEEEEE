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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalkulator Risiko')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
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
              child: Text('Belum ada data.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return Card(
                child: ListTile(
                  title: Text('Risiko ${data['level'] ?? '-'}'),
                  subtitle: Text('Skor: ${data['score'] ?? 0}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showForm(context, existingId: doc.id, existingData: data);
                      } else if (value == 'delete') {
                        _collection.doc(doc.id).delete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Hapus')),
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
                  TextField(
                    controller: heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tinggi (cm)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Berat (kg)'),
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
                    items: const [
                      DropdownMenuItem(
                        value: 'ringan',
                        child: Text('Ringan\nseperti: Yogurt plain, Susu tawar, Teh tawar'),
                      ),
                      DropdownMenuItem(
                        value: 'sedang',
                        child: Text('Sedang\nseperti: Teh manis, Jus buah, Susu cokelat'),
                      ),
                      DropdownMenuItem(
                        value: 'berat',
                        child: Text('Berat\nseperti: Boba, Milkshake, Thai tea'),
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