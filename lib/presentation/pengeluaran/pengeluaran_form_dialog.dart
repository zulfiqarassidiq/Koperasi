import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PengeluaranFormDialog extends StatefulWidget {
  const PengeluaranFormDialog({super.key});

  @override
  State<PengeluaranFormDialog> createState() => _PengeluaranFormDialogState();
}

class _PengeluaranFormDialogState extends State<PengeluaranFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _keteranganController = TextEditingController();
  final _jumlahController = TextEditingController();

  @override
  void dispose() {
    _keteranganController.dispose();
    _jumlahController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final keterangan = _keteranganController.text.trim();
    final jumlahText =
        _jumlahController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final jumlah = num.tryParse(jumlahText) ?? 0;

    Navigator.of(context).pop({
      'keterangan': keterangan,
      'jumlah': jumlah,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Pengeluaran'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _keteranganController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                prefixIcon: Icon(Icons.description_outlined),
                hintText: 'Contoh: Pembelian ATK',
              ),
              validator: (value) {
                final clean = value?.trim() ?? '';
                if (clean.isEmpty) return 'Keterangan wajib diisi.';
                if (clean.length > 200) return 'Maksimal 200 karakter.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _jumlahController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Jumlah (Rp)',
                prefixIcon: Icon(Icons.payments_outlined),
                hintText: 'Contoh: 150000',
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                final clean =
                    value?.trim().replaceAll('.', '').replaceAll(',', '.') ??
                        '';
                final numValue = num.tryParse(clean) ?? 0;
                if (numValue <= 0) return 'Jumlah harus lebih dari 0.';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),
        ),
      ],
    );
  }
}
