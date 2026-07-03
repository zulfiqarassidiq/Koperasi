import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models/receipt_data.dart';
import '../domain/models/receipt_item.dart';

final pdfReceiptGeneratorProvider = Provider<PdfReceiptGenerator>(
  (ref) => const PdfReceiptGenerator(),
);

/// Menghasilkan PDF struk transaksi dari [ReceiptData].
///
/// Generator ini adalah satu-satunya tempat yang tahu cara merender PDF.
/// [ReceiptData] di-supply dari luar sehingga generator ini dapat diuji
/// secara terisolasi tanpa menyentuh Supabase atau state Flutter.
///
/// Format:
/// - Lebar halaman: 80mm (kompatibel dengan preview layar & printer 80mm)
/// - Layout vertikal menyerupai struk kasir thermal
/// - Typography bersih dengan garis pemisah dan tabel item
class PdfReceiptGenerator {
  const PdfReceiptGenerator();

  // ── Dimensi & Style Constants ──────────────────────────────────────────────
  static const double _pageWidthMm = 80;
  static const double _marginMm = 5;
  static final _pageFormat = PdfPageFormat(
    _pageWidthMm * PdfPageFormat.mm,
    double.infinity,
    marginAll: _marginMm * PdfPageFormat.mm,
  );

  static const _colorText = PdfColors.black;
  static const _colorMuted = PdfColors.grey700;
  static const _colorDivider = PdfColors.grey400;

  // ── Public API ─────────────────────────────────────────────────────────────
  /// Menghasilkan PDF sebagai [Uint8List] yang dapat langsung
  /// diteruskan ke [Printing.layoutPdf] atau [Printing.sharePdf].
  Future<Uint8List> generate(ReceiptData data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: _pageFormat,
        build: (context) => _buildContent(context, data),
      ),
    );

    return doc.save();
  }

  // ── Layout Builder ─────────────────────────────────────────────────────────
  pw.Widget _buildContent(pw.Context context, ReceiptData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _buildHeader(data),
        _divider(),
        _buildTransactionInfo(data),
        _divider(),
        _buildItemsTable(data.items),
        _divider(),
        _buildTotals(data),
        _divider(),
        _buildFooter(),
      ],
    );
  }

  // ── Header Koperasi ────────────────────────────────────────────────────────
  pw.Widget _buildHeader(ReceiptData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          data.namaKoperasi.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _colorText,
          ),
          textAlign: pw.TextAlign.center,
        ),
        if (data.alamatKoperasi != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            data.alamatKoperasi!,
            style: pw.TextStyle(fontSize: 8, color: _colorMuted),
            textAlign: pw.TextAlign.center,
          ),
        ],
        if (data.teleponKoperasi != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'Telp: ${data.teleponKoperasi}',
            style: pw.TextStyle(fontSize: 8, color: _colorMuted),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Info Transaksi ─────────────────────────────────────────────────────────
  pw.Widget _buildTransactionInfo(ReceiptData data) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoRow('No. Transaksi', data.nomorTransaksi),
          _infoRow('Tanggal', dateFormat.format(data.tanggal)),
          _infoRow('Kasir', data.namaKasir),
          _infoRow('Pembayaran', data.metodePembayaran),
        ],
      ),
    );
  }

  // ── Tabel Item ─────────────────────────────────────────────────────────────
  pw.Widget _buildItemsTable(List<ReceiptItem> items) {
    const headerStyle = pw.TextStyle(fontSize: 8);
    final boldStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Column(
        children: [
          // Header kolom
          pw.Row(
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Text('Produk', style: headerStyle),
              ),
              pw.SizedBox(
                width: 22,
                child: pw.Text('Qty', style: headerStyle,
                    textAlign: pw.TextAlign.center),
              ),
              pw.SizedBox(
                width: 40,
                child: pw.Text('Subtotal', style: headerStyle,
                    textAlign: pw.TextAlign.right),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          _thinDivider(),
          pw.SizedBox(height: 3),
          // Baris item
          ...items.map((item) => _buildItemRow(item, boldStyle)),
        ],
      ),
    );
  }

  pw.Widget _buildItemRow(ReceiptItem item, pw.TextStyle style) {
    final currency = NumberFormat('#,###', 'id_ID');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Nama produk (bisa panjang, wrap otomatis)
          pw.Text(item.namaProduk,
              style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Text(
                  '  ${item.qty} x Rp ${currency.format(item.hargaSatuan)}',
                  style: pw.TextStyle(fontSize: 7, color: _colorMuted),
                ),
              ),
              pw.SizedBox(
                width: 62,
                child: pw.Text(
                  'Rp ${currency.format(item.subtotal)}',
                  style: style,
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Total ──────────────────────────────────────────────────────────────────
  pw.Widget _buildTotals(ReceiptData data) {
    final currency = NumberFormat('#,###', 'id_ID');
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Column(
        children: [
          _totalRow(
            'Total Item',
            '${data.totalItem} item',
            isBold: false,
          ),
          pw.SizedBox(height: 4),
          _totalRow(
            'GRAND TOTAL',
            'Rp ${currency.format(data.grandTotal)}',
            isBold: true,
            fontSize: 10,
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  pw.Widget _buildFooter() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        children: [
          pw.Text(
            '*** Terima Kasih ***',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _colorText,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Barang yang sudah dibeli\ntidak dapat dikembalikan.',
            style: pw.TextStyle(fontSize: 7, color: _colorMuted),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  pw.Widget _divider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Divider(color: _colorDivider, thickness: 1),
      );

  pw.Widget _thinDivider() => pw.Divider(
        color: _colorDivider,
        thickness: 0.5,
      );

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 58,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 8, color: _colorMuted)),
          ),
          pw.Text(': ', style: pw.TextStyle(fontSize: 8, color: _colorMuted)),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  pw.Widget _totalRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 8,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: isBold ? _colorText : _colorMuted,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
  }
}
