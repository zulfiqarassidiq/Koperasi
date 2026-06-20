import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/kategori_produk_model.dart';
import '../../data/repositories/kategori_repository.dart';
import '../auth/auth_providers.dart';

final kategoriSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final kategoriControllerProvider = AutoDisposeAsyncNotifierProvider<
    KategoriController, List<KategoriProdukModel>>(KategoriController.new);

class KategoriController
    extends AutoDisposeAsyncNotifier<List<KategoriProdukModel>> {
  KategoriRepository get _repository => ref.read(kategoriRepositoryProvider);

  @override
  FutureOr<List<KategoriProdukModel>> build() {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Buat kategori baru, otomatis menyisipkan koperasi_id.
  Future<bool> create(String namaKategori) async {
    final koperasiId = await _getKoperasiId();
    if (koperasiId == null) {
      debugPrint('[KategoriController.create] ERROR: koperasi_id tidak ditemukan!');
      return false;
    }
    return _mutate(
      () => _repository.create(
        namaKategori: namaKategori,
        koperasiId: koperasiId,
      ),
    );
  }

  Future<bool> updateCategory({
    required String id,
    required String namaKategori,
  }) async {
    return _mutate(
      () => _repository.update(id: id, namaKategori: namaKategori),
    );
  }

  Future<bool> delete(String id) async {
    return _mutate(() => _repository.delete(id));
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    final previous = state;
    state = const AsyncLoading();

    try {
      await action();
      state = await AsyncValue.guard(_load);
      return true;
    } on AppException catch (error, stackTrace) {
      debugPrint('[KategoriController] AppException: ${error.message}');
      state = AsyncError(error, stackTrace);
      return false;
    } catch (error, stackTrace) {
      debugPrint('[KategoriController] Unexpected error: $error');
      state = AsyncError(error, stackTrace);
      state = previous;
      return false;
    }
  }

  Future<List<KategoriProdukModel>> _load() async {
    final profile = await ref.read(currentProfileProvider.future);
    final koperasiId = profile?.koperasiId ?? '';
    final search = ref.watch(kategoriSearchProvider);

    if (koperasiId.isEmpty) return [];
    return _repository.findAll(koperasiId: koperasiId, search: search);
  }

  Future<String?> _getKoperasiId() async {
    final profile = await ref.read(currentProfileProvider.future);
    final id = profile?.koperasiId;
    if (id == null || id.isEmpty) return null;
    return id;
  }
}
