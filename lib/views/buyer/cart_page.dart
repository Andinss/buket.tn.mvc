import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/build_product_image.dart';
import '../../widgets/order_confirmation_dialog.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Map<String, bool> selectedItems = {};

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
              auth.city,
              auth.postalCode,
              paymentMethod
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
                backgroundColor: AppColors.primary,
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
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    if (selectedItems.isEmpty && cart.items.isNotEmpty) {
      for (var item in cart.items) {
        selectedItems[item.bouquet.id] = true;
      }
    }

    final allSelected = cart.items.isNotEmpty && 
        cart.items.every((item) => selectedItems[item.bouquet.id] == true);

    final selectedCount = selectedItems.values.where((v) => v).length;
    final selectedTotal = cart.items.fold<int>(0, (sum, item) {
      if (selectedItems[item.bouquet.id] == true) {
        return sum + (item.price * item.quantity);
      }
      return sum;
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: cart.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: const BoxDecoration(color: AppColors.accentPink, shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.primary),
                    ),
                    const SizedBox(height: 30),
                    const Text('Your Cart is Empty', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Text('Add some beautiful flowers to your cart', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        final mainNavState = context.findAncestorStateOfType<_MainNavigationState>();
                        if (mainNavState != null) {
                          mainNavState.setState(() {
                            mainNavState._selectedIndex = 0;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text('Start Shopping', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Cart', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.accentPink, borderRadius: BorderRadius.circular(20)),
                              child: Text('${cart.getTotalItems()} items', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              for (var item in cart.items) {
                                selectedItems[item.bouquet.id] = !allSelected;
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: allSelected ? AppColors.primary : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary, width: 2),
                                ),
                                child: allSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                              ),
                              const SizedBox(width: 8),
                              const Text('Pilih Semua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        final isSelected = selectedItems[item.bouquet.id] ?? true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                            border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedItems[item.bouquet.id] = !isSelected;
                                  });
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2),
                                  ),
                                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(colors: [AppColors.accentPink, AppColors.lightPink]),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: item.bouquet.images.isNotEmpty 
                                      ? buildProductImage(item.bouquet.images[0]) 
                                      : const Icon(Icons.image, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.bouquet.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(item.bouquet.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    const SizedBox(height: 6),
                                    Text(formatRupiah(item.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => cart.removeItem(item.bouquet.id)),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: AppColors.lightPink, borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.delete_outline, size: 16, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(6)),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => setState(() => cart.updateQuantity(item.bouquet.id, item.quantity - 1)),
                                          child: const Icon(Icons.remove, size: 14, color: AppColors.primary),
                                        ),
                                        Container(width: 20, alignment: Alignment.center, child: Text('${item.quantity}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                        GestureDetector(
                                          onTap: () => setState(() => cart.updateQuantity(item.bouquet.id, item.quantity + 1)),
                                          child: const Icon(Icons.add, size: 14, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Selected ($selectedCount)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text(formatRupiah(selectedTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: selectedCount == 0 ? null : () {
                              final selectedItems = cart.items.where((item) => this.selectedItems[item.bouquet.id] == true).toList();
                              final total = selectedItems.fold<int>(0, (sum, item) => sum + (item.price * item.quantity));

                              _showOrderConfirmationDialog(selectedItems, total, cart);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedCount == 0 ? Colors.grey : AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text(
                              selectedCount == 0 ? 'Pilih Produk Terlebih Dahulu' : 'Checkout (${selectedCount})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}