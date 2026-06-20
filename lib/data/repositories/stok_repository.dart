import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/supabase_tables.dart';
import '../../services/supabase_service.dart';
import '../models/produk_model.dart';
import '../models/stok_masuk_model.dart';

final stokRepositoryProvider = Provider<StokRepository>((ref) {
  return StokRepository(ref.watch(supabaseClientProvider));
});

class StokFilter {
  const StokFilter({
    required this.koperasiId,
    this.search = '',
    this.produkId,
    this.tanggal,
  });

  final String koperasiId;
  final String search;
  final String? produkId;
  final DateTime? tanggal;
}

class StokRepository {
  const StokRepository(this._client);

  final SupabaseClient _client;

  /// Ambil semua stok masuk milik koperasi tertentu saja.
  Future<List<StokMasukModel>> findAll(StokFilter filter) async {
    try {
      final products = await findProductOptions(koperasiId: filter.koperasiId);
      final productNames = {
        for (final product in products) product.id: product.namaProduk,
      };

      var query = _client
          .from(SupabaseTables.stokMasuk)
          .select()
          .eq('koperasi_id', filter.koperasiId);

      if ((filter.produkId ?? '').isNotEmpty) {
        query = query.eq('produk_id', filter.produkId!);
      }

      if (filter.tanggal != null) {
        final start = _dateOnly(filter.tanggal!);
        final end = _dateOnly(filter.tanggal!.add(const Duration(days: 1)));
        query = query.gte('tanggal', start).lt('tanggal', end);
      }

      final response = await query.order('tanggal', ascending: false);
      final term = filter.search.trim().toLowerCase();

      return response.map((row) {
        final stock = StokMasukModel.fromJson(row);
        return stock.copyWith(
          namaProduk: productNames[stock.produkId] ?? '-',
        );
      }).where((stock) {
        if (term.isEmpty) return true;
        final productName = stock.namaProduk?.toLowerCase() ?? '';
        final notes = stock.keterangan?.toLowerCase() ?? '';
        return productName.contains(term) || notes.contains(term);
      }).toList();
    } on PostgrestException catch (error) {
      debugPrint('[StokRepository.findAll] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<StokMasukModel> findById(String id) async {
    try {
      final response = await _client
          .from(SupabaseTables.stokMasuk)
          .select()
          .eq('id', id)
          .single();
      return StokMasukModel.fromJson(response);
    } on PostgrestException catch (error) {
      debugPrint('[StokRepository.findById] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  /// Ambil daftar produk hanya milik koperasi ini sebagai opsi dropdown.
  Future<List<ProdukModel>> findProductOptions({
    required String koperasiId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseTables.produk)
          .select('id,nama_produk,stok')
          .eq('koperasi_id', koperasiId)
          .order('nama_produk');

      return response.map((row) => ProdukModel.fromJson(row)).toList();
    } on PostgrestException catch (error) {
      debugPrint('[StokRepository.findProductOptions] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  /// Tambah stok, otomatis menyimpan koperasi_id.
  Future<void> addStock({
    required StokMasukModel stock,
    required String koperasiId,
  }) async {
    _validate(stock);

    try {
      debugPrint('[StokRepository.addStock] Adding stock for produk: ${stock.produkId}, koperasi: $koperasiId');
      final product = await _client
          .from(SupabaseTables.produk)
          .select('stok')
          .eq('id', stock.produkId)
          .single();
      final currentStock = product['stok'] as int? ?? 0;

      await _client.from(SupabaseTables.stokMasuk).insert({
        ...stock.toInsertJson(),
        'koperasi_id': koperasiId,
      });
      await _client.from(SupabaseTables.produk).update({
        'stok': currentStock + stock.qty,
      }).eq('id', stock.produkId);
      debugPrint('[StokRepository.addStock] SUCCESS');
    } on PostgrestException catch (error) {
      debugPrint('[StokRepository.addStock] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  void _validate(StokMasukModel stock) {
    if (stock.produkId.trim().isEmpty) {
      throw const AppException('Produk wajib dipilih.');
    }

    if (stock.qty <= 0) {
      throw const AppException('Qty harus lebih dari 0.');
    }
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
