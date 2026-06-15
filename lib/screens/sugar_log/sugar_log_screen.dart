import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_constants.dart';
import '../../domain/health_logic.dart';
import '../../services/notification_service.dart';
import '../../services/nutrition_lookup_service.dart';

class SugarLogScreen extends StatelessWidget {
  const SugarLogScreen({super.key, required this.user});

  final User user;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  CollectionReference<Map<String, dynamic>> get _logs =>
      _userDoc.collection('sugarLogs');

  @override
  Widget build(BuildContext context) {
    final today = dayKey(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Log Gula')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'barcode',
            onPressed: () => _startBarcodeLookup(context),
            icon: const Icon(Icons.search),
            label: const Text('Barcode'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'manual',
            onPressed: () => _showLogForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Manual'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _logs.orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          final todayTotal = totalSugarForDay(
            docs.map((doc) => doc.data()),
            today,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 136),
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _userDoc.snapshots(),
                builder: (context, profileSnapshot) {
                  final target =
                      (profileSnapshot.data?.data()?['dailySugarTargetGram']
                              as num?)
                          ?.toDouble() ??
                      AppConstants.defaultSugarTargetGram;
                  return _DailySugarCard(total: todayTotal, target: target);
                },
              ),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const _EmptySugarState()
              else
                for (final doc in docs) ...[
                  _SugarLogTile(
                    data: doc.data(),
                    onEdit: () => _showLogForm(
                      context,
                      existingId: doc.id,
                      existingData: doc.data(),
                    ),
                    onDelete: () => _deleteLog(context, doc.id),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _startBarcodeLookup(BuildContext context) async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) => _BarcodeDialog(),
    );
    if (barcode == null || barcode.trim().isEmpty || !context.mounted) return;
    if (!isValidNutritionBarcode(barcode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode harus 8-14 digit angka.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final product = await NutritionLookupService().fetchProduct(barcode);
      if (!context.mounted) return;
      if (product == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Produk tidak ditemukan.')),
        );
        return;
      }
      await _showLogForm(context, product: product);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showLogForm(
    BuildContext context, {
    String? existingId,
    Map<String, dynamic>? existingData,
    NutritionProduct? product,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SugarLogFormSheet(
        userDoc: _userDoc,
        logs: _logs,
        existingId: existingId,
        existingData: existingData,
        product: product,
      ),
    );
  }

  Future<void> _deleteLog(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus log gula?'),
        content: const Text('Data konsumsi ini akan dihapus dari Firestore.'),
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
      await _logs.doc(id).delete();
      await recalculateActiveChallenges(_userDoc);
    }
  }
}

class _DailySugarCard extends StatelessWidget {
  const _DailySugarCard({required this.total, required this.target});

  final double total;
  final double target;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : (total / target).clamp(0.0, 1.0);
    final overTarget = total > target;
    final color = overTarget
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: color),
                const SizedBox(width: 8),
                Text(
                  'Ringkasan hari ini',
                  style: Theme.of(context).textTheme.titleMedium,
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
            const SizedBox(height: 12),
            Text(
              '${total.toStringAsFixed(1)}g dari target ${target.toStringAsFixed(0)}g',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              overTarget
                  ? 'Target terlewati. Kurangi tambahan gula berikutnya.'
                  : 'Masih dalam target edukasi harian.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SugarLogTile extends StatelessWidget {
  const _SugarLogTile({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final sugar = (data['sugarGram'] as num?)?.toDouble() ?? 0;
    final confidence = (data['nutritionConfidence'] as num?)?.toDouble();
    final needsReview = data['needsNutritionReview'] == true;
    final manualAdjusted = data['manualAdjusted'] == true;
    final source = _nutritionSourceLabel(
      data['nutritionSource']?.toString() ?? data['source']?.toString(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.local_cafe_outlined)),
          title: Text(data['productName']?.toString() ?? 'Produk'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${DateFormat('d MMM yyyy').format(date)} - $source'),
              if (confidence != null)
                Text('Confidence ${(confidence * 100).round()}%'),
              if (needsReview || manualAdjusted)
                Wrap(
                  spacing: 6,
                  children: [
                    if (needsReview)
                      const Chip(
                        label: Text('Perlu cek'),
                        avatar: Icon(Icons.warning_amber, size: 18),
                      ),
                    if (manualAdjusted)
                      const Chip(
                        label: Text('Manual'),
                        avatar: Icon(Icons.edit_note, size: 18),
                      ),
                  ],
                ),
            ],
          ),
          trailing: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${sugar.toStringAsFixed(1)}g',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySugarState extends StatelessWidget {
  const _EmptySugarState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada log gula',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tambah manual atau cari produk dari barcode.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BarcodeDialog extends StatelessWidget {
  _BarcodeDialog();

  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cari barcode'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Barcode produk',
          prefixIcon: Icon(Icons.qr_code_scanner),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _controller.text),
          icon: const Icon(Icons.search),
          label: const Text('Cari'),
        ),
      ],
    );
  }
}

