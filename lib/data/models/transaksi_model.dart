class TransaksiModel {
  const TransaksiModel({
    required this.id,
    required this.tanggal,
    required this.total,
    required this.metodePembayaran,
  });

  final String id;
  final DateTime tanggal;
  final num total;
  final String metodePembayaran;

  factory TransaksiModel.fromJson(Map<String, dynamic> json) {
    return TransaksiModel(
      id: json['id'].toString(),
      tanggal: DateTime.tryParse(json['tanggal']?.toString() ?? '') ??
          DateTime.now(),
      total: json['total'] as num? ?? 0,
      metodePembayaran: json['metode_pembayaran'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tanggal': _dateOnly(tanggal),
        'total': total,
        'metode_pembayaran': metodePembayaran,
      };

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
