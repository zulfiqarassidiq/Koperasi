class KategoriProdukModel {
  const KategoriProdukModel({required this.id, required this.namaKategori});

  final String id;
  final String namaKategori;

  factory KategoriProdukModel.fromJson(Map<String, dynamic> json) {
    return KategoriProdukModel(
      id: json['id'].toString(),
      namaKategori: json['nama_kategori'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nama_kategori': namaKategori};

  Map<String, dynamic> toInsertJson() => {'nama_kategori': namaKategori};

  KategoriProdukModel copyWith({String? id, String? namaKategori}) {
    return KategoriProdukModel(
      id: id ?? this.id,
      namaKategori: namaKategori ?? this.namaKategori,
    );
  }
}
