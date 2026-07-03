import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/pengeluaran_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import '../../data/models/user_profile_model.dart';
import '../auth/auth_providers.dart';
import 'pengeluaran_form_dialog.dart';
import 'pengeluaran_providers.dart';

class PengeluaranPage extends ConsumerWidget {
  const PengeluaranPage({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const PengeluaranFormDialog(),
    );

    if (result == null) return;

    final keterangan = result['keterangan'] as String? ?? '';
    final jumlah = result['jumlah'] as num? ?? 0;

    if (keterangan.isEmpty || jumlah <= 0) return;

    final isSuccess = await ref
        .read(pengeluaranControllerProvider.notifier)
        .addExpense(keterangan: keterangan, jumlah: jumlah);

    if (context.mounted && isSuccess) {
      _showMessage(context, 'Pengeluaran berhasil ditambahkan.');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PengeluaranModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengeluaran'),
        content: Text(
          'Hapus pengeluaran "${item.keterangan}" sebesar Rp ${NumberFormat.decimalPattern(AppLocale.formattingLocale).format(item.jumlah)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final isSuccess =
        await ref.read(pengeluaranControllerProvider.notifier).delete(item.id);

    if (context.mounted && isSuccess) {
      _showMessage(context, 'Pengeluaran berhasil dihapus.');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengeluaranState = ref.watch(pengeluaranControllerProvider);
    final search = ref.watch(pengeluaranSearchProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final canDelete = profile?.role.canDeletePengeluaran ?? false;

    return AppScaffold(
      title: 'Pengeluaran',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () =>
              ref.read(pengeluaranControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Tambah Pengeluaran',
          onPressed: () => _showAddDialog(context, ref),
          icon: const Icon(Icons.add),
        ),
      ],
      child: Column(
        children: [
          _PengeluaranSearchField(initialValue: search),
          const SizedBox(height: 16),
          Expanded(
            child: pengeluaranState.when(
              loading: () =>
                  const LoadingState(message: 'Memuat pengeluaran...'),
              error: (error, stackTrace) => _PengeluaranErrorState(
                message: _errorMessage(error),
                onRetry: () =>
                    ref.read(pengeluaranControllerProvider.notifier).refresh(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    message: search.trim().isEmpty
                        ? 'Belum ada data pengeluaran.'
                        : 'Pengeluaran tidak ditemukan.',
                  );
                }

                return _PengeluaranList(
                  items: items,
                  canDelete: canDelete,
                  onDelete: (item) => _confirmDelete(context, ref, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat data pengeluaran. Silakan coba lagi.';
  }
}

class _PengeluaranSearchField extends ConsumerStatefulWidget {
  const _PengeluaranSearchField({required this.initialValue});

  final String initialValue;

  @override
  ConsumerState<_PengeluaranSearchField> createState() =>
      _PengeluaranSearchFieldState();
}

class _PengeluaranSearchFieldState
    extends ConsumerState<_PengeluaranSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _PengeluaranSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari keterangan pengeluaran',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Bersihkan pencarian',
                onPressed: () {
                  _controller.clear();
                  ref.read(pengeluaranSearchProvider.notifier).state = '';
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
      ),
      onChanged: (value) {
        ref.read(pengeluaranSearchProvider.notifier).state = value;
        setState(() {});
      },
    );
  }
}

class _PengeluaranList extends StatelessWidget {
  const _PengeluaranList({
    required this.items,
    required this.canDelete,
    required this.onDelete,
  });

  final List<PengeluaranModel> items;
  final bool canDelete;
  final void Function(PengeluaranModel) onDelete;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.payments_outlined),
            ),
            title: Text(
              item.keterangan,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(dateFormat.format(item.tanggal)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currency.format(item.jumlah),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                if (canDelete)
                  IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(item),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PengeluaranErrorState extends StatelessWidget {
  const _PengeluaranErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
