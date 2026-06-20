import 'package:equatable/equatable.dart';

import 'user_profile_model.dart';

enum InviteStatus { pending, accepted, rejected }

InviteStatus inviteStatusFromString(String? value) {
  switch (value) {
    case 'accepted':
      return InviteStatus.accepted;
    case 'rejected':
      return InviteStatus.rejected;
    default:
      return InviteStatus.pending;
  }
}

class UserInviteModel extends Equatable {
  const UserInviteModel({
    required this.id,
    required this.koperasiId,
    required this.email,
    required this.role,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String koperasiId;
  final String email;
  final UserRole role;
  final InviteStatus status;
  final DateTime? createdAt;

  bool get isPending => status == InviteStatus.pending;

  factory UserInviteModel.fromMap(Map<String, dynamic> map) {
    return UserInviteModel(
      id: map['id'] as String,
      koperasiId: map['koperasi_id'] as String,
      email: map['email'] as String,
      role: userRoleFromString(map['role'] as String?),
      status: inviteStatusFromString(map['status'] as String?),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, koperasiId, email, role, status, createdAt];
}
