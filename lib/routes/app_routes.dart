class AppRoutes {
  const AppRoutes._();

  // ─── Auth & Onboarding ───────────────────────────────────────────────────
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const changePassword = '/change-password';
  static const createKoperasi = '/create-koperasi';

  // ─── Main App ────────────────────────────────────────────────────────────
  static const dashboard = '/dashboard';
  static const produk = '/produk';
  static const produkCreate = '/produk/create';
  static const produkDetail = '/produk/:id';
  static const produkEdit = '/produk/:id/edit';
  static const kategori = '/kategori';
  static const stok = '/stok';
  static const stokCreate = '/stok/create';
  static const stokDetail = '/stok/:id';
  static const transaksi = '/transaksi';
  static const transaksiHistory = '/transaksi/history';
  static const transaksiDetail = '/transaksi/:id';
  static const pengeluaran = '/pengeluaran';
  static const laporan = '/laporan';
  static const settings = '/settings';
  static const userManagement = '/user-management';

  // ─── Path builders ───────────────────────────────────────────────────────
  static String produkDetailPath(String id) => '/produk/$id';
  static String produkEditPath(String id) => '/produk/$id/edit';
  static String stokDetailPath(String id) => '/stok/$id';
  static String transaksiDetailPath(String id) => '/transaksi/$id';
}
