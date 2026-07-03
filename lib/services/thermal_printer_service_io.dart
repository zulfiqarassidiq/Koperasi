import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/app_printer.dart';
import '../domain/models/receipt_data.dart';
import 'thermal_printer_service.dart';
import 'thermal_receipt_formatter.dart';

ThermalPrinterService createThermalPrinterService() => _ThermalPrinterServiceIo();

class _ThermalPrinterServiceIo implements ThermalPrinterService {
  final _plugin = FlutterThermalPrinter.instance;

  @override
  bool get isSupported {
    return Platform.isAndroid || Platform.isWindows;
  }

  @override
  List<AppPrinterConnectionType> get platformConnectionTypes {
    if (!isSupported) return [];
    if (Platform.isAndroid) return [AppPrinterConnectionType.ble, AppPrinterConnectionType.usb];
    if (Platform.isWindows) return [AppPrinterConnectionType.usb, AppPrinterConnectionType.ble];
    return [];
  }

  ConnectionType _toPluginConnectionType(AppPrinterConnectionType type) {
    switch (type) {
      case AppPrinterConnectionType.ble:
      case AppPrinterConnectionType.bluetooth:
        return ConnectionType.BLE;
      case AppPrinterConnectionType.usb:
        return ConnectionType.USB;
      case AppPrinterConnectionType.network:
        return ConnectionType.NETWORK;
      default:
        return ConnectionType.USB;
    }
  }

  AppPrinterConnectionType _toAppConnectionType(ConnectionType? type) {
    if (type == ConnectionType.BLE) return AppPrinterConnectionType.ble;
    if (type == ConnectionType.USB) return AppPrinterConnectionType.usb;
    if (type == ConnectionType.NETWORK) return AppPrinterConnectionType.network;
    return AppPrinterConnectionType.unknown;
  }

  AppPrinter _toAppPrinter(Printer p) {
    return AppPrinter(
      name: p.name,
      address: p.address,
      connectionType: _toAppConnectionType(p.connectionType),
      isConnected: p.isConnected ?? false,
      vendorData: p.toJson(),
    );
  }

  Printer? _toPluginPrinter(AppPrinter p) {
    if (p.vendorData != null) {
      return Printer.fromJson(p.vendorData!);
    }
    return null;
  }

  @override
  Stream<List<AppPrinter>> get devicesStream {
    if (!isSupported) return const Stream.empty();
    return _plugin.devicesStream.map((list) => list.map(_toAppPrinter).toList());
  }

  @override
  Future<void> startScan({Duration duration = const Duration(seconds: 5)}) async {
    if (!isSupported) return;
    await _plugin.getPrinters(
      refreshDuration: duration,
      connectionTypes: platformConnectionTypes.map(_toPluginConnectionType).toList(),
    );
  }

  @override
  Future<void> stopScan() async {
    if (!isSupported) return;
    await _plugin.stopScan();
  }

  @override
  Future<bool> connect(AppPrinter printer) async {
    if (!isSupported) return false;
    final pluginPrinter = _toPluginPrinter(printer);
    if (pluginPrinter == null) return false;
    try {
      return await _plugin.connect(pluginPrinter);
    } catch (e) {
      debugPrint('[ThermalPrinterServiceIo] connect error: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect(AppPrinter printer) async {
    if (!isSupported) return;
    final pluginPrinter = _toPluginPrinter(printer);
    if (pluginPrinter == null) return;
    try {
      await _plugin.disconnect(pluginPrinter);
    } catch (e) {
      debugPrint('[ThermalPrinterServiceIo] disconnect error: $e');
    }
  }

  @override
  Future<void> printReceipt({
    required ReceiptData data,
    required AppPrinter printer,
    required int paperWidth,
  }) async {
    if (!isSupported) throw Exception('Thermal printing tidak didukung di platform ini.');
    final pluginPrinter = _toPluginPrinter(printer);
    if (pluginPrinter == null) throw Exception('Printer tidak valid.');

    final formatter = EscPosFormatter(paperWidth: paperWidth);
    final bytes = await formatter.format(data);
    await _printBytes(pluginPrinter: pluginPrinter, bytes: bytes);
  }

  @override
  Future<void> testPrint({
    required AppPrinter printer,
    required int paperWidth,
  }) async {
    if (!isSupported) throw Exception('Thermal printing tidak didukung di platform ini.');
    final pluginPrinter = _toPluginPrinter(printer);
    if (pluginPrinter == null) throw Exception('Printer tidak valid.');

    final formatter = EscPosFormatter(paperWidth: paperWidth);
    final testData = ReceiptData.testData();
    final bytes = await formatter.format(testData);
    await _printBytes(pluginPrinter: pluginPrinter, bytes: bytes);
  }

  @override
  Stream<bool> get bluetoothStateStream {
    if (!isSupported || !Platform.isAndroid) return const Stream.empty();
    try {
      return _plugin.isBleTurnedOnStream;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<void> savePrinterPreferences({
    required AppPrinter printer,
    required int paperWidth,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('thermal_printer_saved_printer', jsonEncode(printer.toJson()));
      await prefs.setInt('thermal_printer_paper_width', paperWidth);
      debugPrint('[ThermalPrinterServiceIo] Saved printer: ${printer.name}');
    } catch (e) {
      debugPrint('[ThermalPrinterServiceIo] savePrinterPreferences error: $e');
    }
  }

  @override
  Future<({AppPrinter printer, int paperWidth})?> loadPrinterPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('thermal_printer_saved_printer');
      if (jsonStr == null) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final printer = AppPrinter.fromJson(map);
      final paperWidth = prefs.getInt('thermal_printer_paper_width') ?? 58;
      return (printer: printer, paperWidth: paperWidth);
    } catch (e) {
      debugPrint('[ThermalPrinterServiceIo] loadPrinterPreferences error: $e');
      return null;
    }
  }

  @override
  Future<void> clearPrinterPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('thermal_printer_saved_printer');
      await prefs.remove('thermal_printer_paper_width');
    } catch (e) {
      debugPrint('[ThermalPrinterServiceIo] clearPrinterPreferences error: $e');
    }
  }

  @override
  Future<AppPrinter?> tryAutoReconnect() async {
    if (!isSupported) return null;
    final pref = await loadPrinterPreferences();
    if (pref == null) return null;

    debugPrint('[ThermalPrinterServiceIo] Trying auto-reconnect to: ${pref.printer.name}');
    try {
      final success = await connect(pref.printer);
      if (success) {
        debugPrint('[ThermalPrinterServiceIo] Auto-reconnect success: ${pref.printer.name}');
        return pref.printer;
      }
      return null;
    } catch (e) {
      debugPrint('[ThermalPrinterServiceIo] Auto-reconnect error: $e');
      return null;
    }
  }

  Future<void> _printBytes({
    required Printer pluginPrinter,
    required List<int> bytes,
  }) async {
    try {
      await _plugin.printData(pluginPrinter, bytes);
    } catch (e) {
      throw Exception('Gagal mengirim data ke printer: $e');
    }
  }
}
