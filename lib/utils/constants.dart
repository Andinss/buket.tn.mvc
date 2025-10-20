import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFF6B9D);
  static const secondary = Color(0xFFDB2777);
  static const background = Color(0xFFFAFAFA);
  static const textPrimary = Color(0xFF2D3142);
  static const textSecondary = Color(0xFF9CA3AF);
  static const accentPink = Color(0xFFFFE8F0);
  static const lightPink = Color(0xFFFFF0F5);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
}

class AppStrings {
  static const appName = 'Toko Bunga Cantik';
  static const appSlogan = 'Bunga Segar Setiap Hari';
}

class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const detail = '/detail';
  static const cart = '/cart';
  static const profile = '/profile';
  static const activity = '/activity';
  static const favorites = '/favorites';
}

class FirestoreCollections {
  static const users = 'users';
  static const bouquets = 'bouquets';
  static const orders = 'orders';
  static const favorites = 'favorites';
}