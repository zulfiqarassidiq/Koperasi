import 'receipt_item.dart';

/// Data lengkap sebuah struk transaksi.
///
/// Model ini adalah **single source of truth** untuk semua renderer struk:
/// - [PdfReceiptGenerator]     → menghasilkan file PDF
/// - [ThermalReceiptFormatter] → menghasilkan bytes ESC/POS untuk printer thermal
///
/// Tidak memiliki dependency ke Flutter, pdf, atau paket printer.
/// Artinya dapat dibuat, diuji, dan digunakan lintas layer tanpa coupling.
///
/// Format nomor transaksi yang human-friendly (mis. TRX000001) dihasilkan
/// oleh [ReceiptService] saat membangun instance ini.
class ReceiptData {
  const ReceiptData({
    required this.nomorTransaksi,
    required this.tanggal,
    required this.namaKasir,
    required this.metodePembayaran,
    required this.namaKoperasi,
    required this.items,
    this.alamatKoperasi,
    this.teleponKoperasi,
  });

  // ── Header Koperasi ────────────────────────────────────────────────────────
  /// Nama koperasi berasal dari tabel `koperasi` milik user yang login.
  /// Dijamin tidak cross-koperasi karena di-supply oleh [ReceiptService].
  final String namaKoperasi;

  /// Opsional — ditampilkan di struk jika tersedia di database.
  final String? alamatKoperasi;

  /// Opsional — ditampilkan di struk jika tersedia di database.
  final String? teleponKoperasi;

  // ── Info Transaksi ─────────────────────────────────────────────────────────
  /// Nomor transaksi human-friendly, contoh: TRX000001.
  final String nomorTransaksi;

  final DateTime tanggal;
  final String namaKasir;
  final String metodePembayaran;

  // ── Item ──────────────────────────────────────────────────────────────────
  final List<ReceiptItem> items;

  // ── Aggregates ────────────────────────────────────────────────────────────
  /// Jumlah total qty seluruh item.
  int get totalItem => items.fold(0, (sum, e) => sum + e.qty);

  /// Grand total (sum subtotal seluruh item).
  num get grandTotal => items.fold<num>(0, (sum, e) => sum + e.subtotal);

  @override
  String toString() =>
      'ReceiptData(nomorTransaksi: $nomorTransaksi, '
      'namaKoperasi: $namaKoperasi, grandTotal: $grandTotal)';

  // ── Test Data ─────────────────────────────────────────────────────────────

  /// Membuat [ReceiptData] palsu untuk keperluan test print printer.
  ///
  /// Digunakan oleh [ThermalPrinterService.testPrint] agar user dapat
  /// memverifikasi koneksi printer tanpa harus membuat transaksi baru.
  factory ReceiptData.testData() {
    return ReceiptData(
      nomorTransaksi: 'TRX-TEST',
      tanggal: DateTime.now(),
      namaKasir: 'Test Kasir',
      metodePembayaran: 'Cash',
      namaKoperasi: 'KOPERASI POS TEST',
      alamatKoperasi: 'Jl. Test No. 1',
      teleponKoperasi: '08123456789',
      items: const [
        ReceiptItem(
          namaProduk: 'Produk Test A',
          qty: 2,
          hargaSatuan: 15000,
          subtotal: 30000,
        ),
        ReceiptItem(
          namaProduk: 'Produk Test B',
          qty: 1,
          hargaSatuan: 25000,
          subtotal: 25000,
        ),
      ],
    );
  }
}
