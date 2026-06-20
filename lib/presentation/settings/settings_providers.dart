import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/auth_providers.dart';

class SettingsState {
  const SettingsState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  SettingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearMessages ? null : successMessage ?? this.successMessage,
    );
  }
}

final settingsControllerProvider =
    StateNotifierProvider.autoDispose<SettingsController, SettingsState>((ref) {
  return SettingsController(ref);
});

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._ref) : super(const SettingsState());

  final Ref _ref;

  AuthRepository get _repository => _ref.read(authRepositoryProvider);

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  Future<bool> updateProfileName(String nama) async {
    state = const SettingsState(isLoading: true);
    try {
      await _repository.updateProfileName(nama);
      // Invalidate provider agar UI langsung update dengan data terbaru
      _ref.invalidate(currentProfileProvider);
      state = const SettingsState(successMessage: 'Profil berhasil diperbarui.');
      return true;
    } on AppException catch (e) {
      state = SettingsState(errorMessage: e.message);
      return false;
    } catch (_) {
      state = const SettingsState(
          errorMessage: 'Gagal memperbarui profil. Coba lagi.');
      return false;
    }
  }

  Future<bool> updateKoperasi({
    required String namaKoperasi,
    String? alamat,
    String? telepon,
  }) async {
    final profile = await _ref.read(currentProfileProvider.future);
    if (profile?.koperasiId == null) {
      state = const SettingsState(errorMessage: 'Koperasi tidak ditemukan.');
      return false;
    }

    state = const SettingsState(isLoading: true);
    try {
      await _repository.updateKoperasi(
        profile!.koperasiId!,
        namaKoperasi: namaKoperasi,
        alamat: alamat,
        telepon: telepon,
      );
      // Invalidate provider agar UI koperasi update
      _ref.invalidate(currentKoperasiProvider);
      state = const SettingsState(successMessage: 'Profil Koperasi berhasil diperbarui.');
      return true;
    } on AppException catch (e) {
      state = SettingsState(errorMessage: e.message);
      return false;
    } catch (_) {
      state = const SettingsState(
          errorMessage: 'Gagal memperbarui koperasi. Coba lagi.');
      return false;
    }
  }
}
