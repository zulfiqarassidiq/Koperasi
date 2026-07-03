import '../domain/models/app_printer.dart';
import '../domain/models/receipt_data.dart';
import 'thermal_printer_service.dart';

ThermalPrinterService createThermalPrinterService() => _ThermalPrinterServiceStub();

class _ThermalPrinterServiceStub implements ThermalPrinterService {
  @override
  bool get isSupported => false;

  @override
  List<AppPrinterConnectionType> get platformConnectionTypes => [];

  @override
  Stream<List<AppPrinter>> get devicesStream => const Stream.empty();

  @override
  Stream<bool> get bluetoothStateStream => const Stream.empty();

  @override
  Future<void> startScan({Duration duration = const Duration(seconds: 5)}) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<bool> connect(AppPrinter printer) async => false;

  @override
  Future<void> disconnect(AppPrinter printer) async {}

  @override
  Future<void> printReceipt({
    required ReceiptData data,
    required AppPrinter printer,
    required int paperWidth,
  }) async {
    throw Exception('Thermal printing is not supported on Web.');
  }

  @override
  Future<void> testPrint({
    required AppPrinter printer,
    required int paperWidth,
  }) async {
    throw Exception('Thermal printing is not supported on Web.');
  }

  @override
  Future<void> savePrinterPreferences({
    required AppPrinter printer,
    required int paperWidth,
  }) async {}

  @override
  Future<({AppPrinter printer, int paperWidth})?> loadPrinterPreferences() async => null;

  @override
  Future<void> clearPrinterPreferences() async {}

  @override
  Future<AppPrinter?> tryAutoReconnect() async => null;
}
