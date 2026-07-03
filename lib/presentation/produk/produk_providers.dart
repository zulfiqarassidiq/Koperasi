import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/kategori_produk_model.dart';
import '../../data/models/produk_model.dart';
import '../../data/repositories/produk_repository.dart';
import '../auth/auth_providers.dart';

final produkSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final produkControllerProvider =
    AutoDisposeAsyncNotifierProvider<ProdukController, List<ProdukModel>>(
  ProdukController.new,
);

final produkDetailProvider =
    FutureProvider.autoDispose.family<ProdukModel, String>((ref, id) {
  return ref.watch(produkRepositoryProvider).findById(id);
});

final produkKategoriProvider =
    FutureProvider.autoDispose<List<KategoriProdukModel>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';
  if (koperasiId.isEmpty) return [];
  return ref
      .watch(produkRepositoryProvider)
      .findCategories(koperasiId: koperasiId);
});

/// Generate kode produk nomor urut berikutnya, di-scope per koperasi.
/// Aman digunakan karena DB constraint sudah UNIQUE(koperasi_id, kode_produk).
final nextKodeProdukProvider = FutureProvider.autoDispose<String>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';
  if (koperasiId.isEmpty) return 'PRD-000001';
  return ref
      .watch(produkRepositoryProvider)
      .generateKodeProduk(koperasiId: koperasiId);
});

class ProdukController extends AutoDisposeAsyncNotifier<List<ProdukModel>> {
  ProdukRepository get _repository => ref.read(produkRepositoryProvider);

  @override
  FutureOr<List<ProdukModel>> build() {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Buat produk baru, otomatis menyisipkan koperasi_id dari profil user.
  Future<bool> create(ProdukModel product) async {
    final koperasiId = await _getKoperasiId();
    if (koperasiId == null) {
      debugPrint('[ProdukController.create] ERROR: koperasi_id tidak ditemukan!');
      return false;
    }
    return _mutate(
      () => _repository.create(product: product, koperasiId: koperasiId),
    );
  }

  /// Update produk, koperasi_id tetap tersimpan.
  Future<bool> updateProduct(ProdukModel product) async {
    final koperasiId = await _getKoperasiId();
    if (koperasiId == null) {
      debugPrint('[ProdukController.updateProduct] ERROR: koperasi_id tidak ditemukan!');
      return false;
    }
    return _mutate(
      () => _repository.updateProduct(product: product, koperasiId: koperasiId),
    );
  }

  Future<bool> delete(String id) async {
    return _mutate(() => _repository.delete(id));
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    state = const AsyncLoading();

    try {
      await action();
      state = await AsyncValue.guard(_load);
      return true;
    } on AppException catch (error, stackTrace) {
      debugPrint('[ProdukController] AppException: ${error.message}');
      state = AsyncError(error, stackTrace);
      return false;
    } catch (error, stackTrace) {
      debugPrint('[ProdukController] Unexpected error: $error');
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<List<ProdukModel>> _load() async {
    final profile = await ref.read(currentProfileProvider.future);
    final koperasiId = profile?.koperasiId ?? '';
    final search = ref.watch(produkSearchProvider);

    if (koperasiId.isEmpty) return [];
    return _repository.findAll(koperasiId: koperasiId, search: search);
  }

  Future<String?> _getKoperasiId() async {
    final profile = await ref.read(currentProfileProvider.future);
    final id = profile?.koperasiId;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Generate kode produk on-demand (untuk tombol refresh di form).
  Future<String> generateKode() async {
    final koperasiId = await _getKoperasiId();
    if (koperasiId == null) return 'PRD-000001';
    return _repository.generateKodeProduk(koperasiId: koperasiId);
  }
}
