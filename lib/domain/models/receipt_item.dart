/// Satu baris item pada struk transaksi.
///
/// Model ini murni Dart (tanpa dependency Flutter/UI) sehingga dapat
/// digunakan oleh PDF generator, ESC/POS formatter, maupun lapisan lainnya
/// tanpa perubahan.
class ReceiptItem {
  const ReceiptItem({
    required this.namaProduk,
    required this.qty,
    required this.hargaSatuan,
    required this.subtotal,
  });

  final String namaProduk;
  final int qty;
  final num hargaSatuan;
  final num subtotal;

  @override
  String toString() =>
      'ReceiptItem(namaProduk: $namaProduk, qty: $qty, '
      'hargaSatuan: $hargaSatuan, subtotal: $subtotal)';
}
