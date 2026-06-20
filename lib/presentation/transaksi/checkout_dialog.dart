import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import 'transaksi_providers.dart';

class CheckoutDialog extends ConsumerWidget {
  const CheckoutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return AlertDialog(
      title: const Text('Checkout'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: cart.paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Metode Pembayaran',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: paymentMethods
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    ),
                  )
                  .toList(),
              onChanged: cart.isCheckingOut
                  ? null
                  : (value) {
                      if (value == null) return;
                      ref
                          .read(cartControllerProvider.notifier)
                          .setPaymentMethod(value);
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Total Item')),
                Text('${cart.totalQty}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Grand Total')),
                Text(
                  currency.format(cart.grandTotal),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              cart.isCheckingOut ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: cart.isCheckingOut
              ? null
              : () async {
                  final isSuccess = await ref
                      .read(cartControllerProvider.notifier)
                      .checkout();
                  if (context.mounted && isSuccess) {
                    Navigator.of(context).pop();
                  }
                },
          icon: cart.isCheckingOut
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('Bayar'),
        ),
      ],
    );
  }
}
