import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/transaksi_detail_item_model.dart';
import '../../data/models/transaksi_model.dart';
import '../../routes/app_routes.dart';
import '../../services/pdf_receipt_generator.dart';
import '../../services/receipt_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import '../settings/thermal_printer_providers.dart';
import 'transaksi_providers.dart';

class TransaksiDetailPage extends ConsumerStatefulWidget {
  const TransaksiDetailPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<TransaksiDetailPage> createState() =>
      _TransaksiDetailPageState();
}

class _TransaksiDetailPageState extends ConsumerState<TransaksiDetailPage> {
  bool _isPdfPrinting = false;
  bool _isThermalPrinting = false;

  // ── Lihat Struk (Preview PDF) ──────────────────────────────────────────────
  Future<void> _onLihatStruk() async {
    setState(() => _isPdfPrinting = true);
    try {
      final receiptData = await ref
          .read(receiptServiceProvider)
          .buildFromTransactionId(widget.transactionId);
      final generator = ref.read(pdfReceiptGeneratorProvider);

      if (!mounted) return;
      await Printing.layoutPdf(
        name: '${receiptData.nomorTransaksi}_struk',
        onLayout: (_) async => generator.generate(receiptData),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException ? e.message : 'Gagal membuka struk.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPdfPrinting = false);
    }
  }

  // ── Cetak Thermal ──────────────────────────────────────────────────────────
  Future<void> _onCetakThermal() async {
    // Jika printer belum connect, arahkan ke settings thermal
    final printerState = ref.read(thermalPrinterControllerProvider);
    if (!printerState.isConnected) {
      if (mounted) context.push(AppRoutes.thermalPrinter);
      return;
    }

    setState(() => _isThermalPrinting = true);
    try {
      final receiptData = await ref
          .read(receiptServiceProvider)
          .buildFromTransactionId(widget.transactionId);

      final success = await ref
          .read(thermalPrinterControllerProvider.notifier)
          .printReceipt(receiptData);

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Struk thermal berhasil dicetak!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException ? e.message : 'Gagal cetak thermal.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isThermalPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionState =
        ref.watch(transaksiDetailProvider(widget.transactionId));
    final itemsState =
        ref.watch(transaksiDetailItemsProvider(widget.transactionId));

    final isBusy = _isPdfPrinting || _isThermalPrinting;
    final printerConnected = !kIsWeb &&
        ref.watch(thermalPrinterControllerProvider).isConnected;

    return AppScaffold(
      title: 'Detail Transaksi',
      showBackButton: true,
      actions: [
        // ── Loading indicator saat printing ──────────────────────────────────
        if (isBusy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          // ── Lihat / Cetak Struk PDF ─────────────────────────────────────
          IconButton(
            tooltip: 'Lihat / Cetak Struk (PDF)',
            onPressed: _onLihatStruk,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          // ── Cetak Thermal (Android & Windows saja) ──────────────────────
          if (!kIsWeb)
            IconButton(
              tooltip: printerConnected
                  ? 'Cetak Thermal'
                  : 'Hubungkan Printer Thermal',
              onPressed: _onCetakThermal,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.print_rounded),
                  if (printerConnected)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
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
          onRetry: () =>
              ref.invalidate(transaksiDetailProvider(widget.transactionId)),
        ),
        data: (transaction) => itemsState.when(
          loading: () =>
              const LoadingState(message: 'Memuat item transaksi...'),
          error: (error, stackTrace) => _DetailErrorState(
            message: _errorMessage(error),
            onRetry: () => ref
                .invalidate(transaksiDetailItemsProvider(widget.transactionId)),
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
