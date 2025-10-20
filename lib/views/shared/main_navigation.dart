import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/favorite_provider.dart';
import '../buyer/home_page.dart';
import '../buyer/activity_page.dart';
import '../buyer/cart_page.dart';
import '../seller/seller_products_page.dart';
import '../seller/seller_orders_page.dart';
import '../seller/seller_analytics_page.dart';
import 'profile_page.dart';
import '../../utils/constants.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isSeller = auth.isSeller;

    final List<Widget> buyerPages = [
      const HomePage(),
      const ActivityPage(),
      const CartPage(),
      const ProfilePage(),
    ];

    final List<Widget> sellerPages = [
      const SellerProductsPage(),
      const SellerOrdersPage(),
      const SellerAnalyticsPage(),
      const ProfilePage(),
    ];

    final pages = isSeller ? sellerPages : buyerPages;

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigationBar(isSeller),
    );
  }

  Widget _buildBottomNavigationBar(bool isSeller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 0,
          items: isSeller ? _sellerNavItems() : _buyerNavItems(),
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _buyerNavItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded, size: 28),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_rounded, size: 28),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.shopping_cart_rounded, size: 28),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_rounded, size: 28),
        label: '',
      ),
    ];
  }

  List<BottomNavigationBarItem> _sellerNavItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.store_rounded, size: 28),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_rounded, size: 28),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.trending_up_rounded, size: 28),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_rounded, size: 28),
        label: '',
      ),
    ];
  }
}