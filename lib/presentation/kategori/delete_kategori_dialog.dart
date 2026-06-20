import 'package:flutter/material.dart';

import '../../data/models/kategori_produk_model.dart';

class DeleteKategoriDialog extends StatelessWidget {
  const DeleteKategoriDialog({super.key, required this.kategori});

  final KategoriProdukModel kategori;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hapus Kategori'),
      content: Text(
        'Hapus kategori "${kategori.namaKategori}"? Tindakan ini tidak dapat dibatalkan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Hapus'),
        ),
      ],
    );
  }
}
