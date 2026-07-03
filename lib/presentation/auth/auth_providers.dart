import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/koperasi_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/repositories/auth_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repository Provider (re-export agar konsisten)
// ─────────────────────────────────────────────────────────────────────────────
export '../../data/repositories/auth_repository.dart'
    show authRepositoryProvider;

// ─────────────────────────────────────────────────────────────────────────────
// Session Provider
// ─────────────────────────────────────────────────────────────────────────────
final authSessionProvider = StreamProvider<Session?>((ref) {
  return ref.watch(authRepositoryProvider).sessionChanges;
});

// ─────────────────────────────────────────────────────────────────────────────
// Current User Profile Provider
// ─────────────────────────────────────────────────────────────────────────────
/// Provider yang me-refresh setiap kali session berubah.
/// Meng-expose UserProfileModel? yang sudah diambil dari Supabase.
final currentProfileProvider = FutureProvider<UserProfileModel?>((ref) async {
  // Dengarkan session agar refresh saat login/logout
  final sessionAsync = ref.watch(authSessionProvider);
  final session = sessionAsync.valueOrNull;
  if (session == null) return null;

  return ref.watch(authRepositoryProvider).getCurrentProfile();
});

/// Provider yang me-expose koperasi milik user yang sedang login.
final currentKoperasiProvider = FutureProvider<KoperasiModel?>((ref) async {
  final profileAsync = ref.watch(currentProfileProvider);
  final profile = profileAsync.valueOrNull;
  if (profile == null || !profile.hasKoperasi) return null;

  return ref.watch(authRepositoryProvider).getKoperasi(profile.koperasiId!);
});

// ─────────────────────────────────────────────────────────────────────────────
// Auth Form State
// ─────────────────────────────────────────────────────────────────────────────
class AuthFormState {
  const AuthFormState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  AuthFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return AuthFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearMessages ? null : successMessage ?? this.successMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth Controller
// ─────────────────────────────────────────────────────────────────────────────
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthFormState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AuthFormState> {
  AuthController(this._repository) : super(const AuthFormState());

  final AuthRepository _repository;

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<void> login({required String email, required String password}) async {
    await _run(() => _repository.login(email: email, password: password));
  }

  // ─── Logout ───────────────────────────────────────────────────────────────
  /// Logout membersihkan state dan memanggil Supabase signOut.
  /// GoRouter akan otomatis redirect ke login melalui AuthRouteRefresh listener
  /// yang menangkap event AuthChangeEvent.signedOut dari onAuthStateChange.
  Future<void> logout() async {
    state = const AuthFormState(isLoading: true);
    try {
      await _repository.logout();
      // Reset state ke bersih — GoRouter akan handle redirect via refreshListenable
      state = const AuthFormState();
    } on AppException catch (error) {
      state = AuthFormState(errorMessage: error.message);
    } catch (_) {
      // Meski ada error, tetap reset state agar tidak stuck di loading
      state = const AuthFormState(
        errorMessage: 'Gagal logout. Silakan coba lagi.',
      );
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────
  /// Mendaftar akun baru. Mengembalikan true jika user diinvite.
  Future<bool> register({
    required String email,
    required String nama,
    required String password,
  }) async {
    bool isInvited = false;
    state = const AuthFormState(isLoading: true);
    try {
      isInvited = await _repository.register(
        email: email,
        nama: nama,
        password: password,
      );
      state = const AuthFormState();
    } on AppException catch (error) {
      state = AuthFormState(errorMessage: error.message);
    } catch (_) {
      state = const AuthFormState(
        errorMessage: 'Terjadi kesalahan. Silakan coba lagi.',
      );
    }
    return isInvited;
  }

  // ─── Forgot Password ──────────────────────────────────────────────────────
  Future<void> forgotPassword(String email) async {
    await _run(
      () => _repository.forgotPassword(email),
      successMessage:
          'Jika email terdaftar, tautan reset sudah dikirim. Periksa juga folder Spam.',
    );
  }

  // ─── Change Password ──────────────────────────────────────────────────────
  Future<void> changePassword(String password) async {
    await _run(
      () => _repository.changePassword(password),
      successMessage: 'Password berhasil diperbarui.',
    );
  }

  // ─── Util ─────────────────────────────────────────────────────────────────
  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    state = const AuthFormState(isLoading: true);
    try {
      await action();
      state = AuthFormState(successMessage: successMessage);
    } on AppException catch (error) {
      state = AuthFormState(errorMessage: error.message);
    } catch (_) {
      state = const AuthFormState(
        errorMessage: 'Terjadi kesalahan. Silakan coba lagi.',
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Koperasi Controller (khusus onboarding create koperasi)
// ─────────────────────────────────────────────────────────────────────────────
class KoperasiFormState {
  const KoperasiFormState({
    this.isLoading = false,
    this.errorMessage,
    this.createdKoperasi,
  });

  final bool isLoading;
  final String? errorMessage;
  final KoperasiModel? createdKoperasi;

  bool get isSuccess => createdKoperasi != null;

  KoperasiFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    KoperasiModel? createdKoperasi,
    bool clearError = false,
  }) {
    return KoperasiFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      createdKoperasi: createdKoperasi ?? this.createdKoperasi,
    );
  }
}

final koperasiFormControllerProvider =
    StateNotifierProvider<KoperasiFormController, KoperasiFormState>((ref) {
  return KoperasiFormController(ref.watch(authRepositoryProvider));
});

class KoperasiFormController extends StateNotifier<KoperasiFormState> {
  KoperasiFormController(this._repository) : super(const KoperasiFormState());

  final AuthRepository _repository;

  Future<bool> createKoperasi({
    required String userId,
    required String namaKoperasi,
    String? alamat,
    String? telepon,
  }) async {
    state = const KoperasiFormState(isLoading: true);
    try {
      final koperasi = await _repository.createKoperasi(
        userId: userId,
        namaKoperasi: namaKoperasi,
        alamat: alamat,
        telepon: telepon,
      );
      state = KoperasiFormState(createdKoperasi: koperasi);
      return true;
    } on AppException catch (error) {
      state = KoperasiFormState(errorMessage: error.message);
      return false;
    } catch (_) {
      state = const KoperasiFormState(
        errorMessage: 'Gagal membuat koperasi. Silakan coba lagi.',
      );
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role Guard Helper
// ─────────────────────────────────────────────────────────────────────────────
/// Provider yang memeriksa apakah user memiliki role tertentu.
/// Digunakan oleh pages untuk hide/show fitur sesuai role.
final userRoleProvider = Provider<UserRole?>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.role;
});
