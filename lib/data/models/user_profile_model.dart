import 'package:equatable/equatable.dart';

enum UserRole { owner, admin, kasir }

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Admin';
      case UserRole.kasir:
        return 'Kasir';
    }
  }

  // ── Izin per fitur ────────────────────────────────────────────────────────
  /// Semua role bisa melakukan transaksi (kasir, admin, owner).
  bool get canDoTransactions => true;

  /// Produk: owner, admin, kasir semua bisa CRUD produk.
  bool get canManageProducts => true;

  /// Kategori: owner, admin, kasir semua bisa CRUD kategori.
  bool get canManageKategori => true;

  /// Stok: owner, admin, kasir semua bisa kelola stok.
  bool get canManageStock => true;

  /// Pengeluaran: hanya owner dan admin.
  bool get canManagePengeluaran =>
      this == UserRole.owner || this == UserRole.admin;

  /// Laporan: hanya owner dan admin.
  bool get canViewReports => this == UserRole.owner || this == UserRole.admin;

  /// User management / invite: hanya owner dan admin.
  bool get canManageUsers => this == UserRole.owner || this == UserRole.admin;

  /// Setting koperasi: hanya owner dan admin.
  bool get canManageKoperasi =>
      this == UserRole.owner || this == UserRole.admin;
}

UserRole userRoleFromString(String? value) {
  switch (value) {
    case 'owner':
      return UserRole.owner;
    case 'admin':
      return UserRole.admin;
    case 'kasir':
      return UserRole.kasir;
    default:
      return UserRole.kasir;
  }
}

class UserProfileModel extends Equatable {
  const UserProfileModel({
    required this.id,
    required this.nama,
    required this.role,
    this.koperasiId,
    this.createdAt,
  });

  final String id;
  final String nama;
  final UserRole role;
  final String? koperasiId;
  final DateTime? createdAt;

  /// Apakah user sudah memiliki koperasi (sudah selesai onboarding)
  bool get hasKoperasi => koperasiId != null && koperasiId!.isNotEmpty;

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: map['id'] as String,
      nama: map['nama'] as String? ?? '',
      role: userRoleFromString(map['role'] as String?),
      koperasiId: map['koperasi_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'role': role.name,
      if (koperasiId != null) 'koperasi_id': koperasiId,
    };
  }

  UserProfileModel copyWith({
    String? nama,
    UserRole? role,
    String? koperasiId,
  }) {
    return UserProfileModel(
      id: id,
      nama: nama ?? this.nama,
      role: role ?? this.role,
      koperasiId: koperasiId ?? this.koperasiId,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, nama, role, koperasiId, createdAt];
}
