import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/produk_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import 'delete_produk_dialog.dart';
import 'produk_providers.dart';

class ProdukDetailPage extends ConsumerWidget {
  const ProdukDetailPage({super.key, required this.productId});

  final String productId;

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
      context.go(AppRoutes.produk);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productState = ref.watch(produkDetailProvider(productId));

    return productState.when(
      loading: () => const AppScaffold(
        title: 'Detail Produk',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => AppScaffold(
        title: 'Detail Produk',
        showBackButton: true,
        child: _DetailErrorState(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(produkDetailProvider(productId)),
        ),
      ),
      data: (product) => AppScaffold(
        title: 'Detail Produk',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => context.go(AppRoutes.produkEditPath(product.id)),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Hapus',
            onPressed: () => _deleteProduct(context, ref, product),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
        child: _DetailContent(product: product),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat detail produk. Silakan coba lagi.';
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.product});

  final ProdukModel product;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat =
        DateFormat('dd MMM yyyy HH:mm', AppLocale.formattingLocale);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.namaProduk,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(product.kodeProduk),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.category_outlined),
                              label: Text(product.namaKategori ?? '-'),
                            ),
                            Chip(
                              avatar: const Icon(Icons.inventory_outlined),
                              label: Text('Stok ${product.stok}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _DetailGrid(
                  items: [
                    _DetailItem(
                      label: 'Harga Beli',
                      value: currency.format(product.hargaBeli),
                      icon: Icons.payments_outlined,
                    ),
                    _DetailItem(
                      label: 'Harga Jual',
                      value: currency.format(product.hargaJual),
                      icon: Icons.sell_outlined,
                    ),
                    _DetailItem(
                      label: 'Kategori ID',
                      value: product.kategoriId ?? '-',
                      icon: Icons.tag_outlined,
                    ),
                    _DetailItem(
                      label: 'Dibuat',
                      value: product.createdAt == null
                          ? '-'
                          : dateFormat.format(product.createdAt!),
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});

  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;

        if (!isWide) {
          return Column(
            children: [
              for (final item in items) ...[
                item,
                if (item != items.last) const SizedBox(height: 8),
              ],
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 104,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
