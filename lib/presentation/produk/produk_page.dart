import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/produk_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import 'delete_produk_dialog.dart';
import 'produk_providers.dart';

class ProdukPage extends ConsumerWidget {
  const ProdukPage({super.key});

  Future<void> _deleteProduct(
    BuildContext context,
    WidgetRef ref,
    ProdukModel product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteProdukDialog(product: product),
    );

    if (confirmed != true) return;

    final isSuccess =
        await ref.read(produkControllerProvider.notifier).delete(product.id);

    if (context.mounted && isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk berhasil dihapus.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(produkControllerProvider);
    final search = ref.watch(produkSearchProvider);

    return AppScaffold(
      title: 'Katalog Produk',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () =>
              ref.read(produkControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Tambah Produk',
          onPressed: () => context.go(AppRoutes.produkCreate),
          icon: const Icon(Icons.add_circle_rounded),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          return Column(
            children: [
              _ProdukSearchField(initialValue: search),
              const SizedBox(height: 24),
              Expanded(
                child: productsState.when(
                  loading: () =>
                      const LoadingState(message: 'Memuat produk...'),
                  error: (error, stackTrace) => _ProdukErrorState(
                    message: _errorMessage(error),
                    onRetry: () =>
                        ref.read(produkControllerProvider.notifier).refresh(),
                  ),
                  data: (products) {
                    if (products.isEmpty) {
                      return EmptyState(
                        message: search.trim().isEmpty
                            ? 'Wah, belum ada produk nih.'
                            : 'Produk tidak ditemukan.',
                      );
                    }

                    return _ProdukList(
                      products: products,
                      isWide: isWide,
                      onDetail: (product) =>
                          context.go(AppRoutes.produkDetailPath(product.id)),
                      onEdit: (product) =>
                          context.go(AppRoutes.produkEditPath(product.id)),
                      onDelete: (product) =>
                          _deleteProduct(context, ref, product),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat produk. Silakan coba lagi.';
  }
}

class _ProdukSearchField extends ConsumerStatefulWidget {
  const _ProdukSearchField({required this.initialValue});

  final String initialValue;

  @override
  ConsumerState<_ProdukSearchField> createState() => _ProdukSearchFieldState();
}

class _ProdukSearchFieldState extends ConsumerState<_ProdukSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _ProdukSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama atau kode produk...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Bersihkan pencarian',
                onPressed: () {
                  _controller.clear();
                  ref.read(produkSearchProvider.notifier).state = '';
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      onChanged: (value) {
        ref.read(produkSearchProvider.notifier).state = value;
        setState(() {});
      },
    );
  }
}

class _ProdukList extends StatelessWidget {
  const _ProdukList({
    required this.products,
    required this.isWide,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ProdukModel> products;
  final bool isWide;
  final ValueChanged<ProdukModel> onDetail;
  final ValueChanged<ProdukModel> onEdit;
  final ValueChanged<ProdukModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isWide ? 400 : double.infinity,
        mainAxisExtent: 140,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _ProdukCard(
        product: products[index],
        onDetail: onDetail,
        onEdit: onEdit,
        onDelete: onDelete,
      ).animate(delay: (index * 30).ms).fadeIn().slideY(begin: 0.1),
    );
  }
}

class _ProdukCard extends StatelessWidget {
  const _ProdukCard({
    required this.product,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final ProdukModel product;
  final ValueChanged<ProdukModel> onDetail;
  final ValueChanged<ProdukModel> onEdit;
  final ValueChanged<ProdukModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onDetail(product),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.namaProduk,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${product.kodeProduk} • ${product.namaKategori ?? 'Tanpa Kategori'}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            currency.format(product.hargaJual),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Builder(
                            builder: (context) {
                              final isOutOfStock = product.stok <= 0;
                              final isLowStock = product.stok > 0 && product.stok <= 10;
                              final stokColor = isOutOfStock
                                  ? AppTheme.error
                                  : isLowStock
                                      ? AppTheme.warning
                                      : AppTheme.success;
                                      
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: stokColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOutOfStock ? 'Stok Habis' : 'Stok: ${product.stok}',
                                  style: TextStyle(
                                    color: stokColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => onEdit(product),
                      icon: const Icon(Icons.edit_note_rounded, color: AppTheme.secondary),
                    ),
                    IconButton(
                      onPressed: () => onDelete(product),
                      icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.error),
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

class _ProdukErrorState extends StatelessWidget {
  const _ProdukErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

