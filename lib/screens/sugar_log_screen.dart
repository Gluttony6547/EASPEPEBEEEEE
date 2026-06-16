import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_constants.dart';
import '../domain/health_logic.dart';
import '../services/notification_service.dart';
import '../services/nutrition_lookup_service.dart';

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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _logs.orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _InlineErrorCard(
              message:
                  'Log gula belum bisa dimuat. Cek koneksi atau rules Firestore.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          final todayTotal = totalSugarForDay(
            docs.map((doc) => doc.data()),
            today,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
              const SizedBox(height: 12),
              _LogQuickActions(
                onBarcode: () => _startBarcodeLookup(context),
                onActivity: () => showActivityLogSheet(
                  context,
                  userDoc: _userDoc,
                  title: 'Log olahraga',
                  helperText:
                      'Jalan kaki atau lari dari halaman ini masuk ke target olahraga.',
                  source: 'log_gula',
                ),
                onManual: () => _showLogForm(context),
              ),
              const SizedBox(height: 16),
              _ActivityHistorySection(userDoc: _userDoc),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const _EmptySugarState()
              else
                _SugarHistorySection(
                  docs: docs,
                  onEdit: (doc) => _showLogForm(
                    context,
                    existingId: doc.id,
                    existingData: doc.data(),
                  ),
                  onDelete: (doc) => _deleteLog(context, doc.id),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startBarcodeLookup(BuildContext context) async {
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _BarcodeScannerSheet(),
    );
    if (barcode == null || barcode.trim().isEmpty || !context.mounted) return;
    if (!isValidNutritionBarcode(barcode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode harus 8-14 digit angka.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    _showBarcodeLookupDialog(context);
    try {
      final product = await NutritionLookupService().fetchProduct(barcode);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (product == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Produk tidak ditemukan.')),
        );
        return;
      }
      await _showLogForm(context, product: product);
    } catch (error) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
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
      backgroundColor: Colors.transparent,
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

void _showBarcodeLookupDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('Mencari data barcode...')),
        ],
      ),
    ),
  );
}

