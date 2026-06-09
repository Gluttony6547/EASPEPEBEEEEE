import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/sugar_log_logic.dart';
import '../services/api_service.dart';

class SugarLogScreen extends StatelessWidget {
  const SugarLogScreen({super.key, this.user});

  final User? user;

  User? get _activeUser => user ?? FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>> _userDoc(User user) {
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> _logs(User user) {
    return _userDoc(user).collection('sugarLogs');
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = _activeUser;
    if (activeUser == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Masuk terlebih dahulu untuk memakai log gula.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final userDoc = _userDoc(activeUser);
    final logs = _logs(activeUser);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Gula'),
        actions: [
          IconButton(
            tooltip: 'Tambah log',
            onPressed: () =>
                _showLogForm(context, userDoc: userDoc, logs: logs),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogForm(context, userDoc: userDoc, logs: logs),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: logs.orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final todayKey = sugarLogDayKey(DateTime.now());
          final todayTotal = totalSugarForDay(
            docs.map((doc) => doc.data()),
            todayKey,
          );

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userDoc.snapshots(),
            builder: (context, profileSnapshot) {
              final profile = profileSnapshot.data?.data() ?? {};
              final target =
                  (profile['dailySugarTargetGram'] as num?)?.toDouble() ??
                  defaultDailySugarTargetGram;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _DailySugarCard(total: todayTotal, target: target),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    const _EmptyState()
                  else
                    for (final doc in docs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SugarLogTile(
                          data: doc.data(),
                          onEdit: () => _showLogForm(
                            context,
                            userDoc: userDoc,
                            logs: logs,
                            existingId: doc.id,
                            existingData: doc.data(),
                          ),
                          onDelete: () => _deleteLog(context, logs, doc.id),
                        ),
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showLogForm(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> userDoc,
    required CollectionReference<Map<String, dynamic>> logs,
    String? existingId,
    Map<String, dynamic>? existingData,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SugarLogFormSheet(
        userDoc: userDoc,
        logs: logs,
        existingId: existingId,
        existingData: existingData,
      ),
    );
  }

  Future<void> _deleteLog(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> logs,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus log gula?'),
        content: const Text('Data konsumsi gula ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await logs.doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Log gula dihapus.')));
      }
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
    final isOverTarget = total > target;
    final color = isOverTarget
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
                Icon(Icons.today, color: color),
                const SizedBox(width: 10),
                Text(
                  'Ringkasan hari ini',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 12),
            Text(
              '${total.toStringAsFixed(1)}g dari target ${target.toStringAsFixed(0)}g',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isOverTarget
                  ? 'Target harian terlewati.'
                  : 'Masih dalam target harian.',
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
    final serving = data['serving']?.toString() ?? '1 porsi';
    final source = data['source']?.toString() ?? 'manual';

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.restaurant_menu)),
        title: Text(data['productName']?.toString() ?? 'Produk'),
        subtitle: Text(
          '${formatSugarDate(date)} - $serving - ${_sourceLabel(source)}',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 42),
            SizedBox(height: 12),
            Text('Belum ada log gula.'),
            SizedBox(height: 6),
            Text(
              'Tambah makanan atau minuman untuk memantau gula harian.',
              textAlign: TextAlign.center,
            ),
          ],
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
  });

  final DocumentReference<Map<String, dynamic>> userDoc;
  final CollectionReference<Map<String, dynamic>> logs;
  final String? existingId;
  final Map<String, dynamic>? existingData;

  @override
  State<_SugarLogFormSheet> createState() => _SugarLogFormSheetState();
}

