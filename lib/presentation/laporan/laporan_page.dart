// ignore_for_file: deprecated_member_use

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../routes/app_routes.dart';
import '../../services/pdf_receipt_generator.dart';
import '../../services/receipt_service.dart';
import '../settings/thermal_printer_providers.dart';

import '../../core/config/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/laporan_summary.dart';
import '../../data/models/transaksi_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/loading_state.dart';
import '../../utils/file_saver.dart';
import 'laporan_provider.dart';

class LaporanPage extends ConsumerWidget {
  const LaporanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laporan = ref.watch(laporanSummaryProvider);
    final topProducts = ref.watch(laporanTopProductsProvider);
    final transactions = ref.watch(laporanTransactionsProvider);
    final filter = ref.watch(laporanFilterProvider);

    return AppScaffold(
      title: 'Laporan',
      showBackButton: true,
      child: ListView(
        children: [
          _ExportActionsCard(
            onExportPdf: () => laporan.whenData((data) => _exportPdf(data, filter.dateRange)),
            onExportExcel: () => laporan.whenData((data) => _exportExcel(data, filter.dateRange)),
            onExportCsv: () => laporan.whenData((data) => _exportCsv(data, filter.dateRange)),
            onPrint: () => laporan.whenData((data) => _printReport(data, filter.dateRange)),
          ),
          const SizedBox(height: 16),
          const _QuickFiltersSection(),
          const SizedBox(height: 16),
          const _CustomDateRangeSection(),
          const SizedBox(height: 16),
          _DateRangeHeader(range: filter.dateRange),
          const SizedBox(height: 16),
          laporan.when(
            data: (data) => _LaporanMetricsGrid(data: data),
            loading: () => const LoadingState(message: 'Memuat ringkasan...'),
            error: (error, stack) => Center(child: Text(error.toString())),
          ),
          const SizedBox(height: 24),
          topProducts.when(
            data: (data) => _TopProductsSection(products: data),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text(error.toString())),
          ),
          const SizedBox(height: 24),
          transactions.when(
            data: (data) => _TransactionsSection(transactions: data),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text(error.toString())),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _exportPdf(LaporanSummary data, DateTimeRange range) async {
    await Printing.layoutPdf(
      name: 'laporan-keuangan.pdf',
      onLayout: (_) => _buildLaporanPdf(data, range),
    );
  }

  Future<void> _printReport(LaporanSummary data, DateTimeRange range) async {
    await Printing.layoutPdf(
      name: 'laporan-keuangan-print.pdf',
      onLayout: (_) => _buildLaporanPdf(data, range),
    );
  }

  Future<Uint8List> _buildLaporanPdf(LaporanSummary data, DateTimeRange range) async {
    final document = pw.Document();
    final currency = _currencyFormatter();
    final dateRange = _formatRange(range);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Laporan Keuangan', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Periode: $dateRange'),
              pw.SizedBox(height: 24),
              pw.TableHelper.fromTextArray(
                headers: const ['Metric', 'Nilai'],
                data: [
                  ['Total Penjualan', currency.format(data.totalPenjualan)],
                  ['Total Pengeluaran', currency.format(data.totalPengeluaran)],
                  ['Laba Kotor', currency.format(data.labaKotor)],
                  ['Jumlah Transaksi', data.jumlahTransaksi.toString()],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)),
                cellPadding: const pw.EdgeInsets.all(8),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              ),
            ],
          );
        },
      ),
    );

    return document.save();
  }

  void _exportExcel(LaporanSummary data, DateTimeRange range) {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan'];
    excel.setDefaultSheet('Laporan');

    sheet.appendRow([TextCellValue('Laporan Keuangan')]);
    sheet.appendRow([TextCellValue('Periode'), TextCellValue(_formatRange(range))]);
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Metric'), TextCellValue('Nilai')]);
    sheet.appendRow([TextCellValue('Total Penjualan'), DoubleCellValue(data.totalPenjualan)]);
    sheet.appendRow([TextCellValue('Total Pengeluaran'), DoubleCellValue(data.totalPengeluaran)]);
    sheet.appendRow([TextCellValue('Laba Kotor'), DoubleCellValue(data.labaKotor)]);
    sheet.appendRow([TextCellValue('Jumlah Transaksi'), IntCellValue(data.jumlahTransaksi)]);

    final bytes = excel.encode();
    if (bytes == null) return;

    _downloadBytes(bytes, 'laporan-keuangan.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  void _exportCsv(LaporanSummary data, DateTimeRange range) {
    final rows = [
      ['Laporan Keuangan'],
      ['Periode', _formatRange(range)],
      <String>[],
      ['Metric', 'Nilai'],
      ['Total Penjualan', data.totalPenjualan.toStringAsFixed(0)],
      ['Total Pengeluaran', data.totalPengeluaran.toStringAsFixed(0)],
      ['Laba Kotor', data.labaKotor.toStringAsFixed(0)],
      ['Jumlah Transaksi', data.jumlahTransaksi.toString()],
    ];
    final csv = rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
    saveFileBytes(csv.codeUnits, 'laporan-keuangan.csv', 'text/csv;charset=utf-8');
  }

  void _downloadBytes(List<int> bytes, String filename, String mimeType) {
    saveFileBytes(bytes, filename, mimeType);
  }

  String _escapeCsv(String value) {
    if (!value.contains(',') && !value.contains('"') && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  NumberFormat _currencyFormatter() {
    return NumberFormat.currency(locale: AppLocale.formattingLocale, symbol: 'Rp ', decimalDigits: 0);
  }

  String _formatRange(DateTimeRange range) {
    final formatter = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);
    return '${formatter.format(range.start)} - ${formatter.format(range.end)}';
  }
}

class _QuickFiltersSection extends ConsumerWidget {
  const _QuickFiltersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(laporanFilterProvider);
    final items = [
      (ReportPeriod.hariIni, 'Hari Ini'),
      (ReportPeriod.kemarin, 'Kemarin'),
      (ReportPeriod.tujuhHari, '7 Hari'),
      (ReportPeriod.tigaPuluhHari, '30 Hari'),
      (ReportPeriod.bulanIni, 'Bulan Ini'),
      (ReportPeriod.bulanLalu, 'Bulan Lalu'),
      (ReportPeriod.tahunIni, 'Tahun Ini'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = filter.period == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(item.$2),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(laporanFilterProvider.notifier).state = ReportFilter(
                    period: item.$1,
                    dateRange: getDateRangeForPeriod(item.$1),
                  );
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CustomDateRangeSection extends ConsumerWidget {
  const _CustomDateRangeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(laporanFilterProvider);
    final isCustom = filter.period == ReportPeriod.custom;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Custom Date Range', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: filter.dateRange,
                      );
                      if (range != null) {
                        ref.read(laporanFilterProvider.notifier).state = ReportFilter(
                          period: ReportPeriod.custom,
                          dateRange: DateTimeRange(
                            start: range.start,
                            end: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(isCustom ? 'Ubah Tanggal' : 'Pilih Tanggal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportActionsCard extends StatelessWidget {
  const _ExportActionsCard({
    required this.onExportPdf,
    required this.onExportExcel,
    required this.onExportCsv,
    required this.onPrint,
  });

  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final VoidCallback onExportCsv;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: onExportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onExportExcel,
                icon: const Icon(Icons.table_chart),
                label: const Text('Export Excel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onExportCsv,
                icon: const Icon(Icons.description),
                label: const Text('Export CSV'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateRangeHeader extends StatelessWidget {
  const _DateRangeHeader({required this.range});

  final DateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.calendar_month_outlined),
        ),
        title: const Text(
          'Periode Laporan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${formatter.format(range.start)} - ${formatter.format(range.end)}'),
      ),
    );
  }
}

class _LaporanMetricsGrid extends StatelessWidget {
  const _LaporanMetricsGrid({required this.data});

  final LaporanSummary data;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final metrics = [
      _MetricItem(
        label: 'Total Penjualan',
        value: currency.format(data.totalPenjualan),
        icon: Icons.point_of_sale_outlined,
        color: AppTheme.secondary,
      ),
      _MetricItem(
        label: 'Total Pengeluaran',
        value: currency.format(data.totalPengeluaran),
        icon: Icons.payments_outlined,
        color: AppTheme.error,
      ),
      _MetricItem(
        label: 'Laba Kotor',
        value: currency.format(data.labaKotor),
        icon: Icons.trending_up_outlined,
        color: AppTheme.success,
      ),
      _MetricItem(
        label: 'Jumlah Transaksi',
        value: NumberFormat.decimalPattern(AppLocale.formattingLocale).format(data.jumlahTransaksi),
        icon: Icons.receipt_long_outlined,
        color: AppTheme.accent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            mainAxisExtent: 132,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) => _MetricCard(item: metrics[index]),
        );
      },
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: item.color.withValues(alpha: 0.12),
              foregroundColor: item.color,
              child: Icon(item.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductsSection extends StatelessWidget {
  const _TopProductsSection({required this.products});

  final List<Map<String, dynamic>> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Produk Terlaris (Top 5)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Text('${index + 1}'),
                ),
                title: Text(product['nama_produk'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${product['qty']} Terjual',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TransactionsSection extends ConsumerWidget {
  const _TransactionsSection({required this.transactions});

  final List<TransaksiModel> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    final currency = NumberFormat.currency(locale: AppLocale.formattingLocale, symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMM yyyy HH:mm', AppLocale.formattingLocale);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Detail Transaksi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text('${transactions.length} transaksi', style: const TextStyle(fontSize: 12)),
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final shortId = tx.id.length > 8 ? '#${tx.id.substring(0, 8).toUpperCase()}' : '#${tx.id}';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.receipt_rounded, size: 18),
                ),
                title: Text(
                  'Transaksi $shortId',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  dateFormatter.format(tx.tanggal),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(tx.total),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx.metodePembayaran.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                onTap: () => _showTransactionDetail(context, ref, tx),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, WidgetRef ref, TransaksiModel tx) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    if (isWide) {
      showDialog(
        context: context,
        builder: (_) => ProviderScope(
          parent: ProviderScope.containerOf(context),
          child: _TransactionDetailDialog(transaction: tx),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProviderScope(
          parent: ProviderScope.containerOf(context),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, controller) => _TransactionDetailSheet(
              transaction: tx,
              scrollController: controller,
            ),
          ),
        ),
      );
    }
  }
}

// ─── Transaction Detail Dialog (Web/Desktop) ────────────────────────────────

class _TransactionDetailDialog extends ConsumerWidget {
  const _TransactionDetailDialog({required this.transaction});

  final TransaksiModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(laporanTransactionDetailProvider(transaction.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailHeader(transaction: transaction, onClose: () => Navigator.of(context).pop()),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: detailAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Gagal memuat detail: $e')),
                  ),
                  data: (items) => _DetailBody(transaction: transaction, items: items),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction Detail Bottom Sheet (Mobile/Tablet) ────────────────────────

class _TransactionDetailSheet extends ConsumerWidget {
  const _TransactionDetailSheet({required this.transaction, required this.scrollController});

  final TransaksiModel transaction;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(laporanTransactionDetailProvider(transaction.id));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _DetailHeader(transaction: transaction, onClose: () => Navigator.of(context).pop()),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: detailAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Gagal memuat detail: $e')),
                ),
                data: (items) => _DetailBody(transaction: transaction, items: items),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Header ───────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.transaction, required this.onClose});

  final TransaksiModel transaction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortId = transaction.id.length > 8
        ? transaction.id.substring(0, 8).toUpperCase()
        : transaction.id.toUpperCase();
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm', AppLocale.formattingLocale);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaksi #$shortId',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  dateFormatter.format(transaction.tanggal),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Tutup',
          ),
        ],
      ),
    );
  }
}

