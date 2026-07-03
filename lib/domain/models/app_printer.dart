enum AppPrinterConnectionType {
  usb,
  bluetooth,
  ble,
  network,
  unknown
}

/// Abstraksi perangkat printer untuk mengisolasi package platform-specific
/// (seperti flutter_thermal_printer) dari kode multi-platform, sehingga Web
/// tetap dapat dicompile dengan aman tanpa memicu error ffi/win32.
class AppPrinter {
  const AppPrinter({
    this.name,
    this.address,
    this.macAddress,
    required this.connectionType,
    this.isConnected = false,
    this.vendorData, // Menyimpan serialized object dari package native
  });

  final String? name;
  final String? address;
  final String? macAddress;
  final AppPrinterConnectionType connectionType;
  final bool isConnected;
  final Map<String, dynamic>? vendorData;

  AppPrinter copyWith({
    String? name,
    String? address,
    String? macAddress,
    AppPrinterConnectionType? connectionType,
    bool? isConnected,
    Map<String, dynamic>? vendorData,
  }) {
    return AppPrinter(
      name: name ?? this.name,
      address: address ?? this.address,
      macAddress: macAddress ?? this.macAddress,
      connectionType: connectionType ?? this.connectionType,
      isConnected: isConnected ?? this.isConnected,
      vendorData: vendorData ?? this.vendorData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'macAddress': macAddress,
      'connectionType': connectionType.name,
      'isConnected': isConnected,
      'vendorData': vendorData,
    };
  }

  factory AppPrinter.fromJson(Map<String, dynamic> json) {
    return AppPrinter(
      name: json['name'] as String?,
      address: json['address'] as String?,
      macAddress: json['macAddress'] as String?,
      connectionType: AppPrinterConnectionType.values.firstWhere(
        (e) => e.name == json['connectionType'],
        orElse: () => AppPrinterConnectionType.unknown,
      ),
      isConnected: (json['isConnected'] as bool?) ?? false,
      vendorData: json['vendorData'] as Map<String, dynamic>?,
    );
  }
}
