class SupabaseTables {
  const SupabaseTables._();

  // Auth & user management tables
  static const profiles = 'profiles';
  static const koperasi = 'koperasi';
  static const userInvites = 'user_invites';

  // Business tables
  static const kategoriProduk = 'kategori_produk';
  static const produk = 'produk';
  static const stokMasuk = 'stok_masuk';
  static const transaksi = 'transaksi';
  static const detailTransaksi = 'detail_transaksi';
  static const pengeluaran = 'pengeluaran';
}
