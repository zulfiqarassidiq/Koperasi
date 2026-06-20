import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/supabase_tables.dart';
import '../../services/supabase_service.dart';
import '../models/dashboard_stats_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

class DashboardRepository {
  const DashboardRepository(this._client);

  final SupabaseClient _client;

  /// Ambil statistik dashboard hanya untuk koperasi yang sedang login.
  Future<DashboardStatsModel> getStats({required String koperasiId}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);

    try {
      debugPrint('[DashboardRepository.getStats] Fetching stats for koperasi: $koperasiId');

      final products = await _client
          .from(SupabaseTables.produk)
          .select('id,stok')
          .eq('koperasi_id', koperasiId);

      final todayTransactions = await _client
          .from(SupabaseTables.transaksi)
          .select('id,total,tanggal')
          .eq('koperasi_id', koperasiId)
          .gte('tanggal', _dateOnly(todayStart))
          .lt('tanggal', _dateOnly(tomorrowStart));

      final monthlyTransactions = await _client
          .from(SupabaseTables.transaksi)
          .select('total,tanggal')
          .eq('koperasi_id', koperasiId)
          .gte('tanggal', _dateOnly(monthStart))
          .lt('tanggal', _dateOnly(nextMonthStart));

      final todayExpenses = await _client
          .from(SupabaseTables.pengeluaran)
          .select('jumlah,tanggal')
          .eq('koperasi_id', koperasiId)
          .gte('tanggal', _dateOnly(todayStart))
          .lt('tanggal', _dateOnly(tomorrowStart));

      final monthlyExpenses = await _client
          .from(SupabaseTables.pengeluaran)
          .select('jumlah,tanggal')
          .eq('koperasi_id', koperasiId)
          .gte('tanggal', _dateOnly(monthStart))
          .lt('tanggal', _dateOnly(nextMonthStart));

      return DashboardStatsModel(
        totalProducts: products.length,
        totalStock: _sumInt(products, 'stok'),
        todayTransactions: todayTransactions.length,
        todaySalesAmount: _sumNum(todayTransactions, 'total'),
        todayExpenses: _sumNum(todayExpenses, 'jumlah'),
        monthlySalesAmount: _sumNum(monthlyTransactions, 'total'),
        monthlyExpenseAmount: _sumNum(monthlyExpenses, 'jumlah'),
      );
    } on PostgrestException catch (error) {
      debugPrint('[DashboardRepository.getStats] ERROR: ${error.message}');
      throw AppException(error.message, code: error.code);
    }
  }

  int _sumInt(List<dynamic> rows, String key) {
    return rows.fold<int>(0, (total, row) {
      final value = row[key];
      if (value is int) return total + value;
      if (value is num) return total + value.toInt();
      return total;
    });
  }

  num _sumNum(List<dynamic> rows, String key) {
    return rows.fold<num>(0, (total, row) {
      final value = row[key];
      if (value is num) return total + value;
      return total;
    });
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
