class TransaksiDetailItemModel {
  const TransaksiDetailItemModel({
    required this.id,
    required this.transaksiId,
    required this.produkId,
    required this.qty,
    required this.harga,
    required this.subtotal,
    this.namaProduk,
  });

  final String id;
  final String transaksiId;
  final String produkId;
  final int qty;
  final num harga;
  final num subtotal;
  final String? namaProduk;

  factory TransaksiDetailItemModel.fromJson(Map<String, dynamic> json) {
    return TransaksiDetailItemModel(
      id: json['id'].toString(),
      transaksiId: json['transaksi_id'].toString(),
      produkId: json['produk_id'].toString(),
      qty: json['qty'] as int? ?? 0,
      harga: json['harga'] as num? ?? 0,
      subtotal: json['subtotal'] as num? ?? 0,
      namaProduk: json['nama_produk'] as String?,
    );
  }
}
