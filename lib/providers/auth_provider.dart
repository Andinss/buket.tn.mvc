import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService service;
  User? user;
  String role = '';
  bool initializing = true;
  String phoneNumber = '';
  String address = '';
  String city = '';
  String postalCode = '';
  String paymentMethod = 'Credit Card';

  AuthProvider(this.service) {
    service.auth.authStateChanges().listen((u) async {
      user = u;
      if (user != null) {
        role = await service.getUserRole(user!.uid) ?? '';
        await _loadUserProfile(user!.uid);
      } else {
        role = '';
        phoneNumber = '';
        address = '';
        city = '';
        postalCode = '';
        paymentMethod = 'Credit Card';
      }
      initializing = false;
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final userDoc = await service.db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        phoneNumber = data['phoneNumber']?.toString() ?? '';
        address = data['address']?.toString() ?? '';
        city = data['city']?.toString() ?? '';
        postalCode = data['postalCode']?.toString() ?? '';
        paymentMethod = data['paymentMethod']?.toString() ?? 'Credit Card';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> updateProfile(String name, String phone, String address, String city, String postalCode, String paymentMethod) async {
    if (user == null) return;
    
    try {
      await user!.updateDisplayName(name);
      
      await service.db.collection('users').doc(user!.uid).set({
        'displayName': name,
        'phoneNumber': phone,
        'address': address,
        'city': city,
        'postalCode': postalCode,
        'paymentMethod': paymentMethod,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      this.phoneNumber = phone;
      this.address = address;
      this.city = city;
      this.postalCode = postalCode;
      this.paymentMethod = paymentMethod;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    await service.signInWithEmail(email, password);
  }

  Future<void> registerWithEmail(String email, String password, String name) async {
    await service.registerWithEmail(email, password, name);
  }

  Future<void> signInWithGoogle() async {
    await service.signInWithGoogle();
  }

  Future<void> resetPassword(String email) async {
    await service.resetPassword(email);
  }

  Future<void> signOut() async {
    await service.signOut();
  }

  Future<void> setRole(String r) async {
    if (user == null) return;
    await service.setUserRole(user!.uid, r);
    role = r;
    notifyListeners();
  }
}