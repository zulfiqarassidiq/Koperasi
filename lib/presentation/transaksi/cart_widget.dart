import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../data/models/cart_item_model.dart';
import '../../widgets/empty_state.dart';
import 'checkout_dialog.dart';
import 'transaksi_providers.dart';

class CartWidget extends ConsumerWidget {
  const CartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_bag_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keranjang',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${cart.totalQty} Item',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: cart.items.isEmpty
                ? const EmptyState(message: 'Wah, keranjangmu masih kosong nih!')
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _CartItemTile(item: cart.items[index])
                            .animate()
                            .fadeIn()
                            .slideX(begin: 0.1),
                  ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          _CartTotal(cart: cart),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: cart.items.isEmpty || cart.isCheckingOut
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (context) => const CheckoutDialog(),
                      ),
              icon: cart.isCheckingOut
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: const Text(
                'Lanjutkan Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ).animate(target: cart.items.isEmpty ? 0 : 1).scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1, 1),
                ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp',
      decimalDigits: 0,
    );
    final controller = ref.read(cartControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.namaProduk,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(item.unitPrice),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => controller.remove(item.product.id),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE11D48),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currency.format(item.subtotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => controller.decrease(item.product.id),
                      icon: const Icon(Icons.remove_rounded, size: 16),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${item.qty}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: item.qty >= item.product.stok
                          ? null
                          : () => controller.increase(item.product.id),
                      icon: const Icon(Icons.add_rounded, size: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartTotal extends StatelessWidget {
  const _CartTotal({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Bayar',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            currency.format(cart.grandTotal),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

