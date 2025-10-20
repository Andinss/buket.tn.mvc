import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';
import '../models/bouquet.dart';
import '../utils/constants.dart';

class BouquetProvider with ChangeNotifier {
  final FirebaseService service;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  List<Bouquet> bouquets = [];
  bool isLoading = false;

  BouquetProvider(this.service) {
    init();
  }

  Future<void> init() async {
    await service.seedBouquetsIfNeeded();
    _setupBouquetsStream();
  }

  void _setupBouquetsStream() {
    db.collection(FirestoreCollections.bouquets)
        .orderBy('createdAt')
        .snapshots()
        .listen((snap) {
      bouquets = snap.docs.map((d) => Bouquet.fromDoc(d)).toList();
      notifyListeners();
    });
  }

  List<Bouquet> getBouquetsBySeller(String sellerId) {
    return bouquets.where((b) => b.sellerId == sellerId).toList();
  }

  List<Bouquet> searchBouquets(String query) {
    if (query.isEmpty) return bouquets;
    return bouquets.where((b) =>
      b.name.toLowerCase().contains(query.toLowerCase()) ||
      b.description.toLowerCase().contains(query.toLowerCase()) ||
      b.category.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  List<Bouquet> getBouquetsByCategory(String category) {
    if (category == 'All') return bouquets;
    return bouquets.where((b) => b.category == category).toList();
  }
}