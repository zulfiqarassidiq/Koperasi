import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_printer.dart';
import '../../widgets/app_scaffold.dart';
import 'thermal_printer_providers.dart';

/// Halaman pengaturan dan manajemen AppPrinter Thermal.
///
/// Fitur:
/// - Status koneksi printer saat ini
/// - Scan & list printer yang terdeteksi (BT, USB, Network)
/// - Pilih ukuran kertas saat pertama connect
/// - Test Print
/// - Putus Koneksi
/// - Auto-reconnect berjalan otomatis di background
class ThermalPrinterPage extends ConsumerStatefulWidget {
  const ThermalPrinterPage({super.key});

  @override
  ConsumerState<ThermalPrinterPage> createState() =>
      _ThermalPrinterPageState();
}

class _ThermalPrinterPageState extends ConsumerState<ThermalPrinterPage> {
  @override
  void initState() {
    super.initState();
    // Listen message setelah build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<ThermalPrinterState>(
        thermalPrinterControllerProvider,
        (prev, next) => _handleMessages(next),
      );
    });
  }

  void _handleMessages(ThermalPrinterState state) {
    if (!mounted) return;
    if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ref.read(thermalPrinterControllerProvider.notifier).clearMessages();
            },
          ),
        ),
      );
      ref.read(thermalPrinterControllerProvider.notifier).clearMessages();
    }
    if (state.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.successMessage!),
          backgroundColor: Colors.green.shade700,
        ),
      );
      ref.read(thermalPrinterControllerProvider.notifier).clearMessages();
    }
  }

  Future<void> _onConnectTap(AppPrinter printer) async {
    // Tanya paper width terlebih dahulu
    final paperWidth = await _showPaperWidthDialog();
    if (paperWidth == null || !mounted) return;

    await ref
        .read(thermalPrinterControllerProvider.notifier)
        .connect(printer, paperWidth);
  }

  Future<int?> _showPaperWidthDialog() {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ukuran Kertas AppPrinter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pilih ukuran kertas sesuai printer Anda:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            _PaperWidthOption(
              label: '58mm',
              subtitle: 'XAppPrinter 58mm, mini printer portable',
              onTap: () => Navigator.pop(ctx, 58),
            ),
            const SizedBox(height: 8),
            _PaperWidthOption(
              label: '80mm',
              subtitle: 'XAppPrinter 80mm, Epson TM Series, printer kasir standar',
              onTap: () => Navigator.pop(ctx, 80),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(thermalPrinterControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'AppPrinter Thermal',
      showBackButton: true,
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(thermalPrinterControllerProvider.notifier).startScan(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Auto-reconnect banner ────────────────────────────────────────
            if (state.isAutoReconnecting)
              _InfoBanner(
                icon: Icons.sync_rounded,
                message: 'Menghubungkan ke printer terakhir...',
                color: colorScheme.primaryContainer,
                textColor: colorScheme.onPrimaryContainer,
              ),

            // ── Status Koneksi ───────────────────────────────────────────────
            _SectionTitle(title: 'Status AppPrinter'),
            _StatusCard(
              connectedAppPrinter: state.connectedPrinter,
              connectedPaperWidth: state.connectedPaperWidth,
              isPrinting: state.isPrinting,
              onTestPrint: () =>
                  ref.read(thermalPrinterControllerProvider.notifier).testPrint(),
              onDisconnect: () =>
                  ref.read(thermalPrinterControllerProvider.notifier).disconnect(),
            ),
            const SizedBox(height: 24),

            // ── Scan ─────────────────────────────────────────────────────────
            _SectionTitle(title: 'Daftar AppPrinter'),
            _ScanHeader(
              isScanning: state.isScanning,
              onScan: () =>
                  ref.read(thermalPrinterControllerProvider.notifier).startScan(),
              onStop: () =>
                  ref.read(thermalPrinterControllerProvider.notifier).stopScan(),
            ),
            const SizedBox(height: 8),

            // ── AppPrinter List ─────────────────────────────────────────────────
            if (state.isScanning && state.discoveredPrinters.isEmpty)
              const _ScanningIndicator()
            else if (!state.isScanning && state.discoveredPrinters.isEmpty)
              _EmptyAppPrinterState()
            else
              ...state.discoveredPrinters.map(
                (printer) => _AppPrinterTile(
                  printer: printer,
                  isConnected:
                      state.connectedPrinter?.address == printer.address,
                  isConnecting: state.isConnecting,
                  onConnect: () => _onConnectTap(printer),
                ),
              ),

            const SizedBox(height: 24),

            // ── Panduan ──────────────────────────────────────────────────────
            _GuidanceCard(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.connectedAppPrinter,
    required this.connectedPaperWidth,
    required this.isPrinting,
    required this.onTestPrint,
    required this.onDisconnect,
  });

  final AppPrinter? connectedAppPrinter;
  final int? connectedPaperWidth;
  final bool isPrinting;
  final VoidCallback onTestPrint;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = connectedAppPrinter != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.shade50
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: isConnected
                        ? Colors.green.shade600
                        : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected
                                  ? Colors.green.shade500
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isConnected ? 'Terhubung' : 'Belum Terhubung',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isConnected
                                  ? Colors.green.shade700
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (isConnected) ...[
                        const SizedBox(height: 2),
                        Text(
                          connectedAppPrinter!.name ??
                              connectedAppPrinter!.address ??
                              'Unknown',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${_connectionLabel(connectedAppPrinter!.connectionType)} • ${connectedPaperWidth ?? 58}mm',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                      ] else
                        Text(
                          'Scan printer di bawah untuk terhubung',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (isConnected) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('btn_test_print'),
                      onPressed: isPrinting ? null : onTestPrint,
                      icon: isPrinting
                          ? const SizedBox.square(
                              dimension: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.receipt_outlined, size: 18),
                      label: Text(isPrinting ? 'Mencetak...' : 'Tes Cetak'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('btn_disconnect'),
                      onPressed: isPrinting ? null : onDisconnect,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                      ),
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      label: const Text('Putus'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _connectionLabel(AppPrinterConnectionType? type) {
    switch (type) {
      case AppPrinterConnectionType.ble:
      case AppPrinterConnectionType.bluetooth:
        return 'Bluetooth';
      case AppPrinterConnectionType.usb:
        return 'USB';
      case AppPrinterConnectionType.network:
        return 'Network';
      default:
        return '-';
    }
  }
}

class _ScanHeader extends StatelessWidget {
  const _ScanHeader({
    required this.isScanning,
    required this.onScan,
    required this.onStop,
  });

  final bool isScanning;
  final VoidCallback onScan;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isScanning)
          TextButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Stop'),
          )
        else
          FilledButton.icon(
            key: const ValueKey('btn_scan_printer'),
            onPressed: onScan,
            icon: const Icon(Icons.radar_rounded, size: 18),
            label: const Text('Scan AppPrinter'),
          ),
      ],
    );
  }
}

class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Mencari printer...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppPrinterState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.print_disabled_outlined,
            size: 48,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada printer terdeteksi',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Scan AppPrinter" untuk mencari printer',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppPrinterTile extends StatelessWidget {
  const _AppPrinterTile({
    required this.printer,
    required this.isConnected,
    required this.isConnecting,
    required this.onConnect,
  });

  final AppPrinter printer;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = printer.name ?? printer.address ?? 'Unknown AppPrinter';
    final connLabel = _connectionLabel(printer.connectionType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isConnected
                ? Colors.green.shade50
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _connectionIcon(printer.connectionType),
            color: isConnected
                ? Colors.green.shade600
                : colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$connLabel${printer.address != null ? ' • ${printer.address}' : ''}',
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isConnected
            ? Chip(
                label: const Text('Terhubung', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.green.shade100,
                labelStyle: TextStyle(color: Colors.green.shade800),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
              )
            : FilledButton.tonal(
                key: ValueKey('btn_connect_${printer.address}'),
                onPressed: isConnecting ? null : onConnect,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: isConnecting
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Hubungkan', style: TextStyle(fontSize: 12)),
              ),
      ),
    );
  }

  String _connectionLabel(AppPrinterConnectionType? type) {
    switch (type) {
      case AppPrinterConnectionType.ble:
      case AppPrinterConnectionType.bluetooth:
        return 'Bluetooth';
      case AppPrinterConnectionType.usb:
        return 'USB';
      case AppPrinterConnectionType.network:
        return 'Network';
      default:
        return 'Unknown';
    }
  }

  IconData _connectionIcon(AppPrinterConnectionType? type) {
    switch (type) {
      case AppPrinterConnectionType.ble:
      case AppPrinterConnectionType.bluetooth:
        return Icons.bluetooth_rounded;
      case AppPrinterConnectionType.usb:
        return Icons.usb_rounded;
      case AppPrinterConnectionType.network:
        return Icons.wifi_rounded;
      default:
        return Icons.print_rounded;
    }
  }
}

class _PaperWidthOption extends StatelessWidget {
  const _PaperWidthOption({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Panduan Setup Printer',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _GuidanceItem(
              platform: 'Android (Bluetooth)',
              steps: [
                'Nyalakan printer thermal',
                'Buka Pengaturan HP → Bluetooth → Pair printer',
                'Kembali ke app → Scan Printer → Pilih printer → Hubungkan',
              ],
            ),
            const SizedBox(height: 10),
            const _GuidanceItem(
              platform: 'Windows (USB)',
              steps: [
                'Install driver XPrinter dari xprintertech.com',
                'Sambungkan printer via USB → Windows akan detect otomatis',
                'Buka app → Scan Printer → Pilih printer → Hubungkan',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceItem extends StatelessWidget {
  const _GuidanceItem({required this.platform, required this.steps});

  final String platform;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          platform,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        ...steps.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text(
              '${e.key + 1}. ${e.value}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
