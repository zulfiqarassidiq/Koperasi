import 'package:flutter/material.dart';

import '../../data/models/produk_model.dart';

class DeleteProdukDialog extends StatelessWidget {
  const DeleteProdukDialog({super.key, required this.product});

  final ProdukModel product;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hapus Produk'),
      content: Text(
        'Hapus produk "${product.namaProduk}"? Tindakan ini tidak dapat dibatalkan.',
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
