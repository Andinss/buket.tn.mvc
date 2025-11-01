import 'package:buket.tn.mvc/models/cart_item.dart';
import 'package:buket.tn.mvc/pages/cart_page.dart';
import 'package:buket.tn.mvc/pages/favorite_page.dart';
import 'package:buket.tn.mvc/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool isProcessingOrder = false; // ⬅️ Cegah pesanan ganda

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
    final cart = Provider.of<CartProvider>(context, listen: false);
    final total = widget.bouquet.price * quantity;

    _showOrderConfirmationDialog(
        [CartItem(bouquet: widget.bouquet, quantity: quantity)],
        total,
        cart);
  }

  void _showOrderConfirmationDialog(
      List<CartItem> items, int total, CartProvider cart) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (isProcessingOrder) return;
    isProcessingOrder = true;

    showDialog(
      context: context,
      builder: (context) => OrderConfirmationDialog(
        items: items,
        total: total,
        auth: auth,
        onConfirm: (phone, address, city, postalCode, paymentMethod) async {
          try {
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
            await service.placeOrder(
              auth.user!.uid,
              items,
              total.toDouble(),
              paymentMethod,
            );

            for (var item in items) {
              cart.removeItem(item.bouquet.id);
            }

            if (context.mounted) {
              Navigator.popUntil(context, (route) => route.isFirst);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pesanan berhasil dibuat!'),
                  backgroundColor: Color(0xFFFF6B9D),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Terjadi kesalahan: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } finally {
            isProcessingOrder = false;
          }
        },
      ),
    );
  }

  Future<void> _contactWhatsApp() async {
    final phone = '6281234567890';
    final message = Uri.encodeComponent(
      'Halo, saya tertarik dengan ${widget.bouquet.name}\n'
      'Harga: ${formatRupiah(widget.bouquet.price)}\n'
      'Apakah produk ini tersedia?',
    );
    final url = 'https://wa.me/$phone?text=$message';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
      );
    }
  }

  Widget buildProductImage(String? url) {
    return Image.network(
      url ?? 'https://via.placeholder.com/400',
      width: double.infinity,
      height: 400,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Image.network('https://via.placeholder.com/400', fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    final isFavorite = favoriteProvider.isFavorite(widget.bouquet.id);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  ),
                  const Text(
                    'Detail Product',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CartPage(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: cart.totalItems > 0
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B9D)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              const Icon(Icons.shopping_cart,
                                  color: Color(0xFFFF6B9D), size: 20),
                              if (cart.totalItems > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '${cart.totalItems}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          await favoriteProvider.toggleFavorite(widget.bouquet.id);
                          if (!isFavorite) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Ditambahkan ke favorit!'),
                                backgroundColor: const Color(0xFFFF6B9D),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                action: SnackBarAction(
                                  label: 'Lihat',
                                  textColor: Colors.white,
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const FavoritePage(),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: const Color(0xFFFF6B9D),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Image carousel & detail
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE8F0), Color(0xFFFFF0F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          height: 400,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) =>
                                setState(() => currentImageIndex = index),
                            itemCount: widget.bouquet.images.length,
                            itemBuilder: (context, index) {
                              final imageUrl = widget.bouquet.images.isNotEmpty
                                  ? widget.bouquet.images[index]
                                  : null;
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: buildProductImage(imageUrl),
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
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: currentImageIndex == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: currentImageIndex == index
                                      ? const Color(0xFFFF6B9D)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Detail info
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
                                    Text(
                                      widget.bouquet.name,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D3142),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.bouquet.category,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatRupiah(widget.bouquet.price),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF6B9D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.bouquet.details,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Quantity
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Quantity:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        if (quantity > 1) {
                                          setState(() => quantity--);
                                        }
                                      },
                                      icon: const Icon(Icons.remove),
                                      color: const Color(0xFFFF6B9D),
                                    ),
                                    Container(
                                      width: 40,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$quantity',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          setState(() => quantity++),
                                      icon: const Icon(Icons.add),
                                      color: const Color(0xFFFF6B9D),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 🔹 Tombol Add to Cart
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                cart.addToCart(widget.bouquet, quantity);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        const Text('Added to cart!'),
                                    backgroundColor:
                                        const Color(0xFFFF6B9D),
                                    behavior:
                                        SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    action: SnackBarAction(
                                      label: 'Lihat',
                                      textColor: Colors.white,
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CartPage(),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.shopping_cart_outlined,
                                  size: 18),
                              label: const Text('Tambah ke Keranjang'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB6C1),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // WhatsApp button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _contactWhatsApp,
                              icon: const Icon(Icons.chat, size: 18),
                              label: const Text('Chat via WhatsApp'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF25D366),
                                side: const BorderSide(
                                    color: Color(0xFF25D366)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Buy now button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _buyNow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFFFF6B9D),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                'Beli Sekarang',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
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
