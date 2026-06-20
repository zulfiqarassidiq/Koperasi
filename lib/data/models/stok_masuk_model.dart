class StokMasukModel {
  const StokMasukModel({
    required this.id,
    required this.produkId,
    required this.qty,
    required this.tanggal,
    this.keterangan,
    this.namaProduk,
  });

  final String id;
  final String produkId;
  final int qty;
  final DateTime tanggal;
  final String? keterangan;
  final String? namaProduk;

  factory StokMasukModel.fromJson(Map<String, dynamic> json) {
    return StokMasukModel(
      id: json['id'].toString(),
      produkId: json['produk_id'].toString(),
      qty: json['qty'] as int? ?? 0,
      tanggal: DateTime.tryParse(json['tanggal']?.toString() ?? '') ??
          DateTime.now(),
      keterangan: json['keterangan'] as String?,
      namaProduk: json['nama_produk'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'produk_id': produkId,
        'qty': qty,
        'tanggal': _dateOnly(tanggal),
        'keterangan': keterangan,
      };

  Map<String, dynamic> toInsertJson() => {
        'produk_id': produkId,
        'qty': qty,
        'tanggal': _dateOnly(tanggal),
        'keterangan': keterangan,
      };

  StokMasukModel copyWith({
    String? id,
    String? produkId,
    int? qty,
    DateTime? tanggal,
    String? keterangan,
    String? namaProduk,
  }) {
    return StokMasukModel(
      id: id ?? this.id,
      produkId: produkId ?? this.produkId,
      qty: qty ?? this.qty,
      tanggal: tanggal ?? this.tanggal,
      keterangan: keterangan ?? this.keterangan,
      namaProduk: namaProduk ?? this.namaProduk,
    );
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
