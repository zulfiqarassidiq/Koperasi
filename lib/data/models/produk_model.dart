class ProdukModel {
  const ProdukModel({
    required this.id,
    required this.kodeProduk,
    required this.namaProduk,
    required this.hargaBeli,
    required this.hargaJual,
    required this.stok,
    this.createdAt,
    this.kategoriId,
    this.koperasiId,
    this.namaKategori,
  });

  final String id;
  final String kodeProduk;
  final String namaProduk;
  final num hargaBeli;
  final num hargaJual;
  final int stok;
  final String? kategoriId;
  final String? koperasiId;
  final String? namaKategori;
  final DateTime? createdAt;

  factory ProdukModel.fromJson(Map<String, dynamic> json) {
    return ProdukModel(
      id: json['id'].toString(),
      kodeProduk: json['kode_produk'] as String? ?? '',
      namaProduk: json['nama_produk'] as String? ?? '',
      hargaBeli: json['harga_beli'] as num? ?? 0,
      hargaJual: json['harga_jual'] as num? ?? 0,
      stok: json['stok'] as int? ?? 0,
      kategoriId: json['kategori_id']?.toString(),
      koperasiId: json['koperasi_id'] as String?,
      namaKategori: json['nama_kategori'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kategori_id': kategoriId,
        'koperasi_id': koperasiId,
        'kode_produk': kodeProduk,
        'nama_produk': namaProduk,
        'harga_beli': hargaBeli,
        'harga_jual': hargaJual,
        'stok': stok,
        'created_at': createdAt?.toIso8601String(),
      };

  Map<String, dynamic> toInsertJson({String? koperasiId}) => {
        if (koperasiId != null) 'koperasi_id': koperasiId,
        'kategori_id': kategoriId,
        'kode_produk': kodeProduk,
        'nama_produk': namaProduk,
        'harga_beli': hargaBeli,
        'harga_jual': hargaJual,
        'stok': stok,
      };

  ProdukModel copyWith({
    String? id,
    String? kodeProduk,
    String? namaProduk,
    num? hargaBeli,
    num? hargaJual,
    int? stok,
    String? kategoriId,
    String? koperasiId,
    String? namaKategori,
    DateTime? createdAt,
  }) {
    return ProdukModel(
      id: id ?? this.id,
      kodeProduk: kodeProduk ?? this.kodeProduk,
      namaProduk: namaProduk ?? this.namaProduk,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      hargaJual: hargaJual ?? this.hargaJual,
      stok: stok ?? this.stok,
      kategoriId: kategoriId ?? this.kategoriId,
      koperasiId: koperasiId ?? this.koperasiId,
      namaKategori: namaKategori ?? this.namaKategori,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
