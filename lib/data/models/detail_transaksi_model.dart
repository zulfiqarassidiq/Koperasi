class DetailTransaksiModel {
  const DetailTransaksiModel({
    required this.id,
    required this.transaksiId,
    required this.produkId,
    required this.qty,
    required this.harga,
    required this.subtotal,
  });

  final String id;
  final String transaksiId;
  final String produkId;
  final int qty;
  final num harga;
  final num subtotal;

  factory DetailTransaksiModel.fromJson(Map<String, dynamic> json) {
    return DetailTransaksiModel(
      id: json['id'].toString(),
      transaksiId: json['transaksi_id'].toString(),
      produkId: json['produk_id'].toString(),
      qty: json['qty'] as int? ?? 0,
      harga: json['harga'] as num? ?? 0,
      subtotal: json['subtotal'] as num? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transaksi_id': transaksiId,
        'produk_id': produkId,
        'qty': qty,
        'harga': harga,
        'subtotal': subtotal,
      };
}
