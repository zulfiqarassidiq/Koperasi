import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/auth_links.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

class AuthService {
  const AuthService(this._client);

  final SupabaseClient _client;

  /// Raw Supabase client — gunakan dengan hati-hati.
  SupabaseClient get client => _client;

  // ─── Session helpers ──────────────────────────────────────────────────────
  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<Session?> get sessionChanges async* {
    yield currentSession;
    yield* _client.auth.onAuthStateChange.map((event) => event.session);
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─── Login / Logout ───────────────────────────────────────────────────────
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  // ─── Registration ─────────────────────────────────────────────────────────
  /// Daftar akun baru. Data (nama) disimpan sebagai user_metadata.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nama,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'nama': nama},
    );
  }

  // ─── Password ─────────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AuthLinks.passwordResetUrl,
    );
  }

  Future<UserResponse> changePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  // ─── Profile ──────────────────────────────────────────────────────────────
  /// Ambil profil user dari tabel profiles.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final result =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return result;
  }

  /// Insert atau upsert profil user baru.
  Future<void> upsertProfile(Map<String, dynamic> data) async {
    await _client.from('profiles').upsert(data);
  }

  /// Update profil (partial update: koperasi_id & role setelah onboarding).
  Future<void> updateProfile(
    String userId, {
    String? koperasiId,
    String? role,
    String? nama,
  }) async {
    final updates = <String, dynamic>{};
    if (koperasiId != null) updates['koperasi_id'] = koperasiId;
    if (role != null) updates['role'] = role;
    if (nama != null) updates['nama'] = nama;
    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', userId);
  }

  // ─── Koperasi ─────────────────────────────────────────────────────────────
  /// Insert koperasi baru dan kembalikan data lengkapnya.
  Future<Map<String, dynamic>> insertKoperasi(Map<String, dynamic> data) async {
    final result =
        await _client.from('koperasi').insert(data).select().single();
    return result;
  }

  Future<Map<String, dynamic>?> getKoperasi(String koperasiId) async {
    final result = await _client
        .from('koperasi')
        .select()
        .eq('id', koperasiId)
        .maybeSingle();
    return result;
  }

  /// Update data koperasi.
  Future<void> updateKoperasi(
    String koperasiId, {
    String? namaKoperasi,
    String? alamat,
    String? telepon,
  }) async {
    final updates = <String, dynamic>{};
    if (namaKoperasi != null) updates['nama_koperasi'] = namaKoperasi;
    if (alamat != null) updates['alamat'] = alamat;
    if (telepon != null) updates['telepon'] = telepon;

    if (updates.isEmpty) return;

    await _client.from('koperasi').update(updates).eq('id', koperasiId);
  }

  // ─── User Invites ─────────────────────────────────────────────────────────
  /// Cek apakah email ada di tabel user_invites dengan status pending.
  Future<Map<String, dynamic>?> getPendingInvite(String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    debugPrint(
        '[AuthService.getPendingInvite] Querying user_invites for email: $normalizedEmail');
    try {
      final result = await _client
          .from('user_invites')
          .select()
          .eq('email', normalizedEmail)
          .eq('status', 'pending')
          .maybeSingle();
      debugPrint('[AuthService.getPendingInvite] Result: $result');
      return result;
    } catch (e) {
      debugPrint('[AuthService.getPendingInvite] ERROR: $e');
      return null; // Kembalikan null agar caller bisa lanjut (RLS error, dll.)
    }
  }

  /// Update status invite menjadi accepted.
  Future<void> acceptInvite(String inviteId) async {
    debugPrint('[AuthService.acceptInvite] Updating invite id: $inviteId');
    await _client
        .from('user_invites')
        .update({'status': 'accepted'}).eq('id', inviteId);
    debugPrint('[AuthService.acceptInvite] Done.');
  }

  /// Kirim invite baru (dari owner).
  Future<void> sendInvite({
    required String koperasiId,
    required String email,
    required String role,
  }) async {
    await _client.from('user_invites').insert({
      'koperasi_id': koperasiId,
      'email': email.toLowerCase().trim(),
      'role': role,
      'status': 'pending',
    });
  }

  /// Ambil semua invite untuk koperasi tertentu.
  Future<List<Map<String, dynamic>>> getInvitesByKoperasi(
      String koperasiId) async {
    final result = await _client
        .from('user_invites')
        .select()
        .eq('koperasi_id', koperasiId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Ambil semua user member dari koperasi (dari tabel profiles).
  Future<List<Map<String, dynamic>>> getMembersByKoperasi(
      String koperasiId) async {
    final result = await _client
        .from('profiles')
        .select()
        .eq('koperasi_id', koperasiId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(result);
  }
}
