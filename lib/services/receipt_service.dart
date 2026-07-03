import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/app_exception.dart';
import '../core/network/supabase_tables.dart';
import '../data/models/cart_item_model.dart';
import '../data/models/koperasi_model.dart';
import '../data/models/user_profile_model.dart';
import '../domain/models/receipt_data.dart';
import '../domain/models/receipt_item.dart';
import 'supabase_service.dart';

final receiptServiceProvider = Provider<ReceiptService>((ref) {
  return ReceiptService(ref.watch(supabaseClientProvider));
});

/// Service bertanggung jawab membangun [ReceiptData] dari berbagai sumber.
///
/// [ReceiptService] adalah satu-satunya tempat yang tahu cara memetakan
/// data dari database / cart ke [ReceiptData]. PDF generator dan ESC/POS
/// formatter tidak perlu tahu tentang Supabase.
///
/// Dua entry point:
/// 1. [buildFromCart]          — dipanggil sesaat setelah checkout berhasil
///                               (data sudah ada di memory, tidak perlu re-fetch)
/// 2. [buildFromTransactionId] — dipanggil untuk reprint dari riwayat transaksi
class ReceiptService {
  const ReceiptService(this._client);

  final SupabaseClient _client;

  // ─── Entry Point 1: Bangun dari data cart yang sudah ada di memori ─────────
  /// Membangun [ReceiptData] langsung dari [CartState] items.
  ///
  /// Tidak melakukan network call karena semua data sudah tersedia:
  /// - [cartItems]         → baris item dengan nama produk & harga
  /// - [profile]           → nama kasir
  /// - [koperasi]          → nama, alamat, telepon koperasi (multi-koperasi safe)
  /// - [transactionId]     → ID numerik dari database, diformat ke "TRX000001"
  /// - [tanggal]           → timestamp transaksi
  /// - [paymentMethod]     → metode pembayaran
  ReceiptData buildFromCart({
    required List<CartItemModel> cartItems,
    required UserProfileModel profile,
    required KoperasiModel koperasi,
    required String transactionId,
    required DateTime tanggal,
    required String paymentMethod,
  }) {
    final items = cartItems
        .map(
          (e) => ReceiptItem(
            namaProduk: e.product.namaProduk,
            qty: e.qty,
            hargaSatuan: e.unitPrice,
            subtotal: e.subtotal,
          ),
        )
        .toList();

    return ReceiptData(
      nomorTransaksi: _formatTransactionNumber(transactionId),
      tanggal: tanggal,
      namaKasir: profile.nama,
      metodePembayaran: paymentMethod,
      namaKoperasi: koperasi.namaKoperasi,
      alamatKoperasi:
          (koperasi.alamat?.isNotEmpty ?? false) ? koperasi.alamat : null,
      teleponKoperasi:
          (koperasi.telepon?.isNotEmpty ?? false) ? koperasi.telepon : null,
      items: items,
    );
  }

