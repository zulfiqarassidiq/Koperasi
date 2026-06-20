// ─────────────────────────────────────────────────────────────────────────────
// User Management Repository
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../services/auth_service.dart';
import '../models/user_invite_model.dart';
import '../models/user_profile_model.dart';

final userManagementRepositoryProvider =
    Provider<UserManagementRepository>((ref) {
  return UserManagementRepository(ref.watch(authServiceProvider));
});

class UserManagementRepository {
  const UserManagementRepository(this._service);

  final AuthService _service;

  // ─── Members ──────────────────────────────────────────────────────────────
  Future<List<UserProfileModel>> getMembers(String koperasiId) async {
    try {
      final result = await _service.getMembersByKoperasi(koperasiId);
      return result.map(UserProfileModel.fromMap).toList();
    } on PostgrestException catch (e) {
      throw AppException(e.message, code: e.code);
    }
  }

  /// Update role member. Owner tidak boleh diubah.
  Future<void> changeRole({
    required String memberId,
    required UserRole newRole,
  }) async {
    if (newRole == UserRole.owner) {
      throw const AppException('Role owner tidak dapat ditetapkan dari sini.');
    }
    try {
      await _service.updateProfile(memberId, role: newRole.name);
    } on PostgrestException catch (e) {
      throw AppException(e.message, code: e.code);
    }
  }

  /// Keluarkan anggota dengan mengosongkan koperasi_id.
  /// Akun Supabase Auth TIDAK dihapus.
  Future<void> removeMember(String memberId) async {
    try {
      final client = _service.client;
      await client
          .from('profiles')
          .update({'koperasi_id': null})
          .eq('id', memberId);
    } on PostgrestException catch (e) {
      throw AppException(e.message, code: e.code);
    }
  }

  // ─── Invites ──────────────────────────────────────────────────────────────
  Future<List<UserInviteModel>> getInvites(String koperasiId) async {
    try {
      final result = await _service.getInvitesByKoperasi(koperasiId);
      return result.map(UserInviteModel.fromMap).toList();
    } on PostgrestException catch (e) {
      throw AppException(e.message, code: e.code);
    }
  }

  Future<void> sendInvite({
    required String koperasiId,
    required String email,
    required UserRole role,
  }) async {
    if (role == UserRole.owner) {
      throw const AppException('Tidak dapat mengundang dengan role owner.');
    }
    try {
      await _service.sendInvite(
        koperasiId: koperasiId,
        email: email,
        role: role.name,
      );
    } on PostgrestException catch (e) {
      throw AppException(e.message, code: e.code);
    }
  }

  /// Hapus invite — hanya bisa jika status masih pending.
  Future<void> cancelInvite(String inviteId) async {
    try {
      final client = _service.client;
      await client
          .from('user_invites')
          .delete()
          .eq('id', inviteId)
          .eq('status', 'pending');
    } on PostgrestException catch (e) {
      throw AppException(e.message, code: e.code);
    }
  }
}
