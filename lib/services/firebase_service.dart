import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

import '../models/bouquet.dart';
import '../models/cart_item.dart';
import '../models/order.dart';

class FirebaseService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Email sign in error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmail(String email, String password, String name) async {
    try {
      final userCred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      await userCred.user?.updateDisplayName(name);
      final uid = userCred.user!.uid;
      
      String role = 'buyer';
      if (email.toLowerCase() == 'andinn1404@gmail.com') {
        role = 'seller';
      }
      
      await db.collection('users').doc(uid).set({
        'displayName': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return userCred;
    } catch (e) {
      debugPrint('Email registration error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await auth.signInWithCredential(credential);
      final uid = userCred.user!.uid;
      final doc = db.collection('users').doc(uid);
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        String role = 'buyer';
        final email = userCred.user!.email ?? '';
        if (email.toLowerCase() == 'andinn1404@gmail.com') {
          role = 'seller';
        }
        
        await doc.set({
          'displayName': userCred.user!.displayName ?? '',
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return userCred;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await auth.signOut();
  }

  Future<void> setUserRole(String uid, String role) async {
    await db.collection('users').doc(uid).set({'role': role}, SetOptions(merge: true));
  }

  Future<String?> getUserRole(String uid) async {
    final snap = await db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return (snap.data()!['role'] ?? '') as String;
  }

  /// 🔹 Proses penyimpanan order ke Firestore
  Future<void> placeOrder(
    String uid,
    List<CartItem> items,
    double total,
    String? paymentMethod,
  ) async {
    try {
      final docRef = db.collection('orders').doc();

      final orderData = {
        'buyerId': uid,
        'items': items.map((c) => {
          'bouquetId': c.bouquet.id,
          'name': c.bouquet.name,
          'price': c.price,
          'qty': c.quantity,
        }).toList(),
        'total': total,
        'paymentMethod': paymentMethod ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'placed',
      };

      await docRef.set(orderData);
      debugPrint('✅ Order berhasil dibuat (ID: ${docRef.id})');
    } catch (e) {
      debugPrint('❌ Error placing order: $e');
      rethrow;
    }
  }

  Stream<List<Order>> getUserOrders(String uid) {
    return db
        .collection('orders')
        .where('buyerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Order.fromDoc(doc)).toList())
        .handleError((error) {
      debugPrint('Error in getUserOrders: $error');
      return <Order>[];
    });
  }

  Future<void> toggleFavorite(String uid, String bouquetId) async {
    final favRef = db.collection('users').doc(uid).collection('favorites').doc(bouquetId);
    final snap = await favRef.get();
    if (snap.exists) {
      await favRef.delete();
    } else {
      await favRef.set({'addedAt': FieldValue.serverTimestamp()});
    }
  }

  Stream<List<String>> getFavorites(String uid) {
    return db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }

  Future<void> addBouquet(Bouquet bouquet) async {
    final col = db.collection('bouquets');
    final data = bouquet.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    await col.add(data);
  }

  Future<void> updateBouquet(String id, Bouquet bouquet) async {
    final docRef = db.collection('bouquets').doc(id);
    final data = bouquet.toMap();
    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> deleteBouquet(String id) async {
    await db.collection('bouquets').doc(id).delete();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await db.collection('orders').doc(orderId).set({'status': status}, SetOptions(merge: true));
  }

  /// 🔹 Tambahan: Seed bouquet awal jika koleksi kosong
  Future<void> seedBouquetsIfNeeded() async {
    final col = db.collection('bouquets');
    final snap = await col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final sample = [
      {
        'name': 'Rose Romance',
        'description': 'Buket mawar merah romantis',
        'price': 250000,
        'images': [
          'https://images.unsplash.com/photo-1561181286-d3fee7d55364?w=500&h=500&fit=crop',
        ],
        'category': 'Romantic',
        'details': 'Buket mawar merah premium dengan wrapping elegan. Cocok untuk hadiah ulang tahun, anniversary, atau momen spesial lainnya.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Tulip Garden',
        'description': 'Buket tulip warna-warni',
        'price': 200000,
        'images': [
          'https://images.unsplash.com/photo-1520763185298-1b434c919102?w=500&h=500&fit=crop',
        ],
        'category': 'Elegant',
        'details': 'Tulip premium dengan berbagai warna elegan. Simbol cinta sempurna dan keindahan abadi.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Sunflower Joy',
        'description': 'Buket bunga matahari ceria',
        'price': 180000,
        'images': [
          'https://images.unsplash.com/photo-1597848212624-e8b9a6e6d1e1?w=500&h=500&fit=crop',
        ],
        'category': 'Cheerful',
        'details': 'Bunga matahari segar yang membawa keceriaan. Perfect untuk hadiah ke teman atau keluarga.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Lily Elegance',
        'description': 'Buket lily putih elegan',
        'price': 220000,
        'images': [
          'https://images.unsplash.com/photo-1563241527-3004b7be0ffd?w=500&h=500&fit=crop',
        ],
        'category': 'Elegant',
        'details': 'Lily putih yang elegan dan anggun. Cocok untuk acara formal, wedding, atau ucapan duka cita.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Mixed Paradise',
        'description': 'Buket campuran warna-warni',
        'price': 280000,
        'images': [
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=500&h=500&fit=crop',
        ],
        'category': 'Popular',
        'details': 'Kombinasi berbagai bunga segar dengan warna-warni cerah. Hadiah yang sempurna untuk berbagai acara.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = db.batch();
    for (final p in sample) {
      final doc = col.doc();
      batch.set(doc, p);
    }
    await batch.commit();
  }
}
  