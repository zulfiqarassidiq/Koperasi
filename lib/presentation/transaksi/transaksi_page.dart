import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/produk_model.dart';
import '../../data/models/cart_item_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import 'cart_widget.dart';
import 'transaksi_providers.dart';

class TransaksiPage extends ConsumerWidget {
  const TransaksiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<CartState>(cartControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);

      if (next.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(cartControllerProvider.notifier).clearMessages();
      }

      if (next.successMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(next.successMessage!)));
        ref.read(cartControllerProvider.notifier).clearMessages();
      }
    });

    final productsState = ref.watch(transaksiProductResultsProvider);
    final search = ref.watch(transaksiProductSearchProvider);

    final isWide = MediaQuery.of(context).size.width >= 900;
    final productsPanel = _ProductPanel(
      productsState: productsState,
      search: search,
    );

    return AppScaffold(
      title: 'Point of Sale',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Riwayat Transaksi',
          onPressed: () => context.go(AppRoutes.transaksiHistory),
          icon: const Icon(Icons.history_rounded),
        ),
        IconButton(
          tooltip: 'Refresh Produk',
          onPressed: () => ref.invalidate(transaksiProductResultsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      bottomNavigationBar: isWide ? null : const _MobileCartSummary(),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: productsPanel),
                const SizedBox(width: 24),
                const Expanded(flex: 2, child: CartWidget()),
              ],
            )
          : productsPanel,
    );
  }
}

class _MobileCartSummary extends ConsumerWidget {
  const _MobileCartSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp',
      decimalDigits: 0,
    );

    if (cart.items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total (${cart.totalQty} Item)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    currency.format(cart.grandTotal),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      top: 16,
                      left: 16,
                      right: 16,
                    ),
                    child: const CartWidget(),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_bag_rounded),
              label: const Text('Checkout'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPanel extends StatelessWidget {
  const _ProductPanel({
    required this.productsState,
    required this.search,
  });

  final AsyncValue<List<ProdukModel>> productsState;
  final String search;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProductSearchField(initialValue: search)
            .animate()
            .fadeIn()
            .slideY(begin: -0.1),
        const SizedBox(height: 24),
        Expanded(
          child: productsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _TransactionErrorState(
              message: _errorMessage(error),
            ),
            data: (products) {
              if (products.isEmpty) {
                return EmptyState(
                  message: search.trim().isEmpty
                      ? 'Belum ada produk tersedia.'
                      : 'Produk tidak ditemukan.',
                );
              }

              return _ProductList(products: products);
            },
          ),
        ),
      ],
    );
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Gagal memuat produk. Silakan coba lagi.';
  }
}

class _ProductSearchField extends ConsumerStatefulWidget {
  const _ProductSearchField({required this.initialValue});

  final String initialValue;

  @override
  ConsumerState<_ProductSearchField> createState() =>
      _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<_ProductSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _ProductSearchField oldWidget) {
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
        hintText: 'Cari nama produk atau scan barcode...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Bersihkan pencarian',
                onPressed: () {
                  _controller.clear();
                  ref.read(transaksiProductSearchProvider.notifier).state = '';
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      onChanged: (value) {
        ref.read(transaksiProductSearchProvider.notifier).state = value;
        setState(() {});
      },
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList({required this.products});

  final List<ProdukModel> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isWide ? 280 : 200,
            mainAxisExtent: 180,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final cart = ref.watch(cartControllerProvider);
            final cartItem = cart.items.cast<CartItemModel?>().firstWhere(
                  (item) => item?.product.id == product.id,
                  orElse: () => null,
                );

            return _ProductCard(
              product: product,
              quantityInCart: cartItem?.qty ?? 0,
              onTap: () => ref
                  .read(cartControllerProvider.notifier)
                  .addProduct(product),
            ).animate(delay: (index * 30).ms).fadeIn().scale(begin: const Offset(0.95, 0.95));
          },
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    this.quantityInCart = 0,
  });

  final ProdukModel product;
  final VoidCallback onTap;
  final int quantityInCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(
      locale: AppLocale.formattingLocale,
      symbol: 'Rp',
      decimalDigits: 0,
    );

    final isOutOfStock = product.stok <= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: quantityInCart > 0
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : const Color(0xFFF1F5F9),
          width: quantityInCart > 0 ? 2 : 1.5,
        ),
        boxShadow: [
          if (quantityInCart > 0)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isOutOfStock ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.namaProduk,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (quantityInCart > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$quantityInCart',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ).animate().scale(),
                  ],
                ),
                const Spacer(),
                Text(
                  currency.format(product.hargaJual),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? theme.colorScheme.error.withValues(alpha: 0.1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOutOfStock ? 'Habis' : 'Stok: ${product.stok}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOutOfStock
                              ? theme.colorScheme.error
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.add_circle_rounded,
                      color: isOutOfStock
                          ? Colors.grey.shade300
                          : theme.colorScheme.primary,
                      size: 28,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionErrorState extends ConsumerWidget {
  const _TransactionErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(transaksiProductResultsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

