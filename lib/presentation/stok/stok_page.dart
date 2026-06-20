import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_locale.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/produk_model.dart';
import '../../data/models/stok_masuk_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import 'stok_providers.dart';

class StokPage extends ConsumerWidget {
  const StokPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockState = ref.watch(stokControllerProvider);
    final productsState = ref.watch(stokProductOptionsProvider);
    final search = ref.watch(stokSearchProvider);

    return AppScaffold(
      title: 'Stok Masuk',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.read(stokControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Tambah Stok',
          onPressed: () => context.go(AppRoutes.stokCreate),
          icon: const Icon(Icons.add),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          return Column(
            children: [
              _StokFilters(
                initialSearch: search,
                productsState: productsState,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: stockState.when(
                  loading: () =>
                      const LoadingState(message: 'Memuat riwayat stok...'),
                  error: (error, stackTrace) => _StokErrorState(
                    message: _errorMessage(error),
                    onRetry: () =>
                        ref.read(stokControllerProvider.notifier).refresh(),
                  ),
                  data: (stocks) {
                    if (stocks.isEmpty) {
                      return const EmptyState(
                        message: 'Riwayat stok tidak ditemukan.',
                      );
                    }

                    return _StokList(
                      stocks: stocks,
                      isWide: isWide,
                      onDetail: (stock) =>
                          context.go(AppRoutes.stokDetailPath(stock.id)),
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
    return 'Gagal memuat riwayat stok. Silakan coba lagi.';
  }
}

class _StokFilters extends ConsumerStatefulWidget {
  const _StokFilters({
    required this.initialSearch,
    required this.productsState,
  });

  final String initialSearch;
  final AsyncValue<List<ProdukModel>> productsState;

  @override
  ConsumerState<_StokFilters> createState() => _StokFiltersState();
}

class _StokFiltersState extends ConsumerState<_StokFilters> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch);
  }

  @override
  void didUpdateWidget(covariant _StokFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearch != _searchController.text) {
      _searchController.text = widget.initialSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = ref.read(stokDateFilterProvider) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      ref.read(stokDateFilterProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = ref.watch(stokProductFilterProvider);
    final selectedDate = ref.watch(stokDateFilterProvider);
    final dateFormat = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final filters = [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari produk atau keterangan',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Bersihkan pencarian',
                      onPressed: () {
                        _searchController.clear();
                        ref.read(stokSearchProvider.notifier).state = '';
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (value) {
              ref.read(stokSearchProvider.notifier).state = value;
              setState(() {});
            },
          ),
          widget.productsState.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Text('Gagal memuat produk.'),
            data: (products) => DropdownButtonFormField<String>(
              initialValue: selectedProduct,
              decoration: const InputDecoration(
                labelText: 'Filter Produk',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Semua Produk')),
                ...products.map(
                  (product) => DropdownMenuItem(
                    value: product.id,
                    child: Text(product.namaProduk),
                  ),
                ),
              ],
              onChanged: (value) {
                ref.read(stokProductFilterProvider.notifier).state = value;
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              selectedDate == null
                  ? 'Semua Tanggal'
                  : dateFormat.format(selectedDate),
            ),
          ),
          if (selectedDate != null || selectedProduct != null)
            TextButton.icon(
              onPressed: () {
                ref.read(stokDateFilterProvider.notifier).state = null;
                ref.read(stokProductFilterProvider.notifier).state = null;
              },
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset Filter'),
            ),
        ];

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final filter in filters) ...[
                filter,
                if (filter != filters.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: filters[0]),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: filters[1]),
            const SizedBox(width: 12),
            filters[2],
            if (filters.length > 3) ...[
              const SizedBox(width: 8),
              filters[3],
            ],
          ],
        );
      },
    );
  }
}

class _StokList extends StatelessWidget {
  const _StokList({
    required this.stocks,
    required this.isWide,
    required this.onDetail,
  });

  final List<StokMasukModel> stocks;
  final bool isWide;
  final ValueChanged<StokMasukModel> onDetail;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 132,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: stocks.length,
        itemBuilder: (context, index) => _StokCard(
          stock: stocks[index],
          onTap: () => onDetail(stocks[index]),
        ),
      );
    }

    return ListView.separated(
      itemCount: stocks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _StokCard(
        stock: stocks[index],
        onTap: () => onDetail(stocks[index]),
      ),
    );
  }
}

class _StokCard extends StatelessWidget {
  const _StokCard({required this.stock, required this.onTap});

  final StokMasukModel stock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', AppLocale.formattingLocale);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stock.namaProduk ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Chip(
                    label: Text('+${stock.qty}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(dateFormat.format(stock.tanggal)),
              const SizedBox(height: 8),
              Text(
                stock.keterangan?.isEmpty ?? true
                    ? 'Tanpa keterangan'
                    : stock.keterangan!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StokErrorState extends StatelessWidget {
  const _StokErrorState({required this.message, required this.onRetry});

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
