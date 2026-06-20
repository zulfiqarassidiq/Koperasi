import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/user_invite_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/repositories/user_management_repository.dart';
import '../auth/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Members Provider
// ─────────────────────────────────────────────────────────────────────────────

/// FutureProvider yang me-load daftar member koperasi saat ini.
final membersProvider =
    FutureProvider.autoDispose<List<UserProfileModel>>((ref) async {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile?.koperasiId == null) return [];

  return ref
      .watch(userManagementRepositoryProvider)
      .getMembers(profile!.koperasiId!);
});

// ─────────────────────────────────────────────────────────────────────────────
// Invites Provider
// ─────────────────────────────────────────────────────────────────────────────

/// FutureProvider yang me-load daftar invite koperasi saat ini.
final invitesProvider =
    FutureProvider.autoDispose<List<UserInviteModel>>((ref) async {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile?.koperasiId == null) return [];

  return ref
      .watch(userManagementRepositoryProvider)
      .getInvites(profile!.koperasiId!);
});

// ─────────────────────────────────────────────────────────────────────────────
// User Management State
// ─────────────────────────────────────────────────────────────────────────────
class UserMgmtState {
  const UserMgmtState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  UserMgmtState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return UserMgmtState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearMessages ? null : successMessage ?? this.successMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Management Controller
// ─────────────────────────────────────────────────────────────────────────────
final userMgmtControllerProvider =
    StateNotifierProvider<UserMgmtController, UserMgmtState>((ref) {
  return UserMgmtController(
    ref.watch(userManagementRepositoryProvider),
    ref,
  );
});

class UserMgmtController extends StateNotifier<UserMgmtState> {
  UserMgmtController(this._repository, this._ref)
      : super(const UserMgmtState());

  final UserManagementRepository _repository;
  final Ref _ref;

  // ─── Invite ───────────────────────────────────────────────────────────────
  Future<bool> sendInvite({
    required String email,
    required UserRole role,
  }) async {
    final profile = _ref.read(currentProfileProvider).valueOrNull;
    if (profile?.koperasiId == null) {
      state = const UserMgmtState(errorMessage: 'Koperasi tidak ditemukan.');
      return false;
    }

    state = const UserMgmtState(isLoading: true);
    try {
      await _repository.sendInvite(
        koperasiId: profile!.koperasiId!,
        email: email.trim(),
        role: role,
      );
      _ref.invalidate(invitesProvider);
      state = const UserMgmtState(successMessage: 'Undangan berhasil dikirim.');
      return true;
    } on AppException catch (e) {
      state = UserMgmtState(errorMessage: e.message);
      return false;
    } catch (_) {
      state = const UserMgmtState(
          errorMessage: 'Gagal mengirim undangan. Silakan coba lagi.');
      return false;
    }
  }

  // ─── Cancel Invite ────────────────────────────────────────────────────────
  Future<void> cancelInvite(String inviteId) async {
    state = const UserMgmtState(isLoading: true);
    try {
      await _repository.cancelInvite(inviteId);
      _ref.invalidate(invitesProvider);
      state =
          const UserMgmtState(successMessage: 'Undangan berhasil dibatalkan.');
    } on AppException catch (e) {
      state = UserMgmtState(errorMessage: e.message);
    } catch (_) {
      state = const UserMgmtState(
          errorMessage: 'Gagal membatalkan undangan. Silakan coba lagi.');
    }
  }

  // ─── Change Role ──────────────────────────────────────────────────────────
  Future<void> changeRole({
    required String memberId,
    required UserRole newRole,
  }) async {
    state = const UserMgmtState(isLoading: true);
    try {
      await _repository.changeRole(memberId: memberId, newRole: newRole);
      _ref.invalidate(membersProvider);
      state = const UserMgmtState(successMessage: 'Role berhasil diubah.');
    } on AppException catch (e) {
      state = UserMgmtState(errorMessage: e.message);
    } catch (_) {
      state = const UserMgmtState(
          errorMessage: 'Gagal mengubah role. Silakan coba lagi.');
    }
  }

  // ─── Remove Member ────────────────────────────────────────────────────────
  Future<void> removeMember(String memberId) async {
    state = const UserMgmtState(isLoading: true);
    try {
      await _repository.removeMember(memberId);
      _ref.invalidate(membersProvider);
      state = const UserMgmtState(
          successMessage: 'Anggota berhasil dikeluarkan dari koperasi.');
    } on AppException catch (e) {
      state = UserMgmtState(errorMessage: e.message);
    } catch (_) {
      state = const UserMgmtState(
          errorMessage: 'Gagal mengeluarkan anggota. Silakan coba lagi.');
    }
  }

  void clearMessages() => state = state.copyWith(clearMessages: true);
}
