import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/supabase_tables.dart';
import '../../services/supabase_service.dart';
import '../models/cart_item_model.dart';
import '../models/produk_model.dart';
import '../models/transaksi_detail_item_model.dart';
import '../models/transaksi_model.dart';

final transaksiRepositoryProvider = Provider<TransaksiRepository>((ref) {
  return TransaksiRepository(ref.watch(supabaseClientProvider));
});

class TransaksiRepository {
  const TransaksiRepository(this._client);

  final SupabaseClient _client;

  /// Cari produk hanya milik koperasi ini untuk keperluan kasir.
  Future<List<ProdukModel>> searchProducts({
    required String koperasiId,
    String search = '',
  }) async {
    try {
      var query = _client
          .from(SupabaseTables.produk)
          .select('id,nama_produk,harga_jual,stok')
          .eq('koperasi_id', koperasiId);

      final term = search.trim();
      if (term.isNotEmpty) {
        query = query.ilike('nama_produk', '%$term%');
      }

      final response = await query.order('nama_produk').limit(30);
      return response.map((row) => ProdukModel.fromJson(row)).toList();
    } on PostgrestException catch (error) {
      debugPrint('[TransaksiRepository.searchProducts] ERROR: ${error.message}');
      throw AppException(error.message, code: error.code);
    }
  }

  /// Ambil riwayat transaksi hanya milik koperasi ini.
  Future<List<TransaksiModel>> findHistory({
    required String koperasiId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseTables.transaksi)
          .select()
          .eq('koperasi_id', koperasiId)
          .order('tanggal', ascending: false);

      return response.map((row) => TransaksiModel.fromJson(row)).toList();
    } on PostgrestException catch (error) {
      debugPrint('[TransaksiRepository.findHistory] ERROR: ${error.message}');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<TransaksiModel> findTransactionById(String id) async {
    try {
      final response = await _client
          .from(SupabaseTables.transaksi)
          .select()
          .eq('id', id)
          .single();

      return TransaksiModel.fromJson(response);
    } on PostgrestException catch (error) {
      debugPrint('[TransaksiRepository.findTransactionById] ERROR: ${error.message}');
      throw AppException(error.message, code: error.code);
    }
  }

  Future<List<TransaksiDetailItemModel>> findDetails(
      String transactionId) async {
    try {
      final response = await _client
          .from(SupabaseTables.detailTransaksi)
          .select()
          .eq('transaksi_id', transactionId);

      // Ambil nama produk dari kolom produk langsung
      final List<TransaksiDetailItemModel> details = [];
      for (final row in response) {
        final detail = TransaksiDetailItemModel.fromJson(row);
        String namaProduk = '-';
        try {
          final produkRow = await _client
              .from(SupabaseTables.produk)
              .select('nama_produk')
              .eq('id', detail.produkId)
              .maybeSingle();
          namaProduk = produkRow?['nama_produk'] as String? ?? '-';
        } catch (_) {}
        details.add(TransaksiDetailItemModel(
          id: detail.id,
          transaksiId: detail.transaksiId,
          produkId: detail.produkId,
          qty: detail.qty,
          harga: detail.harga,
          subtotal: detail.subtotal,
          namaProduk: namaProduk,
        ));
      }
      return details;
    } on PostgrestException catch (error) {
      debugPrint('[TransaksiRepository.findDetails] ERROR: ${error.message}');
      throw AppException(error.message, code: error.code);
    }
  }

  /// Checkout transaksi, otomatis menyimpan koperasi_id.
  Future<TransaksiModel> checkout({
    required List<CartItemModel> items,
    required String paymentMethod,
    required String koperasiId,
  }) async {
    if (items.isEmpty) {
      throw const AppException('Keranjang tidak boleh kosong.');
    }

    final cleanPaymentMethod = paymentMethod.trim();
    if (cleanPaymentMethod.isEmpty) {
      throw const AppException('Metode pembayaran wajib dipilih.');
    }

    for (final item in items) {
      if (item.qty <= 0) {
        throw const AppException('Qty harus lebih dari 0.');
      }
    }

    String? transactionId;
    final originalStocks = <String, int>{};

    try {
      final freshProducts = <String, ProdukModel>{};

      for (final item in items) {
        final product = await _findProductForCheckout(item.product.id);
        freshProducts[product.id] = product;
        originalStocks[product.id] = product.stok;

        if (item.qty > product.stok) {
          throw AppException(
            'Stok ${product.namaProduk} tidak cukup. Tersedia ${product.stok}.',
          );
        }
      }

      final total = items.fold<num>(0, (sum, item) => sum + item.subtotal);
      debugPrint('[TransaksiRepository.checkout] Creating transaksi for koperasi: $koperasiId');
      final transaction = await _client
          .from(SupabaseTables.transaksi)
          .insert({
            'koperasi_id': koperasiId,
            'tanggal': _dateOnly(DateTime.now()),
            'total': total,
            'metode_pembayaran': cleanPaymentMethod,
          })
          .select()
          .single();

      final createdTransaction = TransaksiModel.fromJson(transaction);
      transactionId = createdTransaction.id;

      final detailRows = items.map((item) {
        return {
          'transaksi_id': transactionId,
          'produk_id': item.product.id,
          'qty': item.qty,
          'harga': item.unitPrice,
          'subtotal': item.subtotal,
        };
      }).toList();

      await _client.from(SupabaseTables.detailTransaksi).insert(detailRows);

      for (final item in items) {
        final product = freshProducts[item.product.id];
        if (product == null) {
          throw const AppException('Produk tidak ditemukan.');
        }

        await _client.from(SupabaseTables.produk).update({
          'stok': product.stok - item.qty,
        }).eq('id', product.id);
      }

      debugPrint('[TransaksiRepository.checkout] SUCCESS, id: $transactionId');
      return createdTransaction;
    } on AppException {
      await _rollback(transactionId, originalStocks);
      rethrow;
    } on PostgrestException catch (error) {
      await _rollback(transactionId, originalStocks);
      debugPrint('[TransaksiRepository.checkout] ERROR: ${error.message}');
      throw AppException(error.message, code: error.code);
    } catch (_) {
      await _rollback(transactionId, originalStocks);
      throw const AppException('Checkout gagal. Silakan coba lagi.');
    }
  }

  Future<ProdukModel> _findProductForCheckout(String id) async {
    try {
      final response = await _client
          .from(SupabaseTables.produk)
          .select('id,nama_produk,harga_jual,stok')
          .eq('id', id)
          .single();

      return ProdukModel.fromJson(response);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST116') {
        throw const AppException('Produk tidak ditemukan.');
      }
      rethrow;
    }
  }

  Future<void> _rollback(
    String? transactionId,
    Map<String, int> originalStocks,
  ) async {
    for (final entry in originalStocks.entries) {
      try {
        await _client.from(SupabaseTables.produk).update({
          'stok': entry.value,
        }).eq('id', entry.key);
      } catch (_) {}
    }

    if (transactionId == null) return;

    try {
      await _client
          .from(SupabaseTables.detailTransaksi)
          .delete()
          .eq('transaksi_id', transactionId);
    } catch (_) {}

    try {
      await _client
          .from(SupabaseTables.transaksi)
          .delete()
          .eq('id', transactionId);
    } catch (_) {}
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
