import 'bouquet.dart';

class CartItem {
  final Bouquet bouquet;
  int quantity;

  CartItem({
    required this.bouquet,
    this.quantity = 1,
  });

  int get price => bouquet.price;
}