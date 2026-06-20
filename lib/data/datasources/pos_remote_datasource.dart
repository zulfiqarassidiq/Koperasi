import '../../core/network/supabase_tables.dart';
import 'supabase_datasource.dart';

class PosRemoteDatasource extends SupabaseDatasource {
  const PosRemoteDatasource(super.client);

  Future<List<Map<String, dynamic>>> getKategoriProduk() async {
    return client
        .from(SupabaseTables.kategoriProduk)
        .select()
        .order('nama_kategori');
  }

  Future<List<Map<String, dynamic>>> getProduk() async {
    return client.from(SupabaseTables.produk).select().order('nama_produk');
  }

  Future<List<Map<String, dynamic>>> getStokMasuk() async {
    return client
        .from(SupabaseTables.stokMasuk)
        .select()
        .order('tanggal', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getTransaksi() async {
    return client
        .from(SupabaseTables.transaksi)
        .select()
        .order('tanggal', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getDetailTransaksi(
      String transaksiId) async {
    return client
        .from(SupabaseTables.detailTransaksi)
        .select()
        .eq('transaksi_id', transaksiId);
  }

  Future<List<Map<String, dynamic>>> getPengeluaran() async {
    return client
        .from(SupabaseTables.pengeluaran)
        .select()
        .order('tanggal', ascending: false);
  }
}
