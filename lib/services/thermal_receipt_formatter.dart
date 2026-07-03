import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import '../domain/models/receipt_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract contract
// ─────────────────────────────────────────────────────────────────────────────

/// Kontrak untuk semua formatter thermal printer.
///
/// Mengubah [ReceiptData] menjadi bytes ESC/POS yang siap dikirim ke printer.
abstract class ThermalReceiptFormatter {
  /// [paperWidth] dalam mm: 58 atau 80.
  int get paperWidth;

  /// Menghasilkan bytes ESC/POS dari [data].
  Future<List<int>> format(ReceiptData data);
}

// ─────────────────────────────────────────────────────────────────────────────
// ESC/POS Formatter (Generic 58mm & 80mm)
// ─────────────────────────────────────────────────────────────────────────────

/// Formatter ESC/POS generik untuk printer 58mm dan 80mm.
///
/// Support: XPrinter 58mm, XPrinter 80mm, Epson TM Series,
/// dan Generic ESC/POS Bluetooth/USB Printer.
class EscPosFormatter implements ThermalReceiptFormatter {
  const EscPosFormatter({this.paperWidth = 58});

  @override
  final int paperWidth;

  @override
  Future<List<int>> format(ReceiptData data) async {
    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    // ── Gunakan var agar bisa diassign ulang dengan += ───────────────────────
    var bytes = <int>[];

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');

    // ── Reset & init ──────────────────────────────────────────────────────────
    bytes += generator.reset();

    // ── Header: Nama Koperasi ────────────────────────────────────────────────
    bytes += generator.text(
      data.namaKoperasi.toUpperCase(),
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );

    if (data.alamatKoperasi != null && data.alamatKoperasi!.isNotEmpty) {
      bytes += generator.text(
        data.alamatKoperasi!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (data.teleponKoperasi != null && data.teleponKoperasi!.isNotEmpty) {
      bytes += generator.text(
        'Telp: ${data.teleponKoperasi}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr(ch: '=');

    // ── Info Transaksi ────────────────────────────────────────────────────────
    bytes += _row2(generator, 'No', data.nomorTransaksi);
    bytes += _row2(generator, 'Tgl', dateFormat.format(data.tanggal));
    bytes += _row2(generator, 'Kasir', data.namaKasir);
    bytes += _row2(generator, 'Bayar', data.metodePembayaran);

    bytes += generator.hr();

    // ── Daftar Item ───────────────────────────────────────────────────────────
    for (final item in data.items) {
      // Nama produk (bisa panjang, wrap otomatis)
      bytes += generator.text(
        item.namaProduk,
        styles: const PosStyles(align: PosAlign.left),
      );
      // Qty x Harga   =   Subtotal
      bytes += _itemRow(
        generator,
        '${item.qty} x ${currency.format(item.hargaSatuan)}',
        currency.format(item.subtotal),
      );
    }

    bytes += generator.hr();

    // ── Ringkasan ─────────────────────────────────────────────────────────────
    bytes += _row2(generator, 'Total Item', '${data.totalItem}');
    bytes += _row2Bold(
      generator,
      'TOTAL',
      currency.format(data.grandTotal),
    );

    bytes += generator.hr(ch: '=');

    // ── Footer ────────────────────────────────────────────────────────────────
    bytes += generator.text(
      'Terima Kasih!',
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
      ),
    );
    bytes += generator.text(
      'Simpan struk ini sebagai bukti transaksi',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // ── Helper: 2-kolom info row ─────────────────────────────────────────────
  List<int> _row2(Generator g, String label, String value) {
    const labelWidth = 4;
    const valueWidth = 8;
    return g.row([
      PosColumn(
        text: label,
        width: labelWidth,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: ': $value',
        width: valueWidth,
        styles: const PosStyles(align: PosAlign.left),
      ),
    ]);
  }

  // ── Helper: 2-kolom bold row ─────────────────────────────────────────────
  List<int> _row2Bold(Generator g, String label, String value) {
    const labelWidth = 4;
    const valueWidth = 8;
    return g.row([
      PosColumn(
        text: label,
        width: labelWidth,
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        text: value,
        width: valueWidth,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
  }

  // ── Helper: Item row (qty x harga | subtotal) ────────────────────────────
  List<int> _itemRow(Generator g, String qtyHarga, String subtotal) {
    const labelWidth = 7;
    const valueWidth = 5;
    return g.row([
      PosColumn(
        text: '  $qtyHarga',
        width: labelWidth,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: subtotal,
        width: valueWidth,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Epson TM Formatter (extends EscPosFormatter)
// ─────────────────────────────────────────────────────────────────────────────

/// Formatter khusus Epson TM Series.
///
/// Epson TM umumnya menggunakan kertas 80mm dan command ESC/POS standar.
/// Override di sini jika memerlukan inisialisasi atau command khusus Epson.
class EpsonTmFormatter extends EscPosFormatter {
  const EpsonTmFormatter({super.paperWidth = 80});

  @override
  Future<List<int>> format(ReceiptData data) async {
    // Epson TM Series menggunakan ESC/POS standar — delegate ke parent.
    return super.format(data);
  }
}
