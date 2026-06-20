import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaksi_model.dart';
import '../../domain/models/laporan_summary.dart';

class LaporanRepository {
  final SupabaseClient _client;

  LaporanRepository(this._client);

  /// Ambil ringkasan laporan hanya untuk koperasi yang sedang login.
  Future<LaporanSummary> getSummary({
    required String koperasiId,
    required DateTime start,
    required DateTime end,
  }) async {
    debugPrint('[LaporanRepository.getSummary] Fetching laporan for koperasi: $koperasiId');

    final transaksi = await _client
        .from('transaksi')
        .select()
        .eq('koperasi_id', koperasiId)
        .gte('tanggal', start.toIso8601String())
        .lte('tanggal', end.toIso8601String());

    final pengeluaran = await _client
        .from('pengeluaran')
        .select()
        .eq('koperasi_id', koperasiId)
        .gte('tanggal', start.toIso8601String())
        .lte('tanggal', end.toIso8601String());

    // Ambil detail item transaksi dari tabel yang benar: detail_transaksi
    // Join ke transaksi (untuk filter koperasi_id & tanggal) dan produk (untuk HPP)
    final transaksiItems = await _client
        .from('detail_transaksi')
        .select('qty, produk:produk_id(harga_jual, harga_beli), transaksi!inner(koperasi_id, tanggal)')
        .eq('transaksi.koperasi_id', koperasiId)
        .gte('transaksi.tanggal', start.toIso8601String())
        .lte('transaksi.tanggal', end.toIso8601String());

    double totalPenjualan = 0;
    double totalPengeluaran = 0;
    double labaKotor = 0;

    for (final item in transaksi) {
      totalPenjualan += (item['total'] as num?)?.toDouble() ?? 0;
    }

    for (final item in pengeluaran) {
      totalPengeluaran += (item['jumlah'] as num?)?.toDouble() ?? 0;
    }

    for (final item in transaksiItems) {
      final qty = (item['qty'] as num?)?.toDouble() ?? 0;
      final produk = item['produk'] as Map<String, dynamic>?;
      if (produk != null) {
        final hargaJual = (produk['harga_jual'] as num?)?.toDouble() ?? 0;
        final hargaBeli = (produk['harga_beli'] as num?)?.toDouble() ?? 0;
        labaKotor += (hargaJual - hargaBeli) * qty;
      }
    }

    debugPrint('[LaporanRepository.getSummary] transaksi: ${transaksi.length}, pengeluaran: ${pengeluaran.length}');

    return LaporanSummary(
      totalPenjualan: totalPenjualan,
      totalPengeluaran: totalPengeluaran,
      labaKotor: labaKotor,
      jumlahTransaksi: transaksi.length,
    );
  }

  Future<List<Map<String, dynamic>>> getTopProducts({
    required String koperasiId,
    required DateTime start,
    required DateTime end,
  }) async {
    // Produk terlaris dihitung dari detail_transaksi join transaksi dan produk
    final response = await _client
        .from('detail_transaksi')
        .select('produk_id, qty, produk:produk_id(nama_produk), transaksi!inner(koperasi_id, tanggal)')
        .eq('transaksi.koperasi_id', koperasiId)
        .gte('transaksi.tanggal', start.toIso8601String())
        .lte('transaksi.tanggal', end.toIso8601String());

    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final item in response) {
      final produkId = item['produk_id']?.toString() ?? 'unknown';
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final produk = item['produk'] as Map<String, dynamic>?;
      final namaProduk = produk?['nama_produk'] as String? ?? 'Unknown';

      if (aggregated.containsKey(produkId)) {
        aggregated[produkId]!['qty'] += qty;
      } else {
        aggregated[produkId] = {
          'id': produkId,
          'nama_produk': namaProduk,
          'qty': qty,
        };
      }
    }

    final list = aggregated.values.toList();
    list.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    return list.take(5).toList();
  }

  Future<List<TransaksiModel>> getTransactions({
    required String koperasiId,
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _client
        .from('transaksi')
        .select()
        .eq('koperasi_id', koperasiId)
        .gte('tanggal', start.toIso8601String())
        .lte('tanggal', end.toIso8601String())
        .order('tanggal', ascending: false);

    return response.map((json) => TransaksiModel.fromJson(json)).toList();
  }

  /// Ambil detail item-item dalam satu transaksi.
  /// Memfilter via transaksi.koperasi_id untuk memastikan isolasi data antar koperasi.
  Future<List<Map<String, dynamic>>> getTransactionDetail({
    required String transaksiId,
    required String koperasiId,
  }) async {
    debugPrint('[LaporanRepository.getTransactionDetail] transaksiId: $transaksiId, koperasiId: $koperasiId');

    // Inner join ke transaksi untuk memvalidasi koperasi_id (keamanan multi-tenant)
    final response = await _client
        .from('detail_transaksi')
        .select('id, qty, harga, subtotal, produk:produk_id(id, nama_produk), transaksi!inner(id, koperasi_id)')
        .eq('transaksi_id', transaksiId)
        .eq('transaksi.koperasi_id', koperasiId);

    debugPrint('[LaporanRepository.getTransactionDetail] items found: ${response.length}');
    return List<Map<String, dynamic>>.from(response);
  }
}
