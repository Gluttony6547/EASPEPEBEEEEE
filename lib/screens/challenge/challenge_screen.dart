import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';

import '../../app_constants.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key, required this.user});

  final User user;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _userDoc.collection('challenges');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tantangan Streak'),
        actions: [
          IconButton(
            tooltip: 'Recalculate',
            onPressed: () async {
              await recalculateActiveChallenges(_userDoc);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Progress challenge dihitung ulang.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showChallengeForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Challenge'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];

          // Schedule/cancel reminder berdasarkan ada tidaknya challenge aktif
          final activeDocs =
              docs.where((d) => d.data()['status'] == 'active').toList();
          if (activeDocs.isNotEmpty) {
            final activeTitle =
                activeDocs.first.data()['title']?.toString() ?? 'Challenge';
            NotificationService.instance.scheduleEveningReminder(activeTitle);
          } else {
            NotificationService.instance.cancelEveningReminder();
          }

          if (docs.isEmpty) return const _EmptyChallengeState();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _ChallengeCard(
                id: doc.id,
                data: doc.data(),
                onEdit:
                    () => _showChallengeForm(
                      context,
                      existingId: doc.id,
                      existingData: doc.data(),
                    ),
                onCancel: () => _cancelChallenge(context, doc.id),
                onDelete: () => _deleteChallenge(context, doc.id, doc.data()),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showChallengeForm(
    BuildContext context, {
    String? existingId,
    Map<String, dynamic>? existingData,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _ChallengeFormSheet(
            collection: _collection,
            existingId: existingId,
            existingData: existingData,
          ),
    );
  }

  Future<void> _cancelChallenge(BuildContext context, String id) async {
    await _collection.doc(id).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteChallenge(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (data['status'] == 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancel challenge aktif sebelum delete.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus challenge?'),
            content: const Text(
              'Challenge nonaktif ini akan dihapus dari Firestore.',
            ),
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
    if (confirmed == true) await _collection.doc(id).delete();
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'active';
    final duration = (data['durationDays'] as num?)?.toInt() ?? 7;
    final progress = (data['progressDays'] as num?)?.toInt() ?? 0;
    final target =
        (data['dailyTargetGram'] as num?)?.toDouble() ??
        AppConstants.defaultSugarTargetGram;
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final ratio = duration <= 0 ? 0.0 : (progress / duration).clamp(0.0, 1.0);
    final color = switch (status) {
      'completed' => Theme.of(context).colorScheme.primary,
      'cancelled' => Theme.of(context).disabledColor,
      _ => Theme.of(context).colorScheme.tertiary,
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
                  child: const Icon(Icons.emoji_events),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title']?.toString() ?? 'Challenge',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Status $status - target ${target.toStringAsFixed(0)}g/hari',
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'cancel') onCancel();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder:
                      (context) => [
                        if (status == 'active')
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'),
                            ),
                          ),
                        if (status == 'active')
                          const PopupMenuItem(
                            value: 'cancel',
                            child: ListTile(
                              leading: Icon(Icons.cancel_outlined),
                              title: Text('Cancel'),
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete'),
                          ),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: ratio,
              color: color,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Text('$progress dari $duration hari berhasil'),
            if (start != null) ...[
              const SizedBox(height: 4),
              Text('Mulai ${DateFormat('d MMM yyyy').format(start)}'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    'Berhasil ${(data['creditedDates'] as List?)?.length ?? 0} hari',
                  ),
                ),
                Chip(
                  label: Text(
                    'Gagal ${(data['failedDates'] as List?)?.length ?? 0} hari',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChallengeState extends StatelessWidget {
  const _EmptyChallengeState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada challenge',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Buat challenge 7 hari agar progress otomatis dihitung dari Log Gula.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeFormSheet extends StatefulWidget {
  const _ChallengeFormSheet({
    required this.collection,
    this.existingId,
    this.existingData,
  });

  final CollectionReference<Map<String, dynamic>> collection;
  final String? existingId;
  final Map<String, dynamic>? existingData;

  @override
  State<_ChallengeFormSheet> createState() => _ChallengeFormSheetState();
}

class _ChallengeFormSheetState extends State<_ChallengeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late final TextEditingController _durationController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData ?? {};
    _titleController = TextEditingController(
      text: data['title']?.toString() ?? '7 Hari Kurangi Minuman Manis',
    );
    _targetController = TextEditingController(
      text:
          (data['dailyTargetGram'] as num?)?.toDouble().toStringAsFixed(0) ??
          AppConstants.defaultSugarTargetGram.toStringAsFixed(0),
    );
    _durationController = TextEditingController(
      text: (data['durationDays'] as num?)?.toInt().toString() ?? '7',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final payload = {
      'title': _titleController.text.trim(),
      'dailyTargetGram': double.parse(_targetController.text),
      'durationDays': int.parse(_durationController.text),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.existingId == null) {
      await widget.collection.add({
        ...payload,
        'status': 'active',
        'startDate': Timestamp.fromDate(DateTime.now()),
        'creditedDates': <String>[],
        'failedDates': <String>[],
        'progressDays': 0,
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
                    ? 'Tambah challenge'
                    : 'Edit challenge',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul challenge',
                  prefixIcon: Icon(Icons.emoji_events_outlined),
                ),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Wajib diisi.'
                            : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Target gram/hari',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      validator: _positiveNumberValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durasi hari',
                        prefixIcon: Icon(Icons.calendar_view_week),
                      ),
                      validator: _positiveIntValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon:
                    _isSaving
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save),
                label: Text(widget.existingId == null ? 'Mulai' : 'Update'),
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

/// Recalculate semua challenge aktif berdasarkan log gula harian.
/// Dipanggil manual via tombol refresh atau otomatis setiap kali
/// sugar log berubah.
Future<void> recalculateActiveChallenges(
  DocumentReference<Map<String, dynamic>> userDoc,
) async {
  final challengeCol = userDoc.collection('challenges');
  final logCol = userDoc.collection('sugarLogs');

  // Ambil semua challenge aktif
  final activeChallenges =
      await challengeCol.where('status', isEqualTo: 'active').get();

  for (final doc in activeChallenges.docs) {
    final data = doc.data();
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final targetGram =
        (data['dailyTargetGram'] as num?)?.toDouble() ??
        AppConstants.defaultSugarTargetGram;
    final durationDays = (data['durationDays'] as num?)?.toInt() ?? 7;

    if (startDate == null) continue;

    // Ambil semua log sejak startDate
    final logsSnap =
        await logCol
            .where(
              'loggedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .get();

    // Kelompokkan log per hari (format: yyyy-MM-dd)
    final Map<String, double> sugarPerDay = {};
    for (final log in logsSnap.docs) {
      final logData = log.data();
      final loggedAt = (logData['loggedAt'] as Timestamp?)?.toDate();
      if (loggedAt == null) continue;
      final dayKey = DateFormat('yyyy-MM-dd').format(loggedAt);
      final sugar = (logData['sugarGram'] as num?)?.toDouble() ?? 0.0;
      sugarPerDay[dayKey] = (sugarPerDay[dayKey] ?? 0.0) + sugar;
    }

    // Tentukan hari berhasil dan gagal
    final now = DateTime.now();
    final List<String> credited = [];
    final List<String> failed = [];

    for (int i = 0; i < durationDays; i++) {
      final day = startDate.add(Duration(days: i));
      if (day.isAfter(now)) break; // belum sampai hari ini
      final dayKey = DateFormat('yyyy-MM-dd').format(day);
      final totalSugar = sugarPerDay[dayKey] ?? -1;

      if (totalSugar < 0) continue; // belum ada log hari itu, skip
      if (totalSugar <= targetGram) {
        credited.add(dayKey);
      } else {
        failed.add(dayKey);
      }
    }

    final newStatus = credited.length >= durationDays ? 'completed' : 'active';

    // Ambil progressDays sebelumnya untuk deteksi perubahan
    final prevProgress = (data['progressDays'] as num?)?.toInt() ?? 0;
    final prevStatus = data['status']?.toString() ?? 'active';

    await doc.reference.update({
      'creditedDates': credited,
      'failedDates': failed,
      'progressDays': credited.length,
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      if (newStatus == 'completed') 'completedAt': FieldValue.serverTimestamp(),
    });

    final title = data['title']?.toString() ?? 'Challenge';

    // Notif: challenge baru saja selesai
    if (newStatus == 'completed' && prevStatus != 'completed') {
      await NotificationService.instance.showChallengeCompleted(title);
    }
    // Notif: streak bertambah hari ini
    else if (credited.length > prevProgress) {
      await NotificationService.instance.showChallengeStreakSuccess(
        title,
        credited.length,
        durationDays,
      );
    }
  }
}
