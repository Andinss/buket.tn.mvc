import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_service.dart';
import '../utils/constants.dart';

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
      final userData = await service.getUserData(uid);
      if (userData != null) {
        phoneNumber = userData['phoneNumber']?.toString() ?? '';
        address = userData['address']?.toString() ?? '';
        city = userData['city']?.toString() ?? '';
        postalCode = userData['postalCode']?.toString() ?? '';
        paymentMethod = userData['paymentMethod']?.toString() ?? 'Credit Card';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> updateProfile(
    String name, 
    String phone, 
    String address, 
    String city, 
    String postalCode, 
    String paymentMethod
  ) async {
    if (user == null) return;
    
    try {
      await user!.updateDisplayName(name);
      
      await service.db.collection(FirestoreCollections.users).doc(user!.uid).set({
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

  bool get isSeller => role == 'seller';
  bool get isBuyer => role == 'buyer';
  bool get isLoggedIn => user != null;
}