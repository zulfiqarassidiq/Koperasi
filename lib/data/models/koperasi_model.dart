import 'package:equatable/equatable.dart';

class KoperasiModel extends Equatable {
  const KoperasiModel({
    required this.id,
    required this.namaKoperasi,
    this.alamat,
    this.telepon,
    this.createdAt,
  });

  final String id;
  final String namaKoperasi;
  final String? alamat;
  final String? telepon;
  final DateTime? createdAt;

  factory KoperasiModel.fromMap(Map<String, dynamic> map) {
    return KoperasiModel(
      id: map['id'] as String,
      namaKoperasi: map['nama_koperasi'] as String? ?? '',
      alamat: map['alamat'] as String?,
      telepon: map['telepon'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'nama_koperasi': namaKoperasi,
      if (alamat != null && alamat!.isNotEmpty) 'alamat': alamat,
      if (telepon != null && telepon!.isNotEmpty) 'telepon': telepon,
    };
  }

  @override
  List<Object?> get props => [id, namaKoperasi, alamat, telepon, createdAt];
}
