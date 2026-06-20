import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/produk_model.dart';
import '../../data/models/stok_masuk_model.dart';
import '../../data/repositories/stok_repository.dart';
import '../auth/auth_providers.dart';

final stokSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final stokProductFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final stokDateFilterProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

final stokControllerProvider =
    AutoDisposeAsyncNotifierProvider<StokController, List<StokMasukModel>>(
  StokController.new,
);

final stokDetailProvider =
    FutureProvider.autoDispose.family<StokMasukModel, String>((ref, id) {
  return ref.watch(stokRepositoryProvider).findById(id);
});

final stokProductOptionsProvider =
    FutureProvider.autoDispose<List<ProdukModel>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';
  if (koperasiId.isEmpty) return [];
  return ref
      .watch(stokRepositoryProvider)
      .findProductOptions(koperasiId: koperasiId);
});

class StokController extends AutoDisposeAsyncNotifier<List<StokMasukModel>> {
  StokRepository get _repository => ref.read(stokRepositoryProvider);

  @override
  FutureOr<List<StokMasukModel>> build() {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Tambah stok, otomatis menyisipkan koperasi_id.
  Future<bool> addStock(StokMasukModel stock) async {
    final koperasiId = await _getKoperasiId();
    if (koperasiId == null) {
      debugPrint('[StokController.addStock] ERROR: koperasi_id tidak ditemukan!');
      return false;
    }

    state = const AsyncLoading();

    try {
      await _repository.addStock(stock: stock, koperasiId: koperasiId);
      state = await AsyncValue.guard(_load);
      ref.invalidate(stokDetailProvider);
      return true;
    } on AppException catch (error, stackTrace) {
      debugPrint('[StokController.addStock] AppException: ${error.message}');
      state = AsyncError(error, stackTrace);
      return false;
    } catch (error, stackTrace) {
      debugPrint('[StokController.addStock] Unexpected error: $error');
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<List<StokMasukModel>> _load() async {
    final profile = await ref.read(currentProfileProvider.future);
    final koperasiId = profile?.koperasiId ?? '';

    if (koperasiId.isEmpty) return [];

    final filter = StokFilter(
      koperasiId: koperasiId,
      search: ref.watch(stokSearchProvider),
      produkId: ref.watch(stokProductFilterProvider),
      tanggal: ref.watch(stokDateFilterProvider),
    );
    return _repository.findAll(filter);
  }

  Future<String?> _getKoperasiId() async {
    final profile = await ref.read(currentProfileProvider.future);
    final id = profile?.koperasiId;
    if (id == null || id.isEmpty) return null;
    return id;
  }
}
