import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/kategori_produk_model.dart';
import '../../data/models/produk_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import 'produk_providers.dart';

class ProdukFormPage extends ConsumerWidget {
  const ProdukFormPage({super.key, this.productId});

  final String? productId;

  bool get _isEditing => productId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(produkKategoriProvider);

    if (!_isEditing) {
      // Tambah Produk: ambil nomor urut berikutnya dari Supabase (per koperasi)
      final nextKodeState = ref.watch(nextKodeProdukProvider);

      return categoriesState.when(
        loading: () => const AppScaffold(
          title: 'Tambah Produk',
          showBackButton: true,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => _FormLoadError(
          title: 'Tambah Produk',
          message: 'Gagal memuat kategori.',
          onRetry: () => ref.invalidate(produkKategoriProvider),
        ),
        data: (categories) => nextKodeState.when(
          loading: () => const AppScaffold(
            title: 'Tambah Produk',
            showBackButton: true,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _ProdukFormContent(
            categories: categories,
            initialKodeProduk: 'PRD-000001',
          ),
          data: (kode) => _ProdukFormContent(
            categories: categories,
            initialKodeProduk: kode,
          ),
        ),
      );
    }

    final productState = ref.watch(produkDetailProvider(productId!));

    return productState.when(
      loading: () => const AppScaffold(
        title: 'Edit Produk',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _FormLoadError(
        title: 'Edit Produk',
        message: 'Gagal memuat produk.',
        onRetry: () => ref.invalidate(produkDetailProvider(productId!)),
      ),
      data: (product) => categoriesState.when(
        loading: () => const AppScaffold(
          title: 'Edit Produk',
          showBackButton: true,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => _FormLoadError(
          title: 'Edit Produk',
          message: 'Gagal memuat kategori.',
          onRetry: () => ref.invalidate(produkKategoriProvider),
        ),
        data: (categories) => _ProdukFormContent(
          product: product,
          categories: categories,
          // Saat edit: kode produk tidak berubah, tetap milik produk tersebut
          initialKodeProduk: product.kodeProduk,
        ),
      ),
    );
  }
}

class _ProdukFormContent extends ConsumerStatefulWidget {
  const _ProdukFormContent({
    required this.categories,
    required this.initialKodeProduk,
    this.product,
  });

  final ProdukModel? product;
  final List<KategoriProdukModel> categories;
  final String initialKodeProduk;

  @override
  ConsumerState<_ProdukFormContent> createState() => _ProdukFormContentState();
}

class _ProdukFormContentState extends ConsumerState<_ProdukFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kodeController;
  late final TextEditingController _namaController;
  late final TextEditingController _hargaBeliController;
  late final TextEditingController _hargaJualController;
  late final TextEditingController _stokController;
  String? _kategoriId;
  bool _isSaving = false;
  bool _isRegeneratingKode = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _kategoriId = product?.kategoriId;
    _kodeController = TextEditingController(text: widget.initialKodeProduk);
    _namaController = TextEditingController(text: product?.namaProduk ?? '');
    _hargaBeliController = TextEditingController(
      text: product == null ? '0' : product.hargaBeli.toString(),
    );
    _hargaJualController = TextEditingController(
      text: product == null ? '0' : product.hargaJual.toString(),
    );
    _stokController = TextEditingController(
      text: product == null ? '0' : product.stok.toString(),
    );
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _stokController.dispose();
    super.dispose();
  }

  /// Generate ulang kode produk saat user menekan tombol refresh.
  Future<void> _regenerateKode() async {
    setState(() => _isRegeneratingKode = true);
    try {
      final newKode =
          await ref.read(produkControllerProvider.notifier).generateKode();
      if (mounted) _kodeController.text = newKode;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal generate kode produk.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegeneratingKode = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final product = ProdukModel(
      id: widget.product?.id ?? '',
      kategoriId: _kategoriId,
      kodeProduk: _kodeController.text.trim(),
      namaProduk: _namaController.text.trim(),
      hargaBeli: _parseNumber(_hargaBeliController.text),
      hargaJual: _parseNumber(_hargaJualController.text),
      stok: _parseInteger(_stokController.text),
    );

    final controller = ref.read(produkControllerProvider.notifier);
    final isSuccess = _isEditing
        ? await controller.updateProduct(product)
        : await controller.create(product);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (isSuccess) {
      ref.invalidate(produkDetailProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Produk berhasil diperbarui.'
                : 'Produk berhasil ditambahkan.',
          ),
        ),
      );
      context.go(AppRoutes.produk);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan produk.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isSaving || _isRegeneratingKode;
    return AppScaffold(
      title: _isEditing ? 'Edit Produk' : 'Tambah Produk',
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
                  // ── Kategori ──────────────────────────────────────────────
                  DropdownButtonFormField<String>(
                    initialValue: _kategoriId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: widget.categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.namaKategori),
                          ),
                        )
                        .toList(),
                    onChanged: isBusy
                        ? null
                        : (value) => setState(() => _kategoriId = value),
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Kategori wajib dipilih.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Kode Produk (READ ONLY) + tombol Generate Ulang ───────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _kodeController,
                          // TASK 3 & 4: field READ ONLY — tidak dapat diedit user
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Kode Produk',
                            prefixIcon: const Icon(Icons.qr_code_2_outlined),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            helperText: _isEditing
                              ? 'Kode produk tidak dapat diubah'
                              : 'Kode produk dibuat otomatis oleh sistem.',
                            helperStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          // Validator tetap ada agar Form.validate() lulus
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Kode produk tidak boleh kosong.';
                            }
                            return null;
                          },
                        ),
                      ),
                      // Tombol refresh hanya muncul saat mode Tambah Produk
                      if (!_isEditing) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Tooltip(
                            message: 'Generate ulang kode produk',
                            child: IconButton.outlined(
                              onPressed: _isSaving ? null : _regenerateKode,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Nama Produk ───────────────────────────────────────────
                  TextFormField(
                    controller: _namaController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Nama produk wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Harga & Stok ──────────────────────────────────────────
                  _NumberFields(
                    hargaBeliController: _hargaBeliController,
                    hargaJualController: _hargaJualController,
                    stokController: _stokController,
                  ),
                  const SizedBox(height: 24),

                  // ── Submit ────────────────────────────────────────────────
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label:
                        Text(_isEditing ? 'Simpan Perubahan' : 'Simpan Produk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  num _parseNumber(String value) {
    return num.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }

  int _parseInteger(String value) {
    return int.tryParse(value.replaceAll('.', '')) ?? 0;
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _NumberFields extends StatelessWidget {
  const _NumberFields({
    required this.hargaBeliController,
    required this.hargaJualController,
    required this.stokController,
  });

  final TextEditingController hargaBeliController;
  final TextEditingController hargaJualController;
  final TextEditingController stokController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final fields = [
          _NumberTextField(
            controller: hargaBeliController,
            label: 'Harga Beli',
            icon: Icons.payments_outlined,
            allowDecimal: true,
          ),
          _NumberTextField(
            controller: hargaJualController,
            label: 'Harga Jual',
            icon: Icons.sell_outlined,
            allowDecimal: true,
          ),
          _NumberTextField(
            controller: stokController,
            label: 'Stok Awal',
            icon: Icons.inventory_outlined,
            allowDecimal: false,
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              for (final field in fields) ...[
                field,
                if (field != fields.last) const SizedBox(height: 16),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in fields) ...[
              Expanded(child: field),
              if (field != fields.last) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _NumberTextField extends StatelessWidget {
  const _NumberTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.allowDecimal,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        final number = allowDecimal
            ? num.tryParse(text.replaceAll('.', '').replaceAll(',', '.'))
            : int.tryParse(text.replaceAll('.', ''));

        if (text.isEmpty) return '$label wajib diisi.';
        if (number == null) return '$label harus berupa angka.';
        if (number < 0) return '$label tidak boleh negatif.';
        return null;
      },
    );
  }
}

class _FormLoadError extends StatelessWidget {
  const _FormLoadError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
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
