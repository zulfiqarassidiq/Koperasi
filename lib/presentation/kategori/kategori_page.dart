import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/kategori_produk_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import 'delete_kategori_dialog.dart';
import 'kategori_form_dialog.dart';
import 'kategori_providers.dart';

class KategoriPage extends ConsumerWidget {
  const KategoriPage({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final namaKategori = await showDialog<String>(
      context: context,
      builder: (context) => const KategoriFormDialog(),
    );

    if (namaKategori == null) return;

    final isSuccess = await ref
        .read(kategoriControllerProvider.notifier)
        .create(namaKategori);

    if (context.mounted && isSuccess) {
      _showMessage(context, 'Kategori berhasil ditambahkan.');
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    KategoriProdukModel kategori,
  ) async {
    final namaKategori = await showDialog<String>(
      context: context,
      builder: (context) => KategoriFormDialog(initialValue: kategori),
    );

    if (namaKategori == null || namaKategori == kategori.namaKategori) return;

    final isSuccess =
        await ref.read(kategoriControllerProvider.notifier).updateCategory(
              id: kategori.id,
              namaKategori: namaKategori,
            );

    if (context.mounted && isSuccess) {
      _showMessage(context, 'Kategori berhasil diperbarui.');
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    KategoriProdukModel kategori,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteKategoriDialog(kategori: kategori),
    );

    if (confirmed != true) return;

    final isSuccess =
        await ref.read(kategoriControllerProvider.notifier).delete(kategori.id);

    if (context.mounted && isSuccess) {
      _showMessage(context, 'Kategori berhasil dihapus.');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriState = ref.watch(kategoriControllerProvider);
    final search = ref.watch(kategoriSearchProvider);

    return AppScaffold(
      title: 'Kategori Produk',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () =>
              ref.read(kategoriControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Tambah Kategori',
          onPressed: () => _showAddDialog(context, ref),
          icon: const Icon(Icons.add),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          return Column(
            children: [
              _KategoriSearchField(initialValue: search),
              const SizedBox(height: 16),
              Expanded(
                child: kategoriState.when(
                  loading: () =>
                      const LoadingState(message: 'Memuat kategori...'),
                  error: (error, stackTrace) => _KategoriErrorState(
                    message: _errorMessage(error),
                    onRetry: () =>
                        ref.read(kategoriControllerProvider.notifier).refresh(),
                  ),
                  data: (kategoriList) {
                    if (kategoriList.isEmpty) {
                      return EmptyState(
                        message: search.trim().isEmpty
                            ? 'Belum ada kategori produk.'
                            : 'Kategori tidak ditemukan.',
                      );
                    }

                    return _KategoriList(
                      kategoriList: kategoriList,
                      isWide: isWide,
                      onEdit: (kategori) =>
                          _showEditDialog(context, ref, kategori),
                      onDelete: (kategori) =>
                          _showDeleteDialog(context, ref, kategori),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat kategori. Silakan coba lagi.';
  }
}

class _KategoriSearchField extends ConsumerStatefulWidget {
  const _KategoriSearchField({required this.initialValue});

  final String initialValue;

  @override
  ConsumerState<_KategoriSearchField> createState() =>
      _KategoriSearchFieldState();
}

class _KategoriSearchFieldState extends ConsumerState<_KategoriSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _KategoriSearchField oldWidget) {
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
        hintText: 'Cari kategori',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Bersihkan pencarian',
                onPressed: () {
                  _controller.clear();
                  ref.read(kategoriSearchProvider.notifier).state = '';
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
      ),
      onChanged: (value) {
        ref.read(kategoriSearchProvider.notifier).state = value;
        setState(() {});
      },
    );
  }
}

class _KategoriList extends StatelessWidget {
  const _KategoriList({
    required this.kategoriList,
    required this.isWide,
    required this.onEdit,
    required this.onDelete,
  });

  final List<KategoriProdukModel> kategoriList;
  final bool isWide;
  final ValueChanged<KategoriProdukModel> onEdit;
  final ValueChanged<KategoriProdukModel> onDelete;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          mainAxisExtent: 96,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: kategoriList.length,
        itemBuilder: (context, index) => _KategoriTile(
          kategori: kategoriList[index],
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      );
    }

    return ListView.separated(
      itemCount: kategoriList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _KategoriTile(
        kategori: kategoriList[index],
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

class _KategoriTile extends StatelessWidget {
  const _KategoriTile({
    required this.kategori,
    required this.onEdit,
    required this.onDelete,
  });

  final KategoriProdukModel kategori;
  final ValueChanged<KategoriProdukModel> onEdit;
  final ValueChanged<KategoriProdukModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.category_outlined)),
        title: Text(
          kategori.namaKategori,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('ID: ${kategori.id}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: () => onEdit(kategori),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Hapus',
              onPressed: () => onDelete(kategori),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _KategoriErrorState extends StatelessWidget {
  const _KategoriErrorState({required this.message, required this.onRetry});

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
