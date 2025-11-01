import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bouquet.dart';
import '../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> items = [];
  String? currentUserId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// =============================
  /// 🔹 Set User dan Load dari Firebase
  /// =============================
  void setUser(String? userId) {
    currentUserId = userId;
    if (userId != null) {
      _loadCartFromFirebase(userId);
    } else {
      items.clear();
      notifyListeners();
    }
  }

  Future<void> _loadCartFromFirebase(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('cart')
          .get();

      items.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Get bouquet data
        final bouquetDoc = await _db
            .collection('bouquets')
            .doc(data['bouquetId'])
            .get();

        if (bouquetDoc.exists) {
          final bouquet = Bouquet.fromDoc(bouquetDoc);
          items.add(CartItem(
            bouquet: bouquet,
            quantity: data['quantity'] ?? 1,
          ));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  /// =============================
  /// 🔹 Tambah Item ke Keranjang
  /// =============================
  Future<void> addItem(Bouquet bouquet, int quantity,
      {BuildContext? context}) async {
    final existingIndex =
        items.indexWhere((item) => item.bouquet.id == bouquet.id);

    if (existingIndex >= 0) {
      items[existingIndex].quantity += quantity;
    } else {
      items.add(CartItem(bouquet: bouquet, quantity: quantity));
    }

    notifyListeners();

    // Simpan ke Firebase
    if (currentUserId != null) {
      await _saveToFirebase(
        bouquet.id,
        existingIndex >= 0 ? items[existingIndex].quantity : quantity,
      );
    }

    // 🔔 Notif tambahan
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Added to cart!"),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/cart');
                },
                child: const Text(
                  "Lihat",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// =============================
  /// 🔹 Wrapper Kompatibilitas (agar addToCart() tetap bisa dipakai)
  /// =============================
  Future<void> addToCart(Bouquet bouquet, int quantity, {BuildContext? context}) async {
    await addItem(bouquet, quantity, context: context);
  }

  /// =============================
  /// 🔹 Hapus Item dari Keranjang
  /// =============================
  Future<void> removeItem(String bouquetId) async {
    items.removeWhere((item) => item.bouquet.id == bouquetId);
    notifyListeners();

    if (currentUserId != null) {
      await _db
          .collection('users')
          .doc(currentUserId)
          .collection('cart')
          .doc(bouquetId)
          .delete();
    }
  }

  /// =============================
  /// 🔹 Update Jumlah Item
  /// =============================
  void increaseQuantity(String bouquetId) {
    final index = items.indexWhere((item) => item.bouquet.id == bouquetId);
    if (index >= 0) {
      items[index].quantity++;
      notifyListeners();
      if (currentUserId != null) {
        _saveToFirebase(bouquetId, items[index].quantity);
      }
    }
  }

  void decreaseQuantity(String bouquetId) {
    final index = items.indexWhere((item) => item.bouquet.id == bouquetId);
    if (index >= 0) {
      if (items[index].quantity > 1) {
        items[index].quantity--;
        notifyListeners();
        if (currentUserId != null) {
          _saveToFirebase(bouquetId, items[index].quantity);
        }
      } else {
        removeItem(bouquetId);
      }
    }
  }

  /// =============================
  /// 🔹 Simpan Data ke Firebase
  /// =============================
  Future<void> _saveToFirebase(String bouquetId, int quantity) async {
    if (currentUserId == null) return;

    try {
      await _db
          .collection('users')
          .doc(currentUserId)
          .collection('cart')
          .doc(bouquetId)
          .set({
        'bouquetId': bouquetId,
        'quantity': quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving cart to Firebase: $e');
    }
  }

  /// =============================
  /// 🔹 Total Item & Harga
  /// =============================
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  int get totalAmount => items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  /// 🔹 Tambahan agar DetailPage tidak error
  int getTotalItems() => totalItems; // <-- ini method tambahan
  int getTotalItem() => totalItems;  // <-- alias supaya kompatibel kode lama

  /// =============================
  /// 🔹 Bersihkan Keranjang
  /// =============================
  Future<void> clear() async {
    items.clear();
    notifyListeners();

    if (currentUserId != null) {
      final batch = _db.batch();
      final cartDocs = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('cart')
          .get();

      for (var doc in cartDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }
}
