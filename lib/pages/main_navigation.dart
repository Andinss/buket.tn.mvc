import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'home_page.dart';
import 'activity_page.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'seller_products_page.dart';
import 'seller_orders_page.dart';
import 'seller_analytics_page.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isSeller = auth.role == 'seller';

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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFFFF6B9D),
            unselectedItemColor: Colors.grey.shade400,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            elevation: 0,
            items: isSeller
                ? const [
                    BottomNavigationBarItem(icon: Icon(Icons.store_rounded, size: 28), label: ''),
                    BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 28), label: ''),
                    BottomNavigationBarItem(icon: Icon(Icons.trending_up_rounded, size: 28), label: ''),
                    BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 28), label: ''),
                  ]
                : const [
                    BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 28), label: ''),
                    BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 28), label: ''),
                    BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_rounded, size: 28), label: ''),
                    BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 28), label: ''),
                  ],
          ),
        ),
      ),
    );
  }
}