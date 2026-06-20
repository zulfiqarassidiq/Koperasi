class DashboardStatsModel {
  const DashboardStatsModel({
    required this.totalProducts,
    required this.totalStock,
    required this.todayTransactions,
    required this.todaySalesAmount,
    required this.todayExpenses,
    required this.monthlySalesAmount,
    required this.monthlyExpenseAmount,
  });

  final int totalProducts;
  final int totalStock;
  final int todayTransactions;
  final num todaySalesAmount;
  final num todayExpenses;
  final num monthlySalesAmount;
  final num monthlyExpenseAmount;

  bool get isEmpty {
    return totalProducts == 0 &&
        totalStock == 0 &&
        todayTransactions == 0 &&
        todaySalesAmount == 0 &&
        todayExpenses == 0 &&
        monthlySalesAmount == 0 &&
        monthlyExpenseAmount == 0;
  }
}
