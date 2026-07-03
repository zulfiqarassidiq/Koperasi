import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/supabase_tables.dart';
import '../../services/supabase_service.dart';
import '../models/kategori_produk_model.dart';
import '../models/produk_model.dart';

final produkRepositoryProvider = Provider<ProdukRepository>((ref) {
  return ProdukRepository(ref.watch(supabaseClientProvider));
});

class ProdukRepository {
  const ProdukRepository(this._client);

  final SupabaseClient _client;

  /// Ambil semua produk milik koperasi tertentu saja.
  Future<List<ProdukModel>> findAll({
    required String koperasiId,
    String search = '',
  }) async {
    try {
      final categories = await findCategories(koperasiId: koperasiId);
      final categoryNames = {
        for (final category in categories) category.id: category.namaKategori,
      };

      var query = _client
          .from(SupabaseTables.produk)
          .select()
          .eq('koperasi_id', koperasiId);

      final term = search.trim();
      final response = term.isEmpty
          ? await query.order('created_at', ascending: false)
          : await query
              .or('nama_produk.ilike.%$term%,kode_produk.ilike.%$term%')
              .order('created_at', ascending: false);

      return response.map((row) {
        final product = ProdukModel.fromJson(row);
        return product.copyWith(
          namaKategori: categoryNames[product.kategoriId] ?? '-',
        );
      }).toList();
    } on PostgrestException catch (error) {
      debugPrint('[ProdukRepository.findAll] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<ProdukModel> findById(String id) async {
    try {
      final response = await _client
          .from(SupabaseTables.produk)
          .select()
          .eq('id', id)
          .single();
      return ProdukModel.fromJson(response);
    } on PostgrestException catch (error) {
      debugPrint('[ProdukRepository.findById] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  /// Generate kode produk nomor urut berikutnya untuk koperasi ini.
  ///
  /// Format: PRD-000001, PRD-000002, PRD-000003, dst.
  /// Kode di-scope per koperasi_id:
  ///   - Koperasi A: PRD-000001 ✅
  ///   - Koperasi B: PRD-000001 ✅  (constraint DB: UNIQUE(koperasi_id, kode_produk))
  ///   - Koperasi A: PRD-000001 lagi ✗ ditolak oleh DB
  Future<String> generateKodeProduk({required String koperasiId}) async {
    try {
      // Query hanya kode produk milik koperasi ini dengan format PRD-XXXXXX
      final response = await _client
          .from(SupabaseTables.produk)
          .select('kode_produk')
          .eq('koperasi_id', koperasiId)
          .like('kode_produk', 'PRD-%');

      int maxNumber = 0;
      for (final row in response) {
        final kode = row['kode_produk'] as String? ?? '';
        final parts = kode.split('-');
        if (parts.length == 2) {
          final number = int.tryParse(parts[1]);
          if (number != null && number > maxNumber) {
            maxNumber = number;
          }
        }
      }

      final nextNumber = maxNumber + 1;
      final kode = 'PRD-${nextNumber.toString().padLeft(6, '0')}';
      debugPrint('[ProdukRepository.generateKodeProduk] Generated: $kode for koperasi: $koperasiId');
      return kode;
    } on PostgrestException catch (error) {
      debugPrint('[ProdukRepository.generateKodeProduk] ERROR: ${error.message}');
      throw AppException(error.message, code: error.code);
    }
  }

  /// Ambil kategori hanya milik koperasi ini.
  Future<List<KategoriProdukModel>> findCategories({
    required String koperasiId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseTables.kategoriProduk)
          .select()
          .eq('koperasi_id', koperasiId)
          .order('nama_kategori');

      return response.map((row) => KategoriProdukModel.fromJson(row)).toList();
    } on PostgrestException catch (error) {
      debugPrint('[ProdukRepository.findCategories] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<void> create({
    required ProdukModel product,
    required String koperasiId,
  }) async {
    _validate(product);

    try {
      debugPrint('[ProdukRepository.create] Inserting produk: ${product.namaProduk} for koperasi: $koperasiId');
      await _client
          .from(SupabaseTables.produk)
          .insert(product.toInsertJson(koperasiId: koperasiId));
      debugPrint('[ProdukRepository.create] SUCCESS');
    } on PostgrestException catch (error) {
      debugPrint('[ProdukRepository.create] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<void> updateProduct({
    required ProdukModel product,
    required String koperasiId,
  }) async {
    _validate(product);

    try {
      debugPrint('[ProdukRepository.updateProduct] Updating produk: ${product.id}');
      await _client
          .from(SupabaseTables.produk)
          .update(product.toInsertJson(koperasiId: koperasiId))
          .eq('id', product.id);
      debugPrint('[ProdukRepository.updateProduct] SUCCESS');
    } on PostgrestException catch (error) {
      debugPrint('[ProdukRepository.updateProduct] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from(SupabaseTables.produk).delete().eq('id', id);
    } on PostgrestException catch (error) {
      debugPrint('[ProdukRepository.delete] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  void _validate(ProdukModel product) {
    if ((product.kategoriId ?? '').trim().isEmpty) {
      throw const AppException('Kategori wajib dipilih.');
    }
    if (product.kodeProduk.trim().isEmpty) {
      throw const AppException('Kode produk wajib diisi.');
    }
    if (product.namaProduk.trim().isEmpty) {
      throw const AppException('Nama produk wajib diisi.');
    }
    if (product.hargaBeli < 0) {
      throw const AppException('Harga beli tidak boleh negatif.');
    }
    if (product.hargaJual < 0) {
      throw const AppException('Harga jual tidak boleh negatif.');
    }
    if (product.stok < 0) {
      throw const AppException('Stok tidak boleh negatif.');
    }
  }
}