  // ─── Entry Point 2: Bangun dari ID transaksi (reprint dari history) ────────
  /// Membangun [ReceiptData] dengan fetch lengkap dari Supabase.
  ///
  /// Digunakan untuk reprint dari halaman riwayat transaksi.
  /// Urutan fetch:
  /// 1. Ambil data transaksi (total, metode, tanggal, koperasi_id, kasir_id)
  /// 2. Ambil detail item (join produk untuk nama)
  /// 3. Ambil profil kasir
  /// 4. Ambil data koperasi
  Future<ReceiptData> buildFromTransactionId(String transactionId) async {
    try {
      // 1. Transaksi
      final txRow = await _client
          .from(SupabaseTables.transaksi)
          .select()
          .eq('id', transactionId)
          .single();

      final koperasiId = txRow['koperasi_id'] as String? ?? '';
      final kasirId = txRow['kasir_id'] as String? ?? '';
      final metodePembayaran =
          txRow['metode_pembayaran'] as String? ?? '-';
      final tanggal =
          DateTime.tryParse(txRow['tanggal']?.toString() ?? '') ??
              DateTime.now();

      // 2. Detail item (dengan nama produk)
      final detailRows = await _client
          .from(SupabaseTables.detailTransaksi)
          .select()
          .eq('transaksi_id', transactionId);

      final items = <ReceiptItem>[];
      for (final row in detailRows) {
        String namaProduk = '-';
        try {
          final produkRow = await _client
              .from(SupabaseTables.produk)
              .select('nama_produk')
              .eq('id', row['produk_id'].toString())
              .maybeSingle();
          namaProduk = produkRow?['nama_produk'] as String? ?? '-';
        } catch (_) {}

        items.add(ReceiptItem(
          namaProduk: namaProduk,
          qty: row['qty'] as int? ?? 0,
          hargaSatuan: row['harga'] as num? ?? 0,
          subtotal: row['subtotal'] as num? ?? 0,
        ));
      }

      // 3. Profil kasir (opsional — graceful fallback jika tidak ditemukan)
      String namaKasir = '-';
      if (kasirId.isNotEmpty) {
        try {
          final kasirRow = await _client
              .from(SupabaseTables.profiles)
              .select('nama')
              .eq('id', kasirId)
              .maybeSingle();
          namaKasir = kasirRow?['nama'] as String? ?? '-';
        } catch (_) {}
      }

      // 4. Data koperasi (opsional — tidak memblok jika gagal)
      String namaKoperasi = 'Koperasi';
      String? alamat;
      String? telepon;
      if (koperasiId.isNotEmpty) {
        try {
          final koperasiRow = await _client
              .from(SupabaseTables.koperasi)
              .select('nama_koperasi,alamat,telepon')
              .eq('id', koperasiId)
              .maybeSingle();
          if (koperasiRow != null) {
            namaKoperasi =
                koperasiRow['nama_koperasi'] as String? ?? 'Koperasi';
            final rawAlamat = koperasiRow['alamat'] as String?;
            final rawTelepon = koperasiRow['telepon'] as String?;
            alamat = (rawAlamat?.isNotEmpty ?? false) ? rawAlamat : null;
            telepon = (rawTelepon?.isNotEmpty ?? false) ? rawTelepon : null;
          }
        } catch (e) {
          debugPrint('[ReceiptService.buildFromTransactionId] Gagal fetch koperasi: $e');
        }
      }

      return ReceiptData(
        nomorTransaksi: _formatTransactionNumber(transactionId),
        tanggal: tanggal,
        namaKasir: namaKasir,
        metodePembayaran: metodePembayaran,
        namaKoperasi: namaKoperasi,
        alamatKoperasi: alamat,
        teleponKoperasi: telepon,
        items: items,
      );
    } on PostgrestException catch (error) {
      debugPrint('[ReceiptService.buildFromTransactionId] ERROR: ${error.message}');
      throw AppException(error.message, code: error.code);
    } catch (e) {
      debugPrint('[ReceiptService.buildFromTransactionId] Unexpected: $e');
      throw AppException('Gagal memuat data struk. Silakan coba lagi.');
    }
  }

  // ─── Helper ────────────────────────────────────────────────────────────────
  /// Mengubah ID transaksi (UUID atau angka) menjadi format human-friendly.
  ///
  /// Contoh:
  /// - "1"        → "TRX000001"
  /// - "42"       → "TRX000042"
  /// - "550e8400-e29b-41d4-a716-446655440000" → "TRX440000" (8 char hex terakhir)
  ///
  /// Format ini mudah dibaca kasir dan customer, serta unik dalam konteks
  /// koperasi yang sama.
  static String _formatTransactionNumber(String id) {
    // Coba parse sebagai integer (ID sequential dari database)
    final asInt = int.tryParse(id);
    if (asInt != null) {
      return 'TRX${asInt.toString().padLeft(6, '0')}';
    }

    // Fallback: gunakan 6 karakter terakhir dari UUID (hex), uppercase
    final clean = id.replaceAll('-', '');
    final suffix = clean.length >= 6
        ? clean.substring(clean.length - 6).toUpperCase()
        : clean.toUpperCase();
    return 'TRX$suffix';
  }
}
