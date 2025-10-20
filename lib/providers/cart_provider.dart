import 'package:flutter/material.dart';

import '../models/bouquet.dart';
import '../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> items = [];

  void addItem(Bouquet bouquet, int quantity) {
    final existingIndex = items.indexWhere((item) => item.bouquet.id == bouquet.id);
    if (existingIndex >= 0) {
      items[existingIndex].quantity += quantity;
    } else {
      items.add(CartItem(bouquet: bouquet, quantity: quantity));
    }
    notifyListeners();
  }

  void removeItem(String bouquetId) {
    items.removeWhere((item) => item.bouquet.id == bouquetId);
    notifyListeners();
  }

  void updateQuantity(String bouquetId, int newQuantity) {
    if (newQuantity < 1) {
      removeItem(bouquetId);
      return;
    }
    final index = items.indexWhere((item) => item.bouquet.id == bouquetId);
    if (index >= 0) {
      items[index].quantity = newQuantity;
      notifyListeners();
    }
  }

  int getTotalItems() => items.fold(0, (sum, item) => sum + item.quantity);
  int getTotalPrice() => items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  void clear() {
    items.clear();
    notifyListeners();
  }
}