import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/supabase_service.dart';
import '../datasources/pos_remote_datasource.dart';

final posRemoteDatasourceProvider = Provider<PosRemoteDatasource>((ref) {
  return PosRemoteDatasource(ref.watch(supabaseClientProvider));
});

final posRepositoryProvider = Provider<PosRepository>((ref) {
  return PosRepository(ref.watch(posRemoteDatasourceProvider));
});

class PosRepository {
  const PosRepository(this._datasource);

  final PosRemoteDatasource _datasource;

  Future<List<Map<String, dynamic>>> kategoriProduk() =>
      _datasource.getKategoriProduk();
  Future<List<Map<String, dynamic>>> produk() => _datasource.getProduk();
  Future<List<Map<String, dynamic>>> stokMasuk() => _datasource.getStokMasuk();
  Future<List<Map<String, dynamic>>> transaksi() => _datasource.getTransaksi();
  Future<List<Map<String, dynamic>>> detailTransaksi(String transaksiId) =>
      _datasource.getDetailTransaksi(transaksiId);
  Future<List<Map<String, dynamic>>> pengeluaran() =>
      _datasource.getPengeluaran();
}