class _SugarLogFormSheet extends StatefulWidget {
  const _SugarLogFormSheet({
    required this.userDoc,
    required this.logs,
    this.existingId,
    this.existingData,
    this.product,
  });

  final DocumentReference<Map<String, dynamic>> userDoc;
  final CollectionReference<Map<String, dynamic>> logs;
  final String? existingId;
  final Map<String, dynamic>? existingData;
  final NutritionProduct? product;

  @override
  State<_SugarLogFormSheet> createState() => _SugarLogFormSheetState();
}

class _SugarLogFormSheetState extends State<_SugarLogFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _productController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _sugarController;
  late final TextEditingController _servingController;
  late DateTime _date;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData ?? {};
    final product = widget.product;
    _productController = TextEditingController(
      text: data['productName']?.toString() ?? product?.name ?? '',
    );
    _barcodeController = TextEditingController(
      text: data['barcode']?.toString() ?? product?.barcode ?? '',
    );
    _sugarController = TextEditingController(
      text:
          data['sugarGram']?.toString() ??
          product?.suggestedSugarGram?.toStringAsFixed(1) ??
          '',
    );
    _servingController = TextEditingController(
      text: data['serving']?.toString() ?? '1 porsi',
    );
    final existingDate = (data['date'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    _date = existingDate == null || existingDate.isAfter(now)
        ? now
        : existingDate;
  }

  @override
  void dispose() {
    _productController.dispose();
    _barcodeController.dispose();
    _sugarController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final sugar = _parseLocalizedDouble(_sugarController.text)!;
      final suggestedSugar = widget.product?.suggestedSugarGram;
      final previousManualAdjusted =
          widget.existingData?['manualAdjusted'] == true;
      final manualAdjusted = widget.product == null
          ? previousManualAdjusted
          : _isManualAdjustment(sugar, suggestedSugar);

      final payload = {
        'date': Timestamp.fromDate(_date),
        'dayKey': dayKey(_date),
        'productName': _productController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'sugarGram': sugar,
        'serving': _servingController.text.trim(),
        'source': widget.product == null
            ? (widget.existingData?['source']?.toString() ?? 'manual')
            : 'barcode',
        'nutritionSource':
            widget.product?.source ??
            widget.existingData?['nutritionSource']?.toString() ??
            widget.existingData?['source']?.toString() ??
            'manual',
        'nutritionConfidence':
            widget.product?.confidence ??
            (widget.existingData?['nutritionConfidence'] as num?)?.toDouble(),
        'needsNutritionReview':
            widget.product?.needsReview ??
            (widget.existingData?['needsNutritionReview'] == true),
        'manualAdjusted': manualAdjusted,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.existingId == null) {
        await widget.logs.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await widget.logs.doc(widget.existingId).update(payload);
      }

      await recalculateActiveChallenges(widget.userDoc);
      await _maybeShowWarning();

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

  bool _isManualAdjustment(double sugar, double? suggestedSugar) {
    return suggestedSugar != null && (sugar - suggestedSugar).abs() > 0.05;
  }

  Future<void> _maybeShowWarning() async {
    final profile = (await widget.userDoc.get()).data() ?? {};
    final target =
        (profile['dailySugarTargetGram'] as num?)?.toDouble() ??
        AppConstants.defaultSugarTargetGram;
    final query = await widget.logs
        .where('dayKey', isEqualTo: dayKey(_date))
        .get();
    final total = totalSugarForDay(
      query.docs.map((doc) => doc.data()),
      dayKey(_date),
    );
    if (total > target) {
      await NotificationService.instance.showSugarWarning(
        totalGram: total,
        targetGram: target,
      );
    }
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
                widget.existingId == null ? 'Tambah log gula' : 'Edit log gula',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.product != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${widget.product!.sourceLabel}: ${widget.product!.brand}',
                ),
                Text(
                  'Confidence ${(widget.product!.confidence * 100).round()}%',
                ),
                if (widget.product!.needsReview)
                  Text(
                    'Data antar-sumber perlu dicek ulang sebelum disimpan.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _productController,
                decoration: const InputDecoration(
                  labelText: 'Nama produk/makanan',
                  prefixIcon: Icon(Icons.fastfood_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Wajib diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sugarController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Gula (gram)',
                        prefixIcon: Icon(Icons.scale_outlined),
                      ),
                      validator: _positiveNumberValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _servingController,
                      decoration: const InputDecoration(
                        labelText: 'Serving',
                        prefixIcon: Icon(Icons.flatware),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Wajib diisi.'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Barcode (opsional)',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(DateFormat('d MMM yyyy').format(_date)),
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

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _date = selected);
  }
}

Future<void> recalculateActiveChallenges(
  DocumentReference<Map<String, dynamic>> userDoc,
) async {
  final logsSnapshot = await userDoc.collection('sugarLogs').get();
  final totalsByDay = <String, double>{};
  final daysWithLogs = <String>{};
  for (final doc in logsSnapshot.docs) {
    final data = doc.data();
    final key = data['dayKey']?.toString();
    final sugar = (data['sugarGram'] as num?)?.toDouble() ?? 0;
    if (key == null || key.isEmpty) continue;
    daysWithLogs.add(key);
    totalsByDay[key] = (totalsByDay[key] ?? 0) + sugar;
  }

  final challenges = await userDoc
      .collection('challenges')
      .where('status', isEqualTo: 'active')
      .get();
  for (final doc in challenges.docs) {
    final data = doc.data();
    final startDate =
        (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final durationDays = (data['durationDays'] as num?)?.toInt() ?? 7;
    final target =
        (data['dailyTargetGram'] as num?)?.toDouble() ??
        AppConstants.defaultSugarTargetGram;
    final progress = recalculateChallengeProgress(
      startDate: startDate,
      durationDays: durationDays,
      dailyTargetGram: target,
      totalsByDay: totalsByDay,
      daysWithLogs: daysWithLogs,
    );
    await doc.reference.update({
      'creditedDates': progress.creditedDates,
      'failedDates': progress.failedDates,
      'progressDays': progress.progressDays,
      'status': progress.isCompleted ? 'completed' : 'active',
      if (progress.isCompleted) 'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

String? _positiveNumberValidator(String? value) {
  final number = _parseLocalizedDouble(value);
  if (number == null || number <= 0) return 'Masukkan angka valid.';
  return null;
}

double? _parseLocalizedDouble(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return double.tryParse(text.replaceAll(',', '.'));
}

String _nutritionSourceLabel(String? source) {
  return (source ?? 'manual')
      .split('+')
      .map(
        (item) => switch (item) {
          'c0r' => 'c0r.ai',
          'calorie_api' => 'CalorieAPI',
          'usda_fdc' => 'USDA FDC',
          'edamam' => 'Edamam',
          'open_food_facts' => 'Open Food Facts',
          'open_food_facts_client' => 'Open Food Facts',
          'barcode' => 'Barcode',
          'manual' => 'Manual',
          _ => item,
        },
      )
      .join(' + ');
}
