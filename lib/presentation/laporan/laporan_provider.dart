import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/transaksi_model.dart';
import '../../data/repositories/laporan_repository.dart';
import '../../domain/models/laporan_summary.dart';
import '../../services/supabase_service.dart';
import '../auth/auth_providers.dart';

enum ReportPeriod {
  hariIni,
  kemarin,
  tujuhHari,
  tigaPuluhHari,
  bulanIni,
  bulanLalu,
  tahunIni,
  custom,
}

class ReportFilter {
  final ReportPeriod period;
  final DateTimeRange dateRange;

  const ReportFilter({
    required this.period,
    required this.dateRange,
  });
}

DateTimeRange getDateRangeForPeriod(ReportPeriod period) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

  switch (period) {
    case ReportPeriod.hariIni:
      return DateTimeRange(start: todayStart, end: todayEnd);
    case ReportPeriod.kemarin:
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final yesterdayEnd = DateTime(yesterdayStart.year, yesterdayStart.month, yesterdayStart.day, 23, 59, 59);
      return DateTimeRange(start: yesterdayStart, end: yesterdayEnd);
    case ReportPeriod.tujuhHari:
      final sevenDaysAgo = todayStart.subtract(const Duration(days: 6));
      return DateTimeRange(start: sevenDaysAgo, end: todayEnd);
    case ReportPeriod.tigaPuluhHari:
      final thirtyDaysAgo = todayStart.subtract(const Duration(days: 29));
      return DateTimeRange(start: thirtyDaysAgo, end: todayEnd);
    case ReportPeriod.bulanIni:
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      return DateTimeRange(start: firstDayOfMonth, end: todayEnd);
    case ReportPeriod.bulanLalu:
      final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
      final lastDayOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
      return DateTimeRange(start: firstDayOfLastMonth, end: lastDayOfLastMonth);
    case ReportPeriod.tahunIni:
      final firstDayOfYear = DateTime(now.year, 1, 1);
      return DateTimeRange(start: firstDayOfYear, end: todayEnd);
    case ReportPeriod.custom:
      return DateTimeRange(start: todayStart, end: todayEnd);
  }
}

final laporanFilterProvider = StateProvider<ReportFilter>((ref) {
  return ReportFilter(
    period: ReportPeriod.hariIni,
    dateRange: getDateRangeForPeriod(ReportPeriod.hariIni),
  );
});

final laporanRepositoryProvider = Provider<LaporanRepository>((ref) {
  return LaporanRepository(
    ref.watch(supabaseClientProvider),
  );
});

final laporanSummaryProvider = FutureProvider<LaporanSummary>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';

  if (koperasiId.isEmpty) {
    return const LaporanSummary(
      totalPenjualan: 0,
      totalPengeluaran: 0,
      labaKotor: 0,
      jumlahTransaksi: 0,
    );
  }

  final repository = ref.read(laporanRepositoryProvider);
  final filter = ref.watch(laporanFilterProvider);

  return repository.getSummary(
    koperasiId: koperasiId,
    start: filter.dateRange.start,
    end: filter.dateRange.end,
  );
});

final laporanTopProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';

  if (koperasiId.isEmpty) return [];

  final repository = ref.read(laporanRepositoryProvider);
  final filter = ref.watch(laporanFilterProvider);

  return repository.getTopProducts(
    koperasiId: koperasiId,
    start: filter.dateRange.start,
    end: filter.dateRange.end,
  );
});

final laporanTransactionsProvider = FutureProvider<List<TransaksiModel>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';

  if (koperasiId.isEmpty) return [];

  final repository = ref.read(laporanRepositoryProvider);
  final filter = ref.watch(laporanFilterProvider);

  return repository.getTransactions(
    koperasiId: koperasiId,
    start: filter.dateRange.start,
    end: filter.dateRange.end,
  );
});

/// Provider family untuk detail item-item dalam satu transaksi.
/// Parameter: transaksiId (String)
final laporanTransactionDetailProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, transaksiId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';

  if (koperasiId.isEmpty || transaksiId.isEmpty) return [];

  final repository = ref.read(laporanRepositoryProvider);
  return repository.getTransactionDetail(
    transaksiId: transaksiId,
    koperasiId: koperasiId,
  );
});
