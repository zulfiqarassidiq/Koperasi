import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/supabase_tables.dart';
import '../../services/supabase_service.dart';
import '../models/pengeluaran_model.dart';

final pengeluaranRepositoryProvider = Provider<PengeluaranRepository>((ref) {
  return PengeluaranRepository(ref.watch(supabaseClientProvider));
});

class PengeluaranRepository {
  const PengeluaranRepository(this._client);

  final SupabaseClient _client;

  /// Ambil semua pengeluaran milik koperasi tertentu saja.
  Future<List<PengeluaranModel>> findAll({
    required String koperasiId,
    String search = '',
  }) async {
    try {
      var query = _client
          .from(SupabaseTables.pengeluaran)
          .select()
          .eq('koperasi_id', koperasiId);

      final term = search.trim();
      if (term.isNotEmpty) {
        query = query.ilike('keterangan', '%$term%');
      }

      final response = await query.order('tanggal', ascending: false);

      return response.map((row) => PengeluaranModel.fromJson(row)).toList();
    } on PostgrestException catch (error) {
      debugPrint('[PengeluaranRepository.findAll] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  /// Catat pengeluaran, otomatis menyimpan koperasi_id.
  Future<void> create({
    required String keterangan,
    required num jumlah,
    required String koperasiId,
    DateTime? tanggal,
  }) async {
    final cleanKeterangan = keterangan.trim();
    if (cleanKeterangan.isEmpty) {
      throw const AppException('Keterangan tidak boleh kosong');
    }
    if (jumlah <= 0) {
      throw const AppException('Jumlah harus lebih dari 0');
    }

    final data = {
      'keterangan': cleanKeterangan,
      'jumlah': jumlah,
      'koperasi_id': koperasiId,
      'tanggal': _dateOnly(tanggal ?? DateTime.now()),
    };

    try {
      debugPrint('[PengeluaranRepository.create] Inserting pengeluaran for koperasi: $koperasiId');
      await _client.from(SupabaseTables.pengeluaran).insert(data);
      debugPrint('[PengeluaranRepository.create] SUCCESS');
    } on PostgrestException catch (error) {
      debugPrint('[PengeluaranRepository.create] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from(SupabaseTables.pengeluaran).delete().eq('id', id);
    } on PostgrestException catch (error) {
      debugPrint('[PengeluaranRepository.delete] ERROR: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
