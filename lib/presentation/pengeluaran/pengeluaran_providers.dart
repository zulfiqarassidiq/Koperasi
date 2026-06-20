import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/pengeluaran_model.dart';
import '../../data/repositories/pengeluaran_repository.dart';
import '../auth/auth_providers.dart';

final pengeluaranSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

final pengeluaranControllerProvider = AutoDisposeAsyncNotifierProvider<
    PengeluaranController, List<PengeluaranModel>>(
  PengeluaranController.new,
);

class PengeluaranController
    extends AutoDisposeAsyncNotifier<List<PengeluaranModel>> {
  PengeluaranRepository get _repository =>
      ref.read(pengeluaranRepositoryProvider);

  @override
  FutureOr<List<PengeluaranModel>> build() {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Catat pengeluaran, otomatis menyisipkan koperasi_id.
  Future<bool> addExpense({
    required String keterangan,
    required num jumlah,
  }) async {
    final koperasiId = await _getKoperasiId();
    if (koperasiId == null) {
      debugPrint('[PengeluaranController.addExpense] ERROR: koperasi_id tidak ditemukan!');
      return false;
    }
    return _mutate(() => _repository.create(
          keterangan: keterangan,
          jumlah: jumlah,
          koperasiId: koperasiId,
        ));
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
      debugPrint('[PengeluaranController] AppException: ${error.message}');
      state = AsyncError(error, stackTrace);
      return false;
    } catch (error, stackTrace) {
      debugPrint('[PengeluaranController] Unexpected error: $error');
      state = AsyncError(error, stackTrace);
      state = previous;
      return false;
    }
  }

  Future<List<PengeluaranModel>> _load() async {
    final profile = await ref.read(currentProfileProvider.future);
    final koperasiId = profile?.koperasiId ?? '';
    final search = ref.watch(pengeluaranSearchProvider);

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
