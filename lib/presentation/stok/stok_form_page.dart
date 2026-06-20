import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../data/models/produk_model.dart';
import '../../data/models/stok_masuk_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import 'stok_providers.dart';

class StokFormPage extends ConsumerWidget {
  const StokFormPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(stokProductOptionsProvider);

    return productsState.when(
      loading: () => const AppScaffold(
        title: 'Tambah Stok',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _FormLoadError(
        message: 'Gagal memuat produk.',
        onRetry: () => ref.invalidate(stokProductOptionsProvider),
      ),
      data: (products) => _StokFormContent(products: products),
    );
  }
}

class _StokFormContent extends ConsumerStatefulWidget {
  const _StokFormContent({required this.products});

  final List<ProdukModel> products;

  @override
  ConsumerState<_StokFormContent> createState() => _StokFormContentState();
}

class _StokFormContentState extends ConsumerState<_StokFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDate = DateTime.now();
  String? _produkId;
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final stock = StokMasukModel(
      id: '',
      produkId: _produkId ?? '',
      qty: int.tryParse(_qtyController.text.trim()) ?? 0,
      tanggal: _selectedDate ?? DateTime.now(),
      keterangan: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final isSuccess =
        await ref.read(stokControllerProvider.notifier).addStock(stock);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (isSuccess) {
      ref.invalidate(stokProductOptionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok berhasil ditambahkan.')),
      );
      context.go(AppRoutes.stok);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menambahkan stok.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);

    return AppScaffold(
      title: 'Tambah Stok',
      showBackButton: true,
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _produkId,
                    decoration: const InputDecoration(
                      labelText: 'Produk',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: widget.products
                        .map(
                          (product) => DropdownMenuItem(
                            value: product.id,
                            child: Text(
                                '${product.namaProduk} (stok ${product.stok})'),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _produkId = value),
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Produk wajib dipilih.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.add_box_outlined),
                    ),
                    validator: (value) {
                      final qty = int.tryParse(value?.trim() ?? '');
                      if (qty == null) return 'Qty wajib berupa angka.';
                      if (qty <= 0) return 'Qty harus lebih dari 0.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FormField<DateTime>(
                    initialValue: _selectedDate,
                    validator: (value) {
                      if (_selectedDate == null) {
                        return 'Tanggal wajib dipilih.';
                      }
                      return null;
                    },
                    builder: (field) {
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tanggal',
                          prefixIcon: const Icon(Icons.calendar_month_outlined),
                          errorText: field.errorText,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                        child: InkWell(
                          onTap: _isSaving ? null : _pickDate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _selectedDate == null
                                  ? 'Pilih tanggal'
                                  : dateFormat.format(_selectedDate!),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan',
                      prefixIcon: Icon(Icons.notes_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Simpan Stok'),
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

class _FormLoadError extends StatelessWidget {
  const _FormLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tambah Stok',
      showBackButton: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
