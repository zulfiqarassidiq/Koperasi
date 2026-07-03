import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../domain/models/receipt_data.dart';
import '../../routes/app_routes.dart';
import '../../services/pdf_receipt_generator.dart';
import '../settings/thermal_printer_providers.dart';
import 'transaksi_providers.dart';

/// Dialog yang muncul setelah checkout berhasil.
///
/// Menawarkan aksi:
/// 1. **Lihat Struk**    — Preview PDF in-app via [Printing.layoutPdf]
/// 2. **Cetak PDF**      — Share / print / download via [Printing.sharePdf]
/// 3. **Cetak Thermal**  — Cetak langsung via [ThermalPrinterController]
///                         (hanya di Android & Windows; hidden di Web)
/// 4. **Tutup**          — Tutup dialog, receipt di-clear dari state
///
/// Dialog ini tidak bergantung langsung ke Supabase. Semua data sudah
/// tersedia di [receiptDataAfterCheckoutProvider].
class TransaksiSuksesDialog extends ConsumerStatefulWidget {
  const TransaksiSuksesDialog({super.key});

  @override
  ConsumerState<TransaksiSuksesDialog> createState() =>
      _TransaksiSuksesDialogState();
}

class _TransaksiSuksesDialogState
    extends ConsumerState<TransaksiSuksesDialog> {
  bool _isThermalPrinting = false;

  @override
  Widget build(BuildContext context) {
    final receiptData = ref.watch(receiptDataAfterCheckoutProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch printer state untuk update status tombol thermal real-time
    final printerState = ref.watch(thermalPrinterControllerProvider);
    final isConnected = !kIsWeb && printerState.isConnected;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Ikon Sukses ────────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 44,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 16),

              // ── Judul & Subtitle ───────────────────────────────────────────
              Text(
                'Transaksi Berhasil!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (receiptData != null) ...[
                const SizedBox(height: 6),
                Text(
                  receiptData.nomorTransaksi,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ── Tombol Aksi ────────────────────────────────────────────────
              _ActionButton(
                id: 'btn_lihat_struk',
                icon: Icons.receipt_long_outlined,
                label: 'Lihat Struk',
                onPressed: receiptData == null
                    ? null
                    : () => _onLihatStruk(context, ref, receiptData),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                id: 'btn_cetak_pdf',
                icon: Icons.picture_as_pdf_outlined,
                label: 'Cetak / Simpan PDF',
                onPressed: receiptData == null
                    ? null
                    : () => _onCetakPdf(context, ref, receiptData),
              ),
              const SizedBox(height: 10),

              // ── Cetak Thermal (Android & Windows saja) ────────────────────
              if (!kIsWeb) ...[
                _ThermalActionButton(
                  id: 'btn_cetak_thermal',
                  isConnected: isConnected,
                  isPrinting: _isThermalPrinting,
                  onPressed: receiptData == null
                      ? null
                      : () => _onCetakThermal(context, ref, receiptData),
                  onSetupTap: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.thermalPrinter);
                  },
                ),
                const SizedBox(height: 10),
              ],

              // ── Divider tipis ──────────────────────────────────────────────
              Divider(color: colorScheme.outlineVariant, height: 1),
              const SizedBox(height: 12),

              // ── Tutup ──────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _onTutup(context, ref),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _onLihatStruk(
    BuildContext context,
    WidgetRef ref,
    ReceiptData data,
  ) async {
    final generator = ref.read(pdfReceiptGeneratorProvider);
    try {
      await Printing.layoutPdf(
        name: '${data.nomorTransaksi}_struk',
        onLayout: (_) async => generator.generate(data),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka preview struk.')),
        );
      }
    }
  }

  Future<void> _onCetakPdf(
    BuildContext context,
    WidgetRef ref,
    ReceiptData data,
  ) async {
    final generator = ref.read(pdfReceiptGeneratorProvider);
    try {
      final bytes = await generator.generate(data);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${data.nomorTransaksi}_struk.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghasilkan PDF.')),
        );
      }
    }
  }

  Future<void> _onCetakThermal(
    BuildContext context,
    WidgetRef ref,
    ReceiptData data,
  ) async {
    // Jika printer belum connect, arahkan ke settings
    final printerState = ref.read(thermalPrinterControllerProvider);
    if (!printerState.isConnected) {
      if (context.mounted) {
        Navigator.of(context).pop();
        context.push(AppRoutes.thermalPrinter);
      }
      return;
    }

    setState(() => _isThermalPrinting = true);
    try {
      final success = await ref
          .read(thermalPrinterControllerProvider.notifier)
          .printReceipt(data);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Struk thermal berhasil dicetak!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal cetak thermal: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isThermalPrinting = false);
    }
  }

  void _onTutup(BuildContext context, WidgetRef ref) {
    // Clear receipt data dari state
    ref.read(receiptDataAfterCheckoutProvider.notifier).state = null;
    Navigator.of(context).pop();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Button
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.id,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        key: ValueKey(id),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thermal Action Button — smart: connected vs not connected state
// ─────────────────────────────────────────────────────────────────────────────
class _ThermalActionButton extends StatelessWidget {
  const _ThermalActionButton({
    required this.id,
    required this.isConnected,
    required this.isPrinting,
    this.onPressed,
    required this.onSetupTap,
  });

  final String id;
  final bool isConnected;
  final bool isPrinting;
  final VoidCallback? onPressed;
  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!isConnected) {
      // Printer belum connect — tampilkan sebagai outline dengan hint setup
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: ValueKey(id),
          onPressed: onSetupTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: colorScheme.outline),
          ),
          icon: const Icon(Icons.print_outlined),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cetak Thermal',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Setup',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Printer sudah connect — tombol aktif
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        key: ValueKey(id),
        onPressed: isPrinting ? null : onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.green.shade50,
          foregroundColor: Colors.green.shade800,
        ),
        icon: isPrinting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.print_rounded),
        label: Text(
          isPrinting ? 'Mencetak...' : 'Cetak Thermal',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
