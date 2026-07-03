import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../services/auth_service.dart';
import '../models/koperasi_model.dart';
import '../models/user_invite_model.dart';
import '../models/user_profile_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authServiceProvider));
});

class AuthRepository {
  const AuthRepository(this._service);

  final AuthService _service;

  // ─── Session ──────────────────────────────────────────────────────────────
  Session? get currentSession => _service.currentSession;
  User? get currentUser => _service.currentUser;
  Stream<Session?> get sessionChanges => _service.sessionChanges;
  Stream<AuthState> get authStateChanges => _service.authStateChanges;

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<void> login({required String email, required String password}) async {
    try {
      final response = await _service.signInWithEmail(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        throw const AppException('Login gagal. Silakan coba lagi.');
      }
    } on AuthException catch (error) {
      throw AppException(_mapAuthError(error.message), code: error.statusCode);
    }
  }

  Future<void> logout() async {
    debugPrint('[AuthRepository.logout] Calling signOut...');
    try {
      await _service.signOut();
      debugPrint(
          '[AuthRepository.logout] signOut complete. Session should be null now.');
    } on AuthException catch (error) {
      debugPrint('[AuthRepository.logout] AuthException: ${error.message}');
      throw AppException(error.message, code: error.statusCode);
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────
  /// Mendaftarkan akun baru.
  ///
  /// Flow:
  /// 1. Buat akun di Supabase Auth
  /// 2. Cek apakah ada invite untuk email ini
  /// 3a. Jika ada invite pending → pakai koperasi_id & role dari invite,
  ///     update status invite menjadi accepted
  /// 3b. Jika tidak ada invite → buat profil tanpa koperasi (role default kasir,
  ///     akan diupdate saat Create Koperasi)
  ///
  /// Return: true jika user diinvite (langsung ke dashboard),
  ///         false jika user baru (perlu create koperasi)
  Future<bool> register({
    required String email,
    required String nama,
    required String password,
  }) async {
    debugPrint('[AuthRepository.register] START. email: $email, nama: $nama');
    try {
      // Strategi: Cek invite SEBELUM signUp (sesi anonim).
      // Jika tabel user_invites mengizinkan akses anonim via anon key, invite langsung
      // terdeteksi. Jika RLS memblokir, kita cek ulang SETELAH signUp.
      debugPrint(
          '[AuthRepository.register] [PRE-SIGNUP] Checking pending invite for: $email');
      Map<String, dynamic>? invite = await _service.getPendingInvite(email);
      debugPrint(
          '[AuthRepository.register] [PRE-SIGNUP] getPendingInvite result: $invite');

      final response = await _service.signUp(
        email: email.trim(),
        password: password,
        nama: nama.trim(),
      );

      final user = response.user;
      if (user == null) {
        throw const AppException('Registrasi gagal. Silakan coba lagi.');
      }
      debugPrint(
          '[AuthRepository.register] SignUp success. userId: ${user.id}, hasSession: ${response.session != null}');

      // Jika invite belum ditemukan (kemungkinan RLS anon memblokir),
      // coba cek ulang dengan sesi user yang baru terdaftar.
      if (invite == null) {
        debugPrint(
            '[AuthRepository.register] [POST-SIGNUP] Re-checking invite with authenticated session...');
        invite = await _service.getPendingInvite(email);
        debugPrint(
            '[AuthRepository.register] [POST-SIGNUP] getPendingInvite result: $invite');
      }

      if (invite != null) {
        final inviteModel = UserInviteModel.fromMap(invite);
        debugPrint(
          '[AuthRepository.register] INVITE FOUND! '
          'role: ${inviteModel.role.name}, '
          'koperasi_id: ${inviteModel.koperasiId}, '
          'status: ${inviteModel.status.name}',
        );

        // Buat profil dengan role & koperasi dari invite
        debugPrint(
            '[AuthRepository.register] upsertProfile => invited user...');
        await _service.upsertProfile({
          'id': user.id,
          'nama': nama.trim(),
          'koperasi_id': inviteModel.koperasiId,
          'role': inviteModel.role.name,
        });

        // Tandai invite sebagai accepted
        debugPrint(
            '[AuthRepository.register] acceptInvite id: ${inviteModel.id}');
        await _service.acceptInvite(inviteModel.id);
        debugPrint(
            '[AuthRepository.register] Invite accepted. User is now [${inviteModel.role.name}].');

        return true; // ada invite => langsung ke dashboard
      } else {
        debugPrint(
            '[AuthRepository.register] No invite found => creating owner profile.');
        await _service.upsertProfile({
          'id': user.id,
          'nama': nama.trim(),
          'role': 'owner',
        });
        debugPrint('[AuthRepository.register] Owner profile created.');

        return false; // tidak ada invite => perlu create koperasi
      }
    } on AuthException catch (error) {
      debugPrint('[AuthRepository.register] AuthException: ${error.message}');
      throw AppException(_mapAuthError(error.message), code: error.statusCode);
    } on PostgrestException catch (error) {
      debugPrint(
          '[AuthRepository.register] PostgrestException: ${error.message} (code: ${error.code})');
      throw AppException(error.message, code: error.code);
    }
  }

  // ─── Koperasi Onboarding ──────────────────────────────────────────────────
  /// Buat koperasi baru dan update profil owner.
  Future<KoperasiModel> createKoperasi({
    required String userId,
    required String namaKoperasi,
    String? alamat,
    String? telepon,
  }) async {
    try {
      final insertData = {
        'nama_koperasi': namaKoperasi.trim(),
        if (alamat != null && alamat.isNotEmpty) 'alamat': alamat.trim(),
        if (telepon != null && telepon.isNotEmpty) 'telepon': telepon.trim(),
      };

      final result = await _service.insertKoperasi(insertData);
      final koperasi = KoperasiModel.fromMap(result);

      // Update profil dengan koperasi_id dan role owner
      await _service.updateProfile(
        userId,
        koperasiId: koperasi.id,
        role: 'owner',
      );

      return koperasi;
    } on PostgrestException catch (error) {
      throw AppException(error.message, code: error.code);
    }
  }

  // ─── Profile ──────────────────────────────────────────────────────────────
  /// Ambil profil user saat ini dari database.
  Future<UserProfileModel?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _service.getUserProfile(user.id);
      if (data == null) return null;
      return UserProfileModel.fromMap(data);
    } on PostgrestException catch (error) {
      throw AppException(error.message, code: error.code);
    }
  }

