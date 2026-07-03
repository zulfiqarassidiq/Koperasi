import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/produk_model.dart';
import '../../data/models/transaksi_detail_item_model.dart';
import '../../data/models/transaksi_model.dart';
import '../../data/repositories/transaksi_repository.dart';
import '../../domain/models/receipt_data.dart';
import '../../services/receipt_service.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../produk/produk_providers.dart';

const paymentMethods = ['Cash', 'Transfer', 'QRIS'];

/// Menyimpan [ReceiptData] dari transaksi yang baru saja berhasil.
/// Di-reset ke null saat dialog transaksi sukses ditutup (via clearReceipt).
/// Digunakan oleh [TransaksiSuksesDialog] untuk preview & cetak PDF.
final receiptDataAfterCheckoutProvider =
    StateProvider<ReceiptData?>((ref) => null);

final transaksiProductSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

/// Cari produk hanya dari koperasi yang sedang login.
final transaksiProductResultsProvider =
    FutureProvider.autoDispose<List<ProdukModel>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';
  if (koperasiId.isEmpty) return [];
  final search = ref.watch(transaksiProductSearchProvider);
  return ref.watch(transaksiRepositoryProvider).searchProducts(
        koperasiId: koperasiId,
        search: search,
      );
});

/// Ambil riwayat transaksi hanya milik koperasi yang sedang login.
final transaksiHistoryProvider =
    FutureProvider.autoDispose<List<TransaksiModel>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final koperasiId = profile?.koperasiId ?? '';
  if (koperasiId.isEmpty) return [];
  return ref
      .watch(transaksiRepositoryProvider)
      .findHistory(koperasiId: koperasiId);
});

final transaksiDetailProvider =
    FutureProvider.autoDispose.family<TransaksiModel, String>((ref, id) {
  return ref.watch(transaksiRepositoryProvider).findTransactionById(id);
});

final transaksiDetailItemsProvider = FutureProvider.autoDispose
    .family<List<TransaksiDetailItemModel>, String>((ref, transactionId) {
  return ref.watch(transaksiRepositoryProvider).findDetails(transactionId);
});

final cartControllerProvider =
    StateNotifierProvider.autoDispose<CartController, CartState>((ref) {
  return CartController(ref);
});

class CartState {
  const CartState({
    this.items = const [],
    this.paymentMethod = 'Cash',
    this.isCheckingOut = false,
    this.errorMessage,
    this.successMessage,
  });

  final List<CartItemModel> items;
  final String paymentMethod;
  final bool isCheckingOut;
  final String? errorMessage;
  final String? successMessage;

  /// Snapshot items saat checkout untuk membangun ReceiptData.
  /// Cart items di-clear setelah checkout berhasil sehingga perlu di-capture dulu.
  List<CartItemModel> get itemsSnapshot => List.unmodifiable(items);

  num get grandTotal {
    return items.fold<num>(0, (sum, item) => sum + item.subtotal);
  }

  int get totalQty {
    return items.fold<int>(0, (sum, item) => sum + item.qty);
  }

  CartState copyWith({
    List<CartItemModel>? items,
    String? paymentMethod,
    bool? isCheckingOut,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return CartState(
      items: items ?? this.items,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      errorMessage: clearMessages ? null : errorMessage,
      successMessage: clearMessages ? null : successMessage,
    );
  }
}

class CartController extends StateNotifier<CartState> {
  CartController(this._ref) : super(const CartState());

  final Ref _ref;

  TransaksiRepository get _repository => _ref.read(transaksiRepositoryProvider);

  void setPaymentMethod(String value) {
    state = state.copyWith(paymentMethod: value, clearMessages: true);
  }

  void addProduct(ProdukModel product) {
    if (product.stok <= 0) {
      state = state.copyWith(
        errorMessage: 'Stok ${product.namaProduk} kosong.',
      );
      return;
    }

    final index =
        state.items.indexWhere((item) => item.product.id == product.id);
    if (index == -1) {
      state = state.copyWith(
        items: [...state.items, CartItemModel(product: product, qty: 1)],
        clearMessages: true,
      );
      return;
    }

    increase(product.id);
  }

  void increase(String productId) {
    state = _changeQty(productId, 1);
  }