class _SugarLogFormSheetState extends State<_SugarLogFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _productController;
  late final TextEditingController _sugarController;
  late final TextEditingController _servingController;
  late DateTime _date;
  var _isSaving = false;
  var _source = 'manual';

  @override
  void initState() {
    super.initState();
    final data = widget.existingData ?? {};
    _productController = TextEditingController(
      text: data['productName']?.toString() ?? '',
    );
    _sugarController = TextEditingController(
      text: (data['sugarGram'] as num?)?.toString() ?? '',
    );
    _servingController = TextEditingController(
      text: data['serving']?.toString() ?? '1 porsi',
    );
    _source = data['source']?.toString() ?? 'manual';
    _date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
  }

  @override
  void dispose() {
    _productController.dispose();
    _sugarController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final sugar = parseSugarNumber(_sugarController.text)!;
      final payload = {
        'productName': _productController.text.trim(),
        'sugarGram': sugar,
        'serving': _servingController.text.trim(),
        'date': Timestamp.fromDate(_date),
        'dayKey': sugarLogDayKey(_date),
        'source': _source,
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingId == null
                  ? 'Log gula ditambahkan.'
                  : 'Log gula diperbarui.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _searchProduct() async {
    final selection = await showModalBottomSheet<_ProductSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ProductSearchSheet(),
    );

    if (selection == null) return;
    _productController.text = selection.name;
    _sugarController.text = selection.sugarGram.toStringAsFixed(1);
    _servingController.text = '${selection.portionGram.toStringAsFixed(0)}g';
    setState(() => _source = 'open_food_facts');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _searchProduct,
                icon: const Icon(Icons.search),
                label: const Text('Cari produk'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _productController,
                decoration: const InputDecoration(
                  labelText: 'Nama makanan/minuman',
                  prefixIcon: Icon(Icons.fastfood_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama wajib diisi.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sugarController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Gula (gram)',
                  prefixIcon: Icon(Icons.scale_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final sugar = parseSugarNumber(value);
                  if (sugar == null || sugar < 0) {
                    return 'Masukkan angka gula yang valid.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _servingController,
                decoration: const InputDecoration(
                  labelText: 'Porsi',
                  prefixIcon: Icon(Icons.local_dining_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(formatSugarDate(_date)),
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

class _ProductSearchSheet extends StatefulWidget {
  const _ProductSearchSheet();

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _queryController = TextEditingController();
  final _portionController = TextEditingController(text: '100');
  List<Map<String, dynamic>> _products = const [];
  var _isLoading = false;
  String? _message;

  @override
  void dispose() {
    _queryController.dispose();
    _portionController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _message = null;
      _products = const [];
    });

    try {
      final products = await ApiService.searchFood(query);
      if (!mounted) return;
      setState(() {
        _products = products;
        _message = products.isEmpty ? 'Produk tidak ditemukan.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _select(Map<String, dynamic> product) {
    final portionGram = parseSugarNumber(_portionController.text) ?? 100;
    final sugars100g = (product['sugars100g'] as num).toDouble();
    final sugarGram = calculateSugarGram(
      sugars100g: sugars100g,
      portionGram: portionGram,
    );

    Navigator.pop(
      context,
      _ProductSelection(
        name: product['name']?.toString() ?? 'Produk',
        portionGram: portionGram,
        sugarGram: sugarGram,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cari produk', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Nama produk',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Cari',
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Porsi dimakan (gram)',
                prefixIcon: Icon(Icons.scale_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_message != null)
              Text(_message!, textAlign: TextAlign.center)
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final sugars100g = (product['sugars100g'] as num)
                        .toDouble()
                        .toStringAsFixed(1);
                    return ListTile(
                      title: Text(product['name']?.toString() ?? 'Produk'),
                      subtitle: Text(
                        '${product['brand'] ?? ''} - $sugars100g g gula/100g',
                      ),
                      onTap: () => _select(product),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductSelection {
  const _ProductSelection({
    required this.name,
    required this.portionGram,
    required this.sugarGram,
  });

  final String name;
  final double portionGram;
  final double sugarGram;
}

String _sourceLabel(String source) {
  return switch (source) {
    'open_food_facts' => 'Open Food Facts',
    'manual' => 'Manual',
    _ => source,
  };
}