// ─── Shared Body ─────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.transaction, required this.items});

  final TransaksiModel transaction;
  final List<Map<String, dynamic>> items;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _isPdfPrinting = false;
  bool _isThermalPrinting = false;

  Future<void> _onCetakPdf() async {
    setState(() => _isPdfPrinting = true);
    try {
      final receiptData = await ref.read(receiptServiceProvider).buildFromTransactionId(widget.transaction.id);
      final generator = ref.read(pdfReceiptGeneratorProvider);
      if (!mounted) return;
      await Printing.layoutPdf(
        name: '${receiptData.nomorTransaksi}_struk',
        onLayout: (_) async => generator.generate(receiptData),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is AppException ? e.message : 'Gagal membuka struk.')));
      }
    } finally {
      if (mounted) setState(() => _isPdfPrinting = false);
    }
  }

  Future<void> _onCetakThermal() async {
    final printerState = ref.read(thermalPrinterControllerProvider);
    if (!printerState.isConnected) {
      if (mounted) {
        Navigator.of(context).pop(); // close dialog
        context.push(AppRoutes.thermalPrinter);
      }
      return;
    }
    setState(() => _isThermalPrinting = true);
    try {
      final receiptData = await ref.read(receiptServiceProvider).buildFromTransactionId(widget.transaction.id);
      final success = await ref.read(thermalPrinterControllerProvider.notifier).printReceipt(receiptData);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Struk thermal berhasil dicetak!'), backgroundColor: Colors.green.shade700));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is AppException ? e.message : 'Gagal cetak thermal.'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _isThermalPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final items = widget.items;
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(locale: AppLocale.formattingLocale, symbol: 'Rp ', decimalDigits: 0);

    final totalQty = items.fold<int>(0, (sum, item) {
      return sum + ((item['qty'] as num?)?.toInt() ?? 0);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metode Pembayaran badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payment_rounded, size: 14, color: theme.colorScheme.secondary),
              const SizedBox(width: 6),
              Text(
                transaction.metodePembayaran.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Items section header
        Text(
          'Item Terjual',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
        const SizedBox(height: 10),

        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey),
                SizedBox(height: 8),
                Text('Tidak ada item ditemukan.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        else
          // Items table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text('Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      ),
                      const SizedBox(
                        width: 40,
                        child: Text('Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                      ),
                      const SizedBox(
                        width: 90,
                        child: Text('Harga', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.right),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text('Subtotal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Table rows
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final produk = item['produk'] as Map<String, dynamic>?;
                  final namaProduk = produk?['nama_produk'] as String? ?? '-';
                  final qty = (item['qty'] as num?)?.toInt() ?? 0;
                  final harga = (item['harga'] as num?)?.toDouble() ?? 0;
                  final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;
                  final isLast = i == items.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                namaProduk,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '$qty',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                currency.format(harga),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                currency.format(subtotal),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) const Divider(height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Summary footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Item', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  Text(
                    '$totalQty item',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    currency.format(transaction.total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // ── Cetak Ulang Actions ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_isPdfPrinting || _isThermalPrinting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: _onCetakPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
              const SizedBox(width: 8),
              if (!kIsWeb)
                ElevatedButton.icon(
                  onPressed: _onCetakThermal,
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Thermal'),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