  void decrease(String productId) {
    CartItemModel? selectedItem;
    for (final item in state.items) {
      if (item.product.id == productId) {
        selectedItem = item;
        break;
      }
    }

    final item = selectedItem;
    if (item == null) return;

    if (item.qty <= 1) {
      remove(productId);
      return;
    }

    state = _changeQty(productId, -1);
  }

  void remove(String productId) {
    state = state.copyWith(
      items: state.items.where((item) => item.product.id != productId).toList(),
      clearMessages: true,
    );
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  /// Checkout transaksi, otomatis menyisipkan koperasi_id dari profil user.
  /// Setelah berhasil, membangun [ReceiptData] dan menyimpannya di
  /// [receiptDataAfterCheckoutProvider] untuk ditampilkan di dialog sukses.
  Future<bool> checkout() async {
    if (state.items.isEmpty) {
      state = state.copyWith(errorMessage: 'Keranjang tidak boleh kosong.');
      return false;
    }

    // Ambil profil dan koperasi user yang sedang login
    final profile = await _ref.read(currentProfileProvider.future);
    final koperasiId = profile?.koperasiId ?? '';
    if (koperasiId.isEmpty) {
      debugPrint('[CartController.checkout] ERROR: koperasi_id tidak ditemukan!');
      state = state.copyWith(
        isCheckingOut: false,
        errorMessage: 'Koperasi tidak ditemukan. Silakan login ulang.',
      );
      return false;
    }

    final koperasi = await _ref.read(currentKoperasiProvider.future);
    if (koperasi == null) {
      debugPrint('[CartController.checkout] ERROR: data koperasi tidak ditemukan!');
      state = state.copyWith(
        isCheckingOut: false,
        errorMessage: 'Data koperasi tidak ditemukan. Silakan login ulang.',
      );
      return false;
    }

    // Snapshot items sebelum cart di-clear
    final cartItemsSnapshot = state.itemsSnapshot.toList();
    final paymentMethodSnapshot = state.paymentMethod;
    final now = DateTime.now();

    state = state.copyWith(isCheckingOut: true, clearMessages: true);

    try {
      final transaction = await _repository.checkout(
        items: cartItemsSnapshot,
        paymentMethod: paymentMethodSnapshot,
        koperasiId: koperasiId,
      );

      // Bangun ReceiptData dari data yang sudah ada di memori (tanpa re-fetch)
      if (profile != null) {
        try {
          final receiptData = _ref.read(receiptServiceProvider).buildFromCart(
                cartItems: cartItemsSnapshot,
                profile: profile,
                koperasi: koperasi,
                transactionId: transaction.id,
                tanggal: transaction.tanggal.isAfter(
                        DateTime(2000))
                    ? transaction.tanggal
                    : now,
                paymentMethod: paymentMethodSnapshot,
              );
          _ref.read(receiptDataAfterCheckoutProvider.notifier).state =
              receiptData;
        } catch (e) {
          // Receipt building tidak boleh memblok checkout sukses
          debugPrint('[CartController.checkout] Gagal build ReceiptData: $e');
        }
      }

      state = CartState(
        paymentMethod: paymentMethodSnapshot,
        successMessage: 'Checkout berhasil.',
      );
      _ref.invalidate(transaksiProductResultsProvider);
      _ref.invalidate(transaksiHistoryProvider);
      _ref.invalidate(dashboardStatsProvider);
      _ref.invalidate(produkControllerProvider);
      return true;
    } on AppException catch (error) {
      debugPrint('[CartController.checkout] AppException: ${error.message}');
      state = state.copyWith(
        isCheckingOut: false,
        errorMessage: error.message,
      );
      return false;
    } catch (e) {
      debugPrint('[CartController.checkout] Unexpected error: $e');
      state = state.copyWith(
        isCheckingOut: false,
        errorMessage: 'Checkout gagal. Silakan coba lagi.',
      );
      return false;
    }
  }

  CartState _changeQty(String productId, int delta) {
    final updated = <CartItemModel>[];
    String? errorMessage;

    for (final item in state.items) {
      if (item.product.id != productId) {
        updated.add(item);
        continue;
      }

      final nextQty = item.qty + delta;
      if (nextQty <= 0) {
        continue;
      }

      if (nextQty > item.product.stok) {
        errorMessage =
            'Qty ${item.product.namaProduk} tidak boleh melebihi stok.';
        updated.add(item);
        continue;
      }

      updated.add(item.copyWith(qty: nextQty));
    }

    return state.copyWith(items: updated, errorMessage: errorMessage);
  }
}
