import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_printer.dart';
import '../../domain/models/receipt_data.dart';
import '../../services/thermal_printer_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State model
// ─────────────────────────────────────────────────────────────────────────────
class ThermalPrinterState {
  const ThermalPrinterState({
    this.discoveredPrinters = const [],
    this.connectedPrinter,
    this.connectedPaperWidth,
    this.isScanning = false,
    this.isConnecting = false,
    this.isPrinting = false,
    this.isAutoReconnecting = false,
    this.errorMessage,
    this.successMessage,
  });

  final List<AppPrinter> discoveredPrinters;

  /// Printer yang saat ini terhubung, null jika belum ada.
  final AppPrinter? connectedPrinter;

  /// Ukuran kertas printer yang terhubung (58 atau 80).
  final int? connectedPaperWidth;

  final bool isScanning;
  final bool isConnecting;
  final bool isPrinting;

  /// True saat auto-reconnect berlangsung di background.
  final bool isAutoReconnecting;

  final String? errorMessage;
  final String? successMessage;

  bool get isConnected => connectedPrinter != null;

  ThermalPrinterState copyWith({
    List<AppPrinter>? discoveredPrinters,
    AppPrinter? connectedPrinter,
    bool clearConnectedPrinter = false,
    int? connectedPaperWidth,
    bool clearPaperWidth = false,
    bool? isScanning,
    bool? isConnecting,
    bool? isPrinting,
    bool? isAutoReconnecting,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ThermalPrinterState(
      discoveredPrinters: discoveredPrinters ?? this.discoveredPrinters,
      connectedPrinter: clearConnectedPrinter
          ? null
          : connectedPrinter ?? this.connectedPrinter,
      connectedPaperWidth: clearPaperWidth
          ? null
          : connectedPaperWidth ?? this.connectedPaperWidth,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      isPrinting: isPrinting ?? this.isPrinting,
      isAutoReconnecting: isAutoReconnecting ?? this.isAutoReconnecting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────
class ThermalPrinterController
    extends StateNotifier<ThermalPrinterState> {
  ThermalPrinterController(this._service)
      : super(const ThermalPrinterState()) {
    _init();
  }

  final ThermalPrinterService _service;
  StreamSubscription<List<AppPrinter>>? _scanSubscription;

  // ── Init: Auto Reconnect ──────────────────────────────────────────────────

  Future<void> _init() async {
    if (!_service.isSupported) return;

    // Muat preferensi tersimpan untuk tahu paper width saat auto-reconnect
    final pref = await _service.loadPrinterPreferences();
    if (pref == null) return;

    state = state.copyWith(isAutoReconnecting: true);
    final reconnected = await _service.tryAutoReconnect();
    if (mounted) {
      state = state.copyWith(
        isAutoReconnecting: false,
        connectedPrinter: reconnected,
        connectedPaperWidth: reconnected != null ? pref.paperWidth : null,
        clearConnectedPrinter: reconnected == null,
        clearPaperWidth: reconnected == null,
      );
    }
  }

  // ── Scan ──────────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (!_service.isSupported) return;
    if (state.isScanning) return;

    state = state.copyWith(
      isScanning: true,
      discoveredPrinters: [],
      clearError: true,
    );

    // Subscribe ke stream dulu
    await _scanSubscription?.cancel();
    _scanSubscription = _service.devicesStream.listen(
      (printers) {
        if (mounted) {
          state = state.copyWith(discoveredPrinters: printers);
        }
      },
      onError: (e) {
        if (mounted) {
          state = state.copyWith(
            isScanning: false,
            errorMessage: 'Gagal scan printer: $e',
          );
        }
      },
    );

    try {
      await _service.startScan(duration: const Duration(seconds: 6));
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isScanning: false,
          errorMessage: _friendlyError(e),
        );
      }
    }

    // Auto stop setelah 7 detik
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted && state.isScanning) {
        state = state.copyWith(isScanning: false);
      }
    });
  }

  Future<void> stopScan() async {
    await _service.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted) {
      state = state.copyWith(isScanning: false);
    }
  }

  // ── Connect ───────────────────────────────────────────────────────────────

  /// Connect ke [printer] dengan [paperWidth] (58 atau 80).
  ///
  /// Menyimpan ke SharedPreferences untuk auto-reconnect berikutnya.
  Future<bool> connect(AppPrinter printer, int paperWidth) async {
    if (!_service.isSupported) return false;

    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      final success = await _service.connect(printer);
      if (mounted) {
        if (success) {
          state = state.copyWith(
            isConnecting: false,
            connectedPrinter: printer,
            connectedPaperWidth: paperWidth,
            successMessage: 'Printer "${printer.name ?? printer.address}" terhubung!',
          );
          // Simpan untuk auto-reconnect
          await _service.savePrinterPreferences(
            printer: printer,
            paperWidth: paperWidth,
          );
        } else {
          state = state.copyWith(
            isConnecting: false,
            errorMessage: 'Gagal terhubung ke printer. Pastikan printer menyala dan dalam jangkauan.',
          );
        }
      }
      return success;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isConnecting: false,
          errorMessage: _friendlyError(e),
        );
      }
      return false;
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    final printer = state.connectedPrinter;
    if (printer == null) return;

    try {
      await _service.disconnect(printer);
      await _service.clearPrinterPreferences();
      if (mounted) {
        state = state.copyWith(
          clearConnectedPrinter: true,
          clearPaperWidth: true,
          successMessage: 'Printer terputus.',
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: _friendlyError(e));
      }
    }
  }

  // ── Print Receipt ─────────────────────────────────────────────────────────

  Future<bool> printReceipt(ReceiptData data) async {
    final printer = state.connectedPrinter;
    final paperWidth = state.connectedPaperWidth ?? 58;

    if (printer == null) {
      state = state.copyWith(
        errorMessage: 'Tidak ada printer terhubung. Buka Pengaturan → Printer Thermal.',
      );
      return false;
    }

    state = state.copyWith(isPrinting: true, clearError: true);
    try {
      await _service.printReceipt(
        data: data,
        printer: printer,
        paperWidth: paperWidth,
      );
      if (mounted) {
        state = state.copyWith(
          isPrinting: false,
          successMessage: 'Struk berhasil dicetak!',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: _friendlyError(e),
        );
      }
      return false;
    }
  }

  // ── Test Print ────────────────────────────────────────────────────────────

  Future<bool> testPrint() async {
    final printer = state.connectedPrinter;
    final paperWidth = state.connectedPaperWidth ?? 58;

    if (printer == null) {
      state = state.copyWith(errorMessage: 'Tidak ada printer terhubung.');
      return false;
    }

    state = state.copyWith(isPrinting: true, clearError: true);
    try {
      await _service.testPrint(printer: printer, paperWidth: paperWidth);
      if (mounted) {
        state = state.copyWith(
          isPrinting: false,
          successMessage: 'Test print berhasil! Printer berfungsi normal.',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: _friendlyError(e),
        );
      }
      return false;
    }
  }

  // ── Clear Messages ────────────────────────────────────────────────────────

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  // ── Error message helper ──────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('bluetooth') && msg.contains('off')) {
      return 'Bluetooth tidak aktif. Aktifkan Bluetooth di pengaturan perangkat.';
    }
    if (msg.contains('permission')) {
      return 'Izin Bluetooth diperlukan. Berikan izin di pengaturan aplikasi.';
    }
    if (msg.contains('timeout')) {
      return 'Koneksi timeout. Pastikan printer menyala dan dalam jangkauan.';
    }
    if (msg.contains('disconnect') || msg.contains('not connected')) {
      return 'Printer terputus. Coba hubungkan kembali.';
    }
    return 'Terjadi kesalahan: $e';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Provider utama untuk state & controller thermal printer.
final thermalPrinterControllerProvider =
    StateNotifierProvider<ThermalPrinterController, ThermalPrinterState>(
  (ref) {
    final service = ref.watch(thermalPrinterServiceProvider);
    return ThermalPrinterController(service);
  },
);

/// Shortcut: apakah thermal printer tersedia di platform ini.
final thermalPrinterSupportedProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isWindows;
});

/// Shortcut: apakah saat ini ada printer yang terhubung.
final isThermalPrinterConnectedProvider = Provider<bool>((ref) {
  return ref.watch(thermalPrinterControllerProvider).isConnected;
});
