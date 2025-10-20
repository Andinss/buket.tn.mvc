import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class FavoriteProvider with ChangeNotifier {
  final FirebaseService service;
  List<String> favoriteIds = [];
  String? currentUid;

  FavoriteProvider(this.service);

  void setUser(String? uid) {
    currentUid = uid;
    if (uid != null) {
      service.getFavorites(uid).listen((ids) {
        favoriteIds = ids;
        notifyListeners();
      });
    } else {
      favoriteIds = [];
      notifyListeners();
    }
  }

  bool isFavorite(String bouquetId) => favoriteIds.contains(bouquetId);

  Future<void> toggleFavorite(String bouquetId) async {
    if (currentUid == null) return;
    await service.toggleFavorite(currentUid!, bouquetId);
  }
}