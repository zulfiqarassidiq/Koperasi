import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/transaksi_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import 'transaksi_providers.dart';

class TransaksiHistoryPage extends ConsumerWidget {
  const TransaksiHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(transaksiHistoryProvider);

    return AppScaffold(
      title: 'Riwayat Transaksi',
      actions: [
        IconButton(
          tooltip: 'Transaksi Baru',
          onPressed: () => context.go(AppRoutes.transaksi),
          icon: const Icon(Icons.point_of_sale),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(transaksiHistoryProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: historyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _HistoryErrorState(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(transaksiHistoryProvider),
        ),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const EmptyState(message: 'Belum ada riwayat transaksi.');
          }

          return _HistoryList(transactions: transactions);
        },
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat riwayat transaksi. Silakan coba lagi.';
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.transactions});

  final List<TransaksiModel> transactions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (!isWide) {
          return ListView.separated(
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _HistoryCard(
              transaction: transactions[index],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 132,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: transactions.length,
          itemBuilder: (context, index) => _HistoryCard(
            transaction: transactions[index],
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.transaction});

  final TransaksiModel transaction;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go(AppRoutes.transaksiDetailPath(transaction.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currency.format(transaction.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text(dateFormat.format(transaction.tanggal)),
              const Spacer(),
              Chip(
                avatar: const Icon(Icons.payments_outlined),
                label: Text(transaction.metodePembayaran),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({
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
