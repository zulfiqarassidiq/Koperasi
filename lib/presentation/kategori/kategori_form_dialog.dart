import 'package:flutter/material.dart';

import '../../data/models/kategori_produk_model.dart';

class KategoriFormDialog extends StatefulWidget {
  const KategoriFormDialog({super.key, this.initialValue});

  final KategoriProdukModel? initialValue;

  @override
  State<KategoriFormDialog> createState() => _KategoriFormDialogState();
}

class _KategoriFormDialogState extends State<KategoriFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaKategoriController;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    _namaKategoriController = TextEditingController(
      text: widget.initialValue?.namaKategori ?? '',
    );
  }

  @override
  void dispose() {
    _namaKategoriController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_namaKategoriController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Kategori' : 'Tambah Kategori'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _namaKategoriController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            final cleanName = value?.trim() ?? '';

            if (cleanName.isEmpty) {
              return 'Nama kategori wajib diisi.';
            }

            if (cleanName.length > 80) {
              return 'Nama kategori maksimal 80 karakter.';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(_isEditing ? Icons.save_outlined : Icons.add),
          label: Text(_isEditing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}
