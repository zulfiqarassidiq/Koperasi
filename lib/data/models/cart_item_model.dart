import 'produk_model.dart';

class CartItemModel {
  const CartItemModel({
    required this.product,
    required this.qty,
  });

  final ProdukModel product;
  final int qty;

  num get unitPrice => product.hargaJual;
  num get subtotal => unitPrice * qty;

  CartItemModel copyWith({
    ProdukModel? product,
    int? qty,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      qty: qty ?? this.qty,
    );
  }
}
