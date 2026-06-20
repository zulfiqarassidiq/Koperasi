import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/supabase_tables.dart';
import '../../services/supabase_service.dart';
import '../models/kategori_produk_model.dart';

final kategoriRepositoryProvider = Provider<KategoriRepository>((ref) {
  return KategoriRepository(ref.watch(supabaseClientProvider));
});

class KategoriRepository {
  const KategoriRepository(this._client);

  final SupabaseClient _client;

  /// Ambil semua kategori milik koperasi tertentu saja.
  Future<List<KategoriProdukModel>> findAll({
    required String koperasiId,
    String search = '',
  }) async {
    try {
      var query = _client
          .from(SupabaseTables.kategoriProduk)
          .select()
          .eq('koperasi_id', koperasiId);

      final response = search.trim().isEmpty
          ? await query.order('nama_kategori')
          : await query
              .ilike('nama_kategori', '%${search.trim()}%')
              .order('nama_kategori');

      return response.map((row) => KategoriProdukModel.fromJson(row)).toList();
    } on PostgrestException catch (error) {
      debugPrint('[KategoriRepository.findAll] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  /// Buat kategori baru, otomatis menyimpan koperasi_id.
  Future<void> create({
    required String namaKategori,
    required String koperasiId,
  }) async {
    final cleanName = _validateName(namaKategori);

    try {
      debugPrint('[KategoriRepository.create] Inserting kategori: $cleanName for koperasi: $koperasiId');
      await _client.from(SupabaseTables.kategoriProduk).insert({
        'nama_kategori': cleanName,
        'koperasi_id': koperasiId,
      });
      debugPrint('[KategoriRepository.create] SUCCESS');
    } on PostgrestException catch (error) {
      debugPrint('[KategoriRepository.create] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<void> update({
    required String id,
    required String namaKategori,
  }) async {
    final cleanName = _validateName(namaKategori);

    try {
      await _client.from(SupabaseTables.kategoriProduk).update({
        'nama_kategori': cleanName,
      }).eq('id', id);
    } on PostgrestException catch (error) {
      debugPrint('[KategoriRepository.update] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client
          .from(SupabaseTables.kategoriProduk)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (error) {
      debugPrint('[KategoriRepository.delete] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  String _validateName(String value) {
    final cleanName = value.trim();

    if (cleanName.isEmpty) {
      throw const AppException('Nama kategori wajib diisi.');
    }

    if (cleanName.length > 80) {
      throw const AppException('Nama kategori maksimal 80 karakter.');
    }

    return cleanName;
  }
}
