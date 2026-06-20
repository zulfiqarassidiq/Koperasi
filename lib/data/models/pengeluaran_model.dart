class PengeluaranModel {
  const PengeluaranModel({
    required this.id,
    required this.tanggal,
    required this.keterangan,
    required this.jumlah,
  });

  final String id;
  final DateTime tanggal;
  final String keterangan;
  final num jumlah;

  factory PengeluaranModel.fromJson(Map<String, dynamic> json) {
    return PengeluaranModel(
      id: json['id'].toString(),
      tanggal: DateTime.tryParse(json['tanggal']?.toString() ?? '') ??
          DateTime.now(),
      keterangan: json['keterangan'] as String? ?? '',
      jumlah: json['jumlah'] as num? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tanggal': _dateOnly(tanggal),
        'keterangan': keterangan,
        'jumlah': jumlah,
      };

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
