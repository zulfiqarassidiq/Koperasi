import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_printer.dart';
import '../domain/models/receipt_data.dart';
import 'thermal_printer_service_stub.dart'
    if (dart.library.io) 'thermal_printer_service_io.dart';

abstract class ThermalPrinterService {
  bool get isSupported;
  List<AppPrinterConnectionType> get platformConnectionTypes;
  
  Stream<List<AppPrinter>> get devicesStream;
  Stream<bool> get bluetoothStateStream;

  Future<void> startScan({Duration duration = const Duration(seconds: 5)});
  Future<void> stopScan();

  Future<bool> connect(AppPrinter printer);
  Future<void> disconnect(AppPrinter printer);

  Future<void> printReceipt({
    required ReceiptData data,
    required AppPrinter printer,
    required int paperWidth,
  });

  Future<void> testPrint({
    required AppPrinter printer,
    required int paperWidth,
  });

  Future<void> savePrinterPreferences({
    required AppPrinter printer,
    required int paperWidth,
  });

  Future<({AppPrinter printer, int paperWidth})?> loadPrinterPreferences();
  
  Future<void> clearPrinterPreferences();
  
  Future<AppPrinter?> tryAutoReconnect();
}

/// Provider utama untuk mendapatkan ThermalPrinterService
final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return createThermalPrinterService();
});
