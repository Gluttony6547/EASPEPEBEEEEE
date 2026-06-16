import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_constants.dart';
import '../domain/health_logic.dart';
import 'sugar_log_screen.dart';

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
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Challenge belum bisa dimuat. Cek koneksi atau rules Firestore.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
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
                onActivityUpdate: () => _showActivityForm(context, doc.data()),
                onEdit: () => _showChallengeForm(
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

  Future<void> _showActivityForm(
    BuildContext context,
    Map<String, dynamic> challengeData,
  ) {
    return showActivityLogSheet(
      context,
      userDoc: _userDoc,
      initialActivityMode: normalizeActivityMode(challengeData['activityMode']),
      initialDistanceKm:
          (challengeData['dailyDistanceTargetKm'] as num?)?.toDouble() ?? 0,
      title: 'Update aktivitas hari ini',
      helperText:
          '${activityModeLabel(challengeData['activityMode']?.toString() ?? walkingMode)} untuk menjaga streak olahraga tetap hidup.',
      source: 'challenge',
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
      backgroundColor: Colors.transparent,
      builder: (context) => _ChallengeFormSheet(
        userDoc: _userDoc,
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
      builder: (context) => AlertDialog(
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
    required this.onActivityUpdate,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onActivityUpdate;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'active';
    final challengeType = normalizeChallengeType(data['challengeType']);
    final duration = (data['durationDays'] as num?)?.toInt() ?? 7;
    final progress = (data['progressDays'] as num?)?.toInt() ?? 0;
    final target =
        (data['dailyTargetGram'] as num?)?.toDouble() ??
        AppConstants.defaultSugarTargetGram;
    final distanceTarget =
        (data['dailyDistanceTargetKm'] as num?)?.toDouble() ?? 0;
    final mode = normalizeActivityMode(data['activityMode']);
    final calories =
        (data['estimatedCaloriesBurnedTotal'] as num?)?.toDouble() ?? 0;
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final ratio = duration <= 0 ? 0.0 : (progress / duration).clamp(0.0, 1.0);
    final color = switch (status) {
      'completed' => Theme.of(context).colorScheme.primary,
      'cancelled' => Theme.of(context).disabledColor,
      'expired' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.tertiary,
    };
    final isActivityChallenge = challengeType == activityChallengeType;
    final subtitle = isActivityChallenge
        ? 'Status $status - ${activityModeLabel(mode)} ${distanceTarget.toStringAsFixed(1)} km/hari'
        : 'Status $status - target gula ${target.toStringAsFixed(0)}g/hari';
    final detail = isActivityChallenge
        ? 'Estimasi terbakar ${calories.toStringAsFixed(0)} kkal dari log olahraga.'
        : 'Progress dihitung dari total Log Gula harian.';

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
                  child: Icon(
                    isActivityChallenge
                        ? Icons.directions_run
                        : Icons.restaurant_menu,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title']?.toString() ?? 'Challenge',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                  itemBuilder: (context) => [
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
            const SizedBox(height: 8),
            Text(detail),
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
                if (((data['missedDates'] as List?)?.length ?? 0) > 0)
                  Chip(
                    avatar: const Icon(Icons.timer_off_outlined, size: 18),
                    label: Text(
                      'Tanpa update ${(data['missedDates'] as List?)?.length ?? 0} hari',
                    ),
                  ),
              ],
            ),
            if (status == 'active' && isActivityChallenge) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onActivityUpdate,
                icon: const Icon(Icons.directions_walk),
                label: const Text('Update aktivitas hari ini'),
              ),
            ],
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
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
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
                  'Buat challenge gula atau olahraga agar progress otomatis tercatat.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeFormSheet extends StatefulWidget {
  const _ChallengeFormSheet({
    required this.userDoc,
    required this.collection,
    this.existingId,
    this.existingData,
  });

  final DocumentReference<Map<String, dynamic>> userDoc;
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
  late final TextEditingController _distanceController;
  late final TextEditingController _durationController;
  late String _challengeType;
  late String _activityMode;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData ?? {};
    _challengeType = normalizeChallengeType(data['challengeType']);
    _titleController = TextEditingController(
      text:
          data['title']?.toString() ??
          (_challengeType == activityChallengeType
              ? '7 Hari Konsisten Jalan/Lari'
              : '7 Hari Gula Terkontrol'),
    );
    _targetController = TextEditingController(
      text:
          (data['dailyTargetGram'] as num?)?.toDouble().toStringAsFixed(0) ??
          AppConstants.defaultSugarTargetGram.toStringAsFixed(0),
    );
    _distanceController = TextEditingController(
      text:
          (data['dailyDistanceTargetKm'] as num?)?.toDouble().toStringAsFixed(
            1,
          ) ??
          '2.0',
    );
    _durationController = TextEditingController(
      text: (data['durationDays'] as num?)?.toInt().toString() ?? '7',
    );
    _activityMode = normalizeActivityMode(data['activityMode']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final durationDays = parseLocalizedInt(_durationController.text)!;
      final payload = <String, Object?>{
        'title': _titleController.text.trim(),
        'challengeType': _challengeType,
        'durationDays': durationDays,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_challengeType == activityChallengeType) {
        payload.addAll({
          'dailyDistanceTargetKm': parseLocalizedDouble(
            _distanceController.text,
          )!,
          'activityMode': _activityMode,
        });
      } else {
        payload.addAll({
          'dailyTargetGram': parseLocalizedDouble(_targetController.text)!,
        });
      }

      if (widget.existingId == null) {
        await widget.collection.add({
          ...payload,
          'status': 'active',
          'startDate': Timestamp.fromDate(DateTime.now()),
          'creditedDates': <String>[],
          'failedDates': <String>[],
          'missedDates': <String>[],
          'progressDays': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await widget.collection.doc(widget.existingId).update(payload);
      }

      await recalculateActiveChallenges(widget.userDoc);

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
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Wajib diisi.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: sugarChallengeType,
                        icon: Icon(Icons.restaurant_menu),
                        label: Text('Target gula'),
                      ),
                      ButtonSegment(
                        value: activityChallengeType,
                        icon: Icon(Icons.directions_run),
                        label: Text('Lari/jalan'),
                      ),
                    ],
                    selected: {_challengeType},
                    onSelectionChanged: (selection) =>
                        setState(() => _challengeType = selection.first),
                  ),
                  const SizedBox(height: 12),
                  if (_challengeType == sugarChallengeType)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _targetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
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
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _activityMode,
                      decoration: const InputDecoration(
                        labelText: 'Mode aktivitas',
                        prefixIcon: Icon(Icons.directions_run),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: walkingMode,
                          child: Text('Jalan kaki'),
                        ),
                        DropdownMenuItem(
                          value: runningMode,
                          child: Text('Lari'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _activityMode = normalizeActivityMode(value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _distanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Jarak/hari (km)',
                              prefixIcon: Icon(Icons.route_outlined),
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
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
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

String? _positiveIntValidator(String? value) {
  final number = parseLocalizedInt(value);
  if (number == null || number <= 0) return 'Masukkan angka valid.';
  return null;
}
