import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/stok_masuk_model.dart';
import '../../widgets/app_scaffold.dart';
import 'stok_providers.dart';

class StokDetailPage extends ConsumerWidget {
  const StokDetailPage({super.key, required this.stockId});

  final String stockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockState = ref.watch(stokDetailProvider(stockId));

    return stockState.when(
      loading: () => const AppScaffold(
        title: 'Detail Stok',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => AppScaffold(
        title: 'Detail Stok',
        showBackButton: true,
        child: _DetailErrorState(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(stokDetailProvider(stockId)),
        ),
      ),
      data: (stock) => AppScaffold(
        title: 'Detail Stok',
        showBackButton: true,
        child: _DetailContent(stock: stock),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat detail stok. Silakan coba lagi.';
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.stock});

  final StokMasukModel stock;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);

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
                      stock.namaProduk ?? '-',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.add_box_outlined),
                          label: Text('+${stock.qty}'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.calendar_month_outlined),
                          label: Text(dateFormat.format(stock.tanggal)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notes_outlined),
                title: const Text('Keterangan'),
                subtitle: Text(
                  stock.keterangan?.isEmpty ?? true
                      ? 'Tanpa keterangan'
                      : stock.keterangan!,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.tag_outlined),
                title: const Text('Produk ID'),
                subtitle: Text(stock.produkId),
              ),
            ),
          ],
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
