import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/transaksi_detail_item_model.dart';
import '../../data/models/transaksi_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import 'transaksi_providers.dart';

class TransaksiDetailPage extends ConsumerWidget {
  const TransaksiDetailPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionState = ref.watch(transaksiDetailProvider(transactionId));
    final itemsState = ref.watch(transaksiDetailItemsProvider(transactionId));

    return AppScaffold(
      title: 'Detail Transaksi',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Riwayat',
          onPressed: () => context.go(AppRoutes.transaksiHistory),
          icon: const Icon(Icons.history),
        ),
      ],
      child: transactionState.when(
        loading: () =>
            const LoadingState(message: 'Memuat detail transaksi...'),
        error: (error, stackTrace) => _DetailErrorState(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(transaksiDetailProvider(transactionId)),
        ),
        data: (transaction) => itemsState.when(
          loading: () =>
              const LoadingState(message: 'Memuat item transaksi...'),
          error: (error, stackTrace) => _DetailErrorState(
            message: _errorMessage(error),
            onRetry: () =>
                ref.invalidate(transaksiDetailItemsProvider(transactionId)),
          ),
          data: (items) => _DetailContent(
            transaction: transaction,
            items: items,
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat detail transaksi. Silakan coba lagi.';
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.transaction,
    required this.items,
  });

  final TransaksiModel transaction;
  final List<TransaksiDetailItemModel> items;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.format(transaction.total),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.calendar_month_outlined),
                          label: Text(dateFormat.format(transaction.tanggal)),
                        ),
                        Chip(
                          avatar: const Icon(Icons.payments_outlined),
                          label: Text(transaction.metodePembayaran),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const SizedBox(
                height: 220,
                child: EmptyState(message: 'Detail transaksi kosong.'),
              )
            else
              ...items.map((item) => _DetailItemCard(item: item)),
          ],
        ),
      ),
    );
  }
}

class _DetailItemCard extends StatelessWidget {
  const _DetailItemCard({required this.item});

  final TransaksiDetailItemModel item;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
          title: Text(
            item.namaProduk ?? '-',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${item.qty} x ${currency.format(item.harga)}'),
          trailing: Text(
            currency.format(item.subtotal),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({
    required this.message,
    required this.onRetry,
  });

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
