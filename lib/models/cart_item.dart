import 'bouquet.dart';

class CartItem {
  final Bouquet bouquet;
  int quantity;

  CartItem({
    required this.bouquet,
    this.quantity = 1,
  });

  int get price => bouquet.price;

  // 🔹 Getter tambahan untuk akses image pertama
  String get imageUrl => bouquet.images.isNotEmpty
      ? bouquet.images[0]
      : 'https://via.placeholder.com/60';

  // Tambahan: untuk simpan ke Firebase
  Map<String, dynamic> toMap() => {
        'bouquetId': bouquet.id,
        'quantity': quantity,
      };

  // Tambahan: untuk ambil dari Firebase
  factory CartItem.fromMap(Map<String, dynamic> map, Bouquet bouquet) {
    return CartItem(
      bouquet: bouquet,
      quantity: map['quantity'] ?? 1,
    );
  }
}