  /// Update nama user yang sedang login.
  Future<void> updateProfileName(String nama) async {
    final user = currentUser;
    if (user == null) throw const AppException('User tidak ditemukan.');
    try {
      await _service.updateProfile(user.id, nama: nama.trim());
    } on PostgrestException catch (error) {
      throw AppException(error.message, code: error.code);
    }
  }

  /// Ambil data koperasi berdasarkan ID.
  Future<KoperasiModel?> getKoperasi(String koperasiId) async {
    try {
      final data = await _service.getKoperasi(koperasiId);
      if (data == null) return null;
      return KoperasiModel.fromMap(data);
    } on PostgrestException catch (error) {
      throw AppException(error.message, code: error.code);
    }
  }

  /// Update data koperasi.
  Future<void> updateKoperasi(
    String koperasiId, {
    String? namaKoperasi,
    String? alamat,
    String? telepon,
  }) async {
    try {
      await _service.updateKoperasi(
        koperasiId,
        namaKoperasi: namaKoperasi?.trim(),
        alamat: alamat?.trim(),
        telepon: telepon?.trim(),
      );
    } on PostgrestException catch (error) {
      throw AppException(error.message, code: error.code);
    }
  }

  // ─── Invite Management ────────────────────────────────────────────────────
  Future<void> sendInvite({
    required String koperasiId,
    required String email,
    required String role,
  }) async {
    try {
      await _service.sendInvite(
        koperasiId: koperasiId,
        email: email,
        role: role,
      );
    } on PostgrestException catch (error) {
      throw AppException(error.message, code: error.code);
    }
  }

  Future<List<UserInviteModel>> getInvitesByKoperasi(String koperasiId) async {
    try {
      final result = await _service.getInvitesByKoperasi(koperasiId);
      return result.map(UserInviteModel.fromMap).toList();
    } on PostgrestException catch (error) {
      throw AppException(error.message, code: error.code);
    }
  }

  Future<List<UserProfileModel>> getMembersByKoperasi(String koperasiId) async {
    try {
      final result = await _service.getMembersByKoperasi(koperasiId);
      return result.map(UserProfileModel.fromMap).toList();
    } on PostgrestException catch (error) {
      throw AppException(error.message, code: error.code);
    }
  }

  // ─── Password ─────────────────────────────────────────────────────────────
  Future<void> forgotPassword(String email) async {
    try {
      await _service.sendPasswordResetEmail(email.trim());
    } on AuthException catch (error) {
      throw AppException(_mapAuthError(error.message), code: error.statusCode);
    }
  }

  Future<void> changePassword(String password) async {
    if (currentSession == null) {
      throw const AppException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    try {
      await _service.changePassword(password);
    } on AuthException catch (error) {
      throw AppException(error.message, code: error.statusCode);
    }
  }

  // ─── Error mapping ────────────────────────────────────────────────────────
  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'Email atau password salah. Silakan periksa kembali.';
    }
    if (lower.contains('email already registered') ||
        lower.contains('user already registered')) {
      return 'Email sudah terdaftar. Silakan login atau gunakan email lain.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Periksa kotak masuk email Anda.';
    }
    if (lower.contains('too many requests')) {
      return 'Terlalu banyak percobaan. Silakan tunggu beberapa saat.';
    }
    if (lower.contains('rate limit')) {
      return 'Batas pengiriman email tercapai. Silakan tunggu sebelum mencoba lagi.';
    }
    if (lower.contains('email address not authorized')) {
      return 'Server email Supabase belum dikonfigurasi untuk mengirim ke alamat ini.';
    }
    return message;
  }
}
