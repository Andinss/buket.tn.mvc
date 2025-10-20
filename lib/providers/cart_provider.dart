import 'package:flutter/material.dart';

import '../models/bouquet.dart';
import '../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  void addItem(Bouquet bouquet, [int quantity = 1]) {
    final existingIndex = _items.indexWhere((item) => item.bouquet.id == bouquet.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(bouquet: bouquet, quantity: quantity));
    }
    notifyListeners();
  }

  void removeItem(String bouquetId) {
    _items.removeWhere((item) => item.bouquet.id == bouquetId);
    notifyListeners();
  }

  void updateQuantity(String bouquetId, int newQuantity) {
    if (newQuantity < 1) {
      removeItem(bouquetId);
      return;
    }
    final index = _items.indexWhere((item) => item.bouquet.id == bouquetId);
    if (index >= 0) {
      _items[index].quantity = newQuantity;
      notifyListeners();
    }
  }

  int getTotalItems() => _items.fold(0, (sum, item) => sum + item.quantity);
  
  int getTotalPrice() => _items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  void clear() {
    _items.clear();
    notifyListeners();
  }

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
}