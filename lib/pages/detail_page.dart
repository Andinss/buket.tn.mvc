import 'package:buket_tn/models/cart_item.dart';
import 'package:buket_tn/pages/favorite_page.dart';
import 'package:buket_tn/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bouquet.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/favorite_provider.dart';
import '../utils/helpers.dart';
import '../widgets/order_confirmation_dialog.dart';

class DetailPage extends StatefulWidget {
  final Bouquet bouquet;
  const DetailPage({super.key, required this.bouquet});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  int quantity = 1;
  int currentImageIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _buyNow() {
    // ignore: unused_local_variable
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final total = widget.bouquet.price * quantity;
    
    _showOrderConfirmationDialog([CartItem(bouquet: widget.bouquet, quantity: quantity)], total, cart);
  }

  void _showOrderConfirmationDialog(List<CartItem> items, int total, CartProvider cart) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => OrderConfirmationDialog(
        items: items,
        total: total,
        auth: auth,
        onConfirm: (phone, address, city, postalCode, paymentMethod) async {
          if (phone.isNotEmpty) {
            await auth.updateProfile(
              auth.user?.displayName ?? 'User',
              phone,
              address,
              city,
              postalCode,
              paymentMethod,
            );
          }
          
          final service = FirebaseService();
          try {
            await service.placeOrder(auth.user!.uid, items, total.toDouble());
            
            for (var item in items) {
              cart.removeItem(item.bouquet.id);
            }
            
            Navigator.popUntil(context, (route) => route.isFirst);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Pesanan berhasil dibuat!'),
                backgroundColor: const Color(0xFFFF6B9D),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (e) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    final isFavorite = favoriteProvider.isFavorite(widget.bouquet.id);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  ),
                  const Text('Detail Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                  GestureDetector(
                    onTap: () async {
                      await favoriteProvider.toggleFavorite(widget.bouquet.id);
                      if (!isFavorite) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Ditambahkan ke favorit!'),
                            backgroundColor: const Color(0xFFFF6B9D),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            action: SnackBarAction(
                              label: 'Lihat',
                              textColor: Colors.white,
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritePage())),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                      child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: const Color(0xFFFF6B9D), size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFE8F0), Color(0xFFFFF0F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          height: 400,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) => setState(() => currentImageIndex = index),
                            itemCount: widget.bouquet.images.length,
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: buildProductImage(widget.bouquet.images[index]),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              widget.bouquet.images.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: currentImageIndex == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(color: currentImageIndex == index ? const Color(0xFFFF6B9D) : Colors.white, borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.bouquet.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                                    const SizedBox(height: 4),
                                    Text(widget.bouquet.category, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              Text(formatRupiah(widget.bouquet.price), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(widget.bouquet.details, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.6)),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Quantity:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    IconButton(onPressed: () { if (quantity > 1) setState(() => quantity--); }, icon: const Icon(Icons.remove), color: const Color(0xFFFF6B9D)),
                                    Container(width: 40, alignment: Alignment.center, child: Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                    IconButton(onPressed: () => setState(() => quantity++), icon: const Icon(Icons.add), color: const Color(0xFFFF6B9D)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    cart.addItem(widget.bouquet, quantity);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Added to cart!'), 
                                        backgroundColor: const Color(0xFFFF6B9D), 
                                        behavior: SnackBarBehavior.floating, 
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFFFF6B9D),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(color: Color(0xFFFF6B9D), width: 2),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shopping_cart_outlined),
                                      SizedBox(width: 8),
                                      Text('Add to Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _buyNow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B9D),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shopping_bag_outlined, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Buy Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}