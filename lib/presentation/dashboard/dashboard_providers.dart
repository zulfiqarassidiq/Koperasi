import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dashboard_stats_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../auth/auth_providers.dart';

final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStatsModel>((ref) async {
  // Filter dashboard berdasarkan koperasi user yang sedang login
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';

  if (koperasiId.isEmpty) {
    return const DashboardStatsModel(
      totalProducts: 0,
      totalStock: 0,
      todayTransactions: 0,
      todaySalesAmount: 0,
      todayExpenses: 0,
      monthlySalesAmount: 0,
      monthlyExpenseAmount: 0,
    );
  }

  return ref.watch(dashboardRepositoryProvider).getStats(koperasiId: koperasiId);
});