Future<void> showActivityLogSheet(
  BuildContext context, {
  required DocumentReference<Map<String, dynamic>> userDoc,
  String initialActivityMode = walkingMode,
  double? initialDistanceKm,
  int? initialSteps,
  double? initialDurationMinutes,
  DateTime? initialDate,
  String title = 'Log olahraga',
  String? helperText,
  String source = 'manual',
  String? replaceActivityLogId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ActivityLogFormSheet(
      userDoc: userDoc,
      initialActivityMode: initialActivityMode,
      initialDistanceKm: initialDistanceKm,
      initialSteps: initialSteps,
      initialDurationMinutes: initialDurationMinutes,
      initialDate: initialDate,
      title: title,
      helperText: helperText,
      source: source,
      replaceActivityLogId: replaceActivityLogId,
    ),
  );
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogQuickActions extends StatelessWidget {
  const _LogQuickActions({
    required this.onBarcode,
    required this.onActivity,
    required this.onManual,
  });

  final VoidCallback onBarcode;
  final VoidCallback onActivity;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final buttonWidth = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: buttonWidth,
                  child: FilledButton.icon(
                    onPressed: onBarcode,
                    icon: const Icon(Icons.search),
                    label: const Text('Barcode'),
                  ),
                ),
                SizedBox(
                  width: buttonWidth,
                  child: FilledButton.icon(
                    onPressed: onActivity,
                    icon: const Icon(Icons.directions_run),
                    label: const Text('Olahraga'),
                  ),
                ),
                SizedBox(
                  width: buttonWidth,
                  child: OutlinedButton.icon(
                    onPressed: onManual,
                    icon: const Icon(Icons.add),
                    label: const Text('Manual'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.13),
                  foregroundColor: color,
                  child: const Icon(Icons.today),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ringkasan hari ini',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: ratio,
              color: color,
              backgroundColor: const Color(0xFFE7E0D6),
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 12),
            Text(
              '${total.toStringAsFixed(1)}g dari target profil ${target.toStringAsFixed(0)}g',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
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

class _ActivityHistorySection extends StatelessWidget {
  const _ActivityHistorySection({required this.userDoc});

  final DocumentReference<Map<String, dynamic>> userDoc;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: userDoc
          .collection('activityLogs')
          .orderBy('date', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _InlineErrorCard(
            message: 'Riwayat olahraga belum bisa dimuat.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.directions_run),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Belum ada riwayat olahraga. Tambahkan dari tombol Olahraga.',
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HistoryTitle(
                  icon: Icons.directions_run,
                  title: 'Riwayat olahraga',
                  count: docs.length,
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < docs.length; index++) ...[
                  _ActivityLogTile(
                    id: docs[index].id,
                    userDoc: userDoc,
                    data: docs[index].data(),
                  ),
                  if (index != docs.length - 1) const Divider(height: 18),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActivityLogTile extends StatelessWidget {
  const _ActivityLogTile({
    required this.id,
    required this.userDoc,
    required this.data,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> userDoc;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final mode = normalizeActivityMode(data['activityMode']);
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final distance = (data['distanceKm'] as num?)?.toDouble() ?? 0;
    final duration = (data['durationMinutes'] as num?)?.toDouble() ?? 0;
    final steps = (data['steps'] as num?)?.toInt();
    final calories = (data['estimatedCaloriesBurned'] as num?)?.toDouble() ?? 0;
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.13),
          foregroundColor: Theme.of(context).colorScheme.secondary,
          child: Icon(
            mode == runningMode ? Icons.directions_run : Icons.directions_walk,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${activityModeLabel(mode)} ${distance.toStringAsFixed(1)} km',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                '${DateFormat('d MMM yyyy').format(date)} - ${duration.toStringAsFixed(0)} menit - ${calories.toStringAsFixed(0)} kkal',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit olahraga',
          onPressed: () => showActivityLogSheet(
            context,
            userDoc: userDoc,
            initialActivityMode: mode,
            initialDistanceKm: distance,
            initialSteps: steps,
            initialDurationMinutes: duration,
            initialDate: date,
            title: 'Edit olahraga',
            helperText: 'Perubahan akan menghitung ulang challenge aktif.',
            source: data['source']?.toString() ?? 'manual',
            replaceActivityLogId: id,
          ),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Hapus olahraga',
          onPressed: () => _delete(context),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus olahraga?'),
        content: const Text(
          'Riwayat aktivitas ini akan dihapus dan challenge dihitung ulang.',
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
    if (confirmed == true) {
      await userDoc.collection('activityLogs').doc(id).delete();
      await recalculateActiveChallenges(userDoc);
    }
  }
}

class _SugarHistorySection extends StatelessWidget {
  const _SugarHistorySection({
    required this.docs,
    required this.onEdit,
    required this.onDelete,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) onEdit;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HistoryTitle(
              icon: Icons.water_drop_outlined,
              title: 'Riwayat gula',
              count: docs.length,
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < docs.length; index++) ...[
              _SugarLogTile(
                data: docs[index].data(),
                onEdit: () => onEdit(docs[index]),
                onDelete: () => onDelete(docs[index]),
              ),
              if (index != docs.length - 1) const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTitle extends StatelessWidget {
  const _HistoryTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(icon, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Chip(label: Text('$count data')),
      ],
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.local_cafe_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['productName']?.toString() ?? 'Produk',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                '${DateFormat('d MMM yyyy').format(date)} - $source',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (confidence != null)
                Text('Confidence ${(confidence * 100).round()}%'),
              if (needsReview || manualAdjusted) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (needsReview)
                      const Chip(
                        avatar: Icon(Icons.warning_amber, size: 18),
                        label: Text('Perlu cek'),
                      ),
                    if (manualAdjusted)
                      const Chip(
                        avatar: Icon(Icons.edit_note, size: 18),
                        label: Text('Manual'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 86),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${sugar.toStringAsFixed(1)}g',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
          ],
        ),
      ],
    );
  }
}

class _EmptySugarState extends StatelessWidget {
  const _EmptySugarState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final _controller = TextEditingController();
  final _scannerController = MobileScannerController();
  var _completed = false;

  @override
  void dispose() {
    _controller.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _complete(String value) {
    if (_completed) return;
    final barcode = normalizeNutritionBarcode(value);
    if (barcode.isEmpty) return;
    _completed = true;
    Navigator.pop(context, barcode);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan barcode',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Arahkan kamera ke barcode produk. Jika kamera tidak tersedia, gunakan input manual.',
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 260,
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final value = barcode.rawValue;
                          if (value != null && value.trim().isNotEmpty) {
                            _complete(value);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Atau input barcode manual',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _complete(_controller.text),
                        icon: const Icon(Icons.search),
                        label: const Text('Cari'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
      text: data['serving']?.toString() ?? product?.serving ?? '1 porsi',
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
      final sugar = parseLocalizedDouble(_sugarController.text)!;
      final suggestedSugar = widget.product?.suggestedSugarGram;
      final previousManualAdjusted =
          widget.existingData?['manualAdjusted'] == true;
      final manualAdjusted = widget.product == null
          ? previousManualAdjusted
          : _isManualAdjustment(sugar, suggestedSugar);
      final payload = {
        'date': Timestamp.fromDate(dateOnly(_date)),
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
                        ? 'Tambah log gula'
                        : 'Edit log gula',
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
                    label: Text(
                      widget.existingId == null ? 'Simpan' : 'Update',
                    ),
                  ),
                ],
              ),
            ),
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

class _ActivityLogFormSheet extends StatefulWidget {
  const _ActivityLogFormSheet({
    required this.userDoc,
    this.initialActivityMode = walkingMode,
    this.initialDistanceKm,
    this.initialSteps,
    this.initialDurationMinutes,
    this.initialDate,
    this.title = 'Log olahraga',
    this.helperText,
    this.source = 'manual',
    this.replaceActivityLogId,
  });

  final DocumentReference<Map<String, dynamic>> userDoc;
  final String initialActivityMode;
  final double? initialDistanceKm;
  final int? initialSteps;
  final double? initialDurationMinutes;
  final DateTime? initialDate;
  final String title;
  final String? helperText;
  final String source;
  final String? replaceActivityLogId;

  @override
  State<_ActivityLogFormSheet> createState() => _ActivityLogFormSheetState();
}

class _ActivityLogFormSheetState extends State<_ActivityLogFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _distanceController;
  late final TextEditingController _stepsController;
  late final TextEditingController _durationController;
  late String _activityMode;
  late DateTime _date;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _activityMode = normalizeActivityMode(widget.initialActivityMode);
    final initialDistance = widget.initialDistanceKm;
    _distanceController = TextEditingController(
      text: initialDistance == null || initialDistance <= 0
          ? ''
          : initialDistance.toStringAsFixed(1),
    );
    _stepsController = TextEditingController(
      text: widget.initialSteps == null ? '' : widget.initialSteps.toString(),
    );
    _durationController = TextEditingController(
      text:
          widget.initialDurationMinutes?.toStringAsFixed(0) ??
          (initialDistance == null || initialDistance <= 0
              ? ''
              : (initialDistance / assumedSpeedKmPerHour(_activityMode) * 60)
                    .round()
                    .toString()),
    );
    final now = DateTime.now();
    final initialDate = widget.initialDate;
    _date = initialDate == null || initialDate.isAfter(now) ? now : initialDate;
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _stepsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await saveDailyActivityLog(
        userDoc: widget.userDoc,
        activityMode: _activityMode,
        distanceKm: parseLocalizedDouble(_distanceController.text)!,
        steps: _stepsController.text.trim().isEmpty
            ? null
            : parseLocalizedInt(_stepsController.text),
        durationMinutes: parseLocalizedDouble(_durationController.text)!,
        date: _date,
        source: widget.source,
        replaceActivityLogId: widget.replaceActivityLogId,
      );
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
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.helperText != null) ...[
                    const SizedBox(height: 8),
                    Text(widget.helperText!),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _activityMode,
                    decoration: const InputDecoration(
                      labelText: 'Aktivitas',
                      prefixIcon: Icon(Icons.directions_run),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: walkingMode,
                        child: Text('Jalan kaki'),
                      ),
                      DropdownMenuItem(value: runningMode, child: Text('Lari')),
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
                            labelText: 'Jarak (km)',
                            prefixIcon: Icon(Icons.route_outlined),
                          ),
                          validator: _positiveNumberValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Durasi (menit)',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          validator: _positiveNumberValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stepsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Langkah (opsional)',
                      prefixIcon: Icon(Icons.directions_walk),
                    ),
                    validator: _optionalNonNegativeIntValidator,
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
                    label: const Text('Simpan olahraga'),
                  ),
                ],
              ),
            ),
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

Future<void> saveDailyActivityLog({
  required DocumentReference<Map<String, dynamic>> userDoc,
  required String activityMode,
  required double distanceKm,
  int? steps,
  double? durationMinutes,
  DateTime? date,
  String source = 'manual',
  String? replaceActivityLogId,
}) async {
  if (distanceKm <= 0) {
    throw ArgumentError('Jarak aktivitas harus lebih dari 0.');
  }
  if (durationMinutes != null && durationMinutes <= 0) {
    throw ArgumentError('Durasi aktivitas harus lebih dari 0.');
  }
  if (steps != null && steps < 0) {
    throw ArgumentError('Langkah aktivitas tidak boleh negatif.');
  }

  final normalizedMode = normalizeActivityMode(activityMode);
  final now = DateTime.now();
  final selectedDate = dateOnly(date ?? now);
  if (selectedDate.isAfter(dateOnly(now))) {
    throw ArgumentError('Tanggal aktivitas tidak boleh di masa depan.');
  }

  final selectedDayKey = dayKey(selectedDate);
  final profile = (await userDoc.get()).data() ?? {};
  final weightKg = (profile['weightKg'] as num?)?.toDouble() ?? 65.0;
  final normalizedDuration =
      durationMinutes ??
      (distanceKm / assumedSpeedKmPerHour(normalizedMode) * 60);
  final calories = estimateCaloriesBurned(
    distanceKm: distanceKm,
    weightKg: weightKg,
    activityMode: normalizedMode,
  );

  final activityDoc = userDoc
      .collection('activityLogs')
      .doc('${selectedDayKey}_$normalizedMode');
  final existingActivity = await activityDoc.get();
  await activityDoc.set({
    'date': Timestamp.fromDate(selectedDate),
    'dayKey': selectedDayKey,
    'activityMode': normalizedMode,
    'distanceKm': distanceKm,
    'steps': steps,
    'durationMinutes': normalizedDuration,
    'estimatedCaloriesBurned': calories,
    'weightKgForEstimate': weightKg,
    'source': source,
    'updatedAt': FieldValue.serverTimestamp(),
    if (!existingActivity.exists) 'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  if (replaceActivityLogId != null &&
      replaceActivityLogId.isNotEmpty &&
      replaceActivityLogId != activityDoc.id) {
    await userDoc.collection('activityLogs').doc(replaceActivityLogId).delete();
  }
  await recalculateActiveChallenges(userDoc);
}

Future<void> recalculateActiveChallenges(
  DocumentReference<Map<String, dynamic>> userDoc,
) async {
  final profile = (await userDoc.get()).data() ?? {};
  final weightKg = (profile['weightKg'] as num?)?.toDouble() ?? 65.0;
  final logsSnapshot = await userDoc.collection('sugarLogs').get();
  final activitySnapshot = await userDoc.collection('activityLogs').get();
  final totalsByDay = <String, double>{};
  final daysWithLogs = <String>{};

  for (final doc in logsSnapshot.docs) {
    final data = doc.data();
    var key = data['dayKey']?.toString();
    if (key == null || key.isEmpty) {
      final logDate =
          (data['date'] as Timestamp?)?.toDate() ??
          (data['loggedAt'] as Timestamp?)?.toDate();
      if (logDate != null) key = dayKey(logDate);
    }
    final sugar = (data['sugarGram'] as num?)?.toDouble() ?? 0;
    if (key == null || key.isEmpty) continue;
    daysWithLogs.add(key);
    totalsByDay[key] = (totalsByDay[key] ?? 0) + sugar;
  }

  final distanceByDayAndMode = <String, Map<String, double>>{};
  final caloriesByDayAndMode = <String, Map<String, double>>{};
  final caloriesByDay = <String, double>{};
  final daysWithActivity = <String>{};
  for (final doc in activitySnapshot.docs) {
    final data = doc.data();
    final key = data['dayKey']?.toString();
    if (key == null || key.isEmpty) continue;
    final mode = normalizeActivityMode(data['activityMode']);
    final distance = (data['distanceKm'] as num?)?.toDouble() ?? 0;
    final storedCalories = (data['estimatedCaloriesBurned'] as num?)
        ?.toDouble();
    final calories =
        storedCalories ??
        estimateCaloriesBurned(
          distanceKm: distance,
          weightKg: weightKg,
          activityMode: mode,
        );
    if (distance <= 0) continue;
    daysWithActivity.add(key);
    final modeTotals = distanceByDayAndMode.putIfAbsent(key, () => {});
    modeTotals[mode] = (modeTotals[mode] ?? 0) + distance;
    final modeCalories = caloriesByDayAndMode.putIfAbsent(key, () => {});
    modeCalories[mode] = (modeCalories[mode] ?? 0) + calories;
    caloriesByDay[key] = (caloriesByDay[key] ?? 0) + calories;
  }

  final challenges = await userDoc.collection('challenges').get();
  for (final doc in challenges.docs) {
    final data = doc.data();
    final status = data['status']?.toString() ?? 'active';
    if (status == 'completed' || status == 'cancelled') continue;

    final startDate =
        (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final durationDays = (data['durationDays'] as num?)?.toInt() ?? 7;
    final target =
        (data['dailyTargetGram'] as num?)?.toDouble() ??
        AppConstants.defaultSugarTargetGram;
    final challengeType = normalizeChallengeType(data['challengeType']);
    final distanceTarget =
        (data['dailyDistanceTargetKm'] as num?)?.toDouble() ?? 0;
    final mode = normalizeActivityMode(data['activityMode']);
    final progress = recalculateChallengeProgress(
      startDate: startDate,
      durationDays: durationDays,
      dailyTargetGram: target,
      totalsByDay: totalsByDay,
      daysWithLogs: daysWithLogs,
      challengeType: challengeType,
      distanceByDayAndMode: distanceByDayAndMode,
      daysWithActivity: daysWithActivity,
      dailyDistanceTargetKm: distanceTarget,
      activityMode: mode,
    );
    final challengeCalories = challengeType == activityChallengeType
        ? _activityCaloriesForChallenge(
            startDate: startDate,
            durationDays: durationDays,
            activityMode: mode,
            caloriesByDayAndMode: caloriesByDayAndMode,
            fallbackCaloriesByDay: caloriesByDay,
          )
        : 0.0;
    final nextStatus = progress.isCompleted
        ? 'completed'
        : progress.isExpired
        ? 'expired'
        : 'active';
    await doc.reference.update({
      'challengeType': challengeType,
      'activityMode': mode,
      'dailyDistanceTargetKm': distanceTarget,
      'creditedDates': progress.creditedDates,
      'failedDates': progress.failedDates,
      'missedDates': progress.missedDates,
      'progressDays': progress.progressDays,
      'estimatedCaloriesBurnedTotal': challengeCalories,
      'status': nextStatus,
      if (progress.isCompleted) 'completedAt': FieldValue.serverTimestamp(),
      if (progress.isExpired) 'expiredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

double _activityCaloriesForChallenge({
  required DateTime startDate,
  required int durationDays,
  required String activityMode,
  required Map<String, Map<String, double>> caloriesByDayAndMode,
  required Map<String, double> fallbackCaloriesByDay,
}) {
  if (durationDays <= 0) return 0;
  final firstDay = dateOnly(startDate);
  final today = dateOnly(DateTime.now());
  var total = 0.0;
  for (var index = 0; index < durationDays; index++) {
    final date = firstDay.add(Duration(days: index));
    if (date.isAfter(today)) break;
    final key = dayKey(date);
    total +=
        caloriesByDayAndMode[key]?[normalizeActivityMode(activityMode)] ??
        fallbackCaloriesByDay[key] ??
        0;
  }
  return total;
}

String? _positiveNumberValidator(String? value) {
  final number = parseLocalizedDouble(value);
  if (number == null || number <= 0) return 'Masukkan angka valid.';
  return null;
}

String? _optionalNonNegativeIntValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final number = parseLocalizedInt(text);
  if (number == null || number < 0) return 'Masukkan angka valid.';
  return null;
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
