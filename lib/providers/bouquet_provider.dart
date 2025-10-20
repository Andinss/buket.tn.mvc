import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';
import '../models/bouquet.dart';

class BouquetProvider with ChangeNotifier {
  final FirebaseService service;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  List<Bouquet> bouquets = [];

  BouquetProvider(this.service) {
    init();
  }

  Future<void> init() async {
    await service.seedBouquetsIfNeeded();
    db.collection('bouquets').orderBy('createdAt').snapshots().listen((snap) {
      bouquets = snap.docs.map((d) => Bouquet.fromDoc(d)).toList();
      notifyListeners();
    });
  }
}