import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_item.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../utils/helpers.dart';

class OrderConfirmationDialog extends StatefulWidget {
  final List<CartItem> items;
  final int total;
  final AuthProvider auth;
  final Function(String phone, String address, String city, String postalCode, String paymentMethod) onConfirm;

  const OrderConfirmationDialog({
    super.key,
    required this.items,
    required this.total,
    required this.auth,
    required this.onConfirm,
  });

  @override
  State<OrderConfirmationDialog> createState() => _OrderConfirmationDialogState();
}

class _OrderConfirmationDialogState extends State<OrderConfirmationDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedPaymentMethod = 'Transfer Bank';
  final List<String> _paymentMethods = [
    'Transfer Bank',
    'E-Wallet',
    'Bayar di Tempat (COD)'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _nameController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _addressController.addListener(() => setState(() {}));
  }

  Future<void> _loadUserData() async {
    try {
      if (widget.auth.user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.auth.user!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _nameController.text = data['displayName']?.toString() ?? '';
          _phoneController.text = data['phoneNumber']?.toString() ?? '';
          _addressController.text = data['address']?.toString() ?? '';
          _cityController.text = data['city']?.toString() ?? '';
          _postalCodeController.text = data['postalCode']?.toString() ?? '';

          String paymentMethod = data['paymentMethod']?.toString() ?? 'Transfer Bank';
          _selectedPaymentMethod = paymentMethod.isEmpty ? 'Transfer Bank' : paymentMethod;
        });
      } else {
        setState(() {
          _nameController.text = widget.auth.user?.displayName ?? '';
          _phoneController.text = widget.auth.phoneNumber;
          _addressController.text = widget.auth.address;
          _cityController.text = widget.auth.city;
          _postalCodeController.text = widget.auth.postalCode;
          _selectedPaymentMethod = widget.auth.paymentMethod.isNotEmpty
              ? (widget.auth.paymentMethod == 'Credit Card' ? 'Transfer Bank' : widget.auth.paymentMethod)
              : 'Transfer Bank';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _nameController.text = widget.auth.user?.displayName ?? '';
        _phoneController.text = widget.auth.phoneNumber;
        _addressController.text = widget.auth.address;
        _cityController.text = widget.auth.city;
        _postalCodeController.text = widget.auth.postalCode;
        _selectedPaymentMethod = widget.auth.paymentMethod.isNotEmpty
            ? (widget.auth.paymentMethod == 'Credit Card' ? 'Transfer Bank' : widget.auth.paymentMethod)
            : 'Transfer Bank';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _processPlaceOrder() async {
    try {
      if (widget.auth.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan login terlebih dahulu.')),
        );
        return;
      }

      final firebaseService = FirebaseService();
      final uid = widget.auth.user!.uid;

      await firebaseService.placeOrder(
        uid,
        widget.items,
        widget.total.toDouble(),
        _selectedPaymentMethod, // argumen ke-4
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Gagal membuat pesanan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat pesanan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shopping_cart_checkout, color: Color(0xFFFF6B9D), size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Checkout',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildSectionHeader('Informasi Pengiriman'),
                    const SizedBox(height: 16),
                    _buildFormField(
                      label: 'Nama Penerima',
                      controller: _nameController,
                      icon: Icons.person,
                      hintText: 'Masukkan nama penerima',
                    ),
                    const SizedBox(height: 12),
                    _buildFormField(
                      label: 'Nomor Telepon',
                      controller: _phoneController,
                      icon: Icons.phone,
                      hintText: 'Contoh: 081234567890',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildFormField(
                      label: 'Alamat Lengkap',
                      controller: _addressController,
                      icon: Icons.location_on,
                      hintText: 'Masukkan alamat lengkap',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _buildFormField(
                      label: 'Kota/Kabupaten',
                      controller: _cityController,
                      icon: Icons.location_city,
                      hintText: 'Masukkan kota/kabupaten',
                    ),
                    const SizedBox(height: 12),
                    _buildFormField(
                      label: 'Kode Pos',
                      controller: _postalCodeController,
                      icon: Icons.markunread_mailbox,
                      hintText: 'Masukkan kode pos',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildFormField(
                      label: 'Catatan (Opsional)',
                      controller: _notesController,
                      icon: Icons.note,
                      hintText: 'Tambahkan catatan untuk kurir',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Metode Pembayaran'),
                    const SizedBox(height: 16),
                    ..._buildPaymentMethods(),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Ringkasan Pesanan'),
                    const SizedBox(height: 16),
                    _buildOrderSummary(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      Text(
                        formatRupiah(widget.total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B9D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nameController.text.isEmpty ||
                              _phoneController.text.isEmpty ||
                              _addressController.text.isEmpty
                          ? null
                          : () async {
                              widget.onConfirm(
                                _phoneController.text,
                                _addressController.text,
                                _cityController.text,
                                _postalCodeController.text,
                                _selectedPaymentMethod,
                              );
                              await _processPlaceOrder();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B9D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Bayar ${formatRupiah(widget.total)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildSectionHeader(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3142),
        ),
      );

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: const Color(0xFFFF6B9D)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B9D), width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Divider(color: Colors.grey.shade300, thickness: 1);

  List<Widget> _buildPaymentMethods() => _paymentMethods.map((method) {
        final bool isSelected = _selectedPaymentMethod == method;
        String description = '';
        if (method == 'Transfer Bank') {
          description = 'BCA, BNI, Mandiri, BRI';
        } else if (method == 'E-Wallet') {
          description = 'Gopay, OVO, Dana, LinkAja';
        } else if (method == 'Bayar di Tempat (COD)') {
          description = 'Bayar saat barang diterima';
        }

        return GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = method),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFF0F5) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFF6B9D)
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFFFF6B9D) : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF6B9D)
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFFF6B9D)
                              : const Color(0xFF2D3142),
                        ),
                      ),
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
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
      }).toList();

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('Produk',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142))),
              ),
              Expanded(
                child: Text('Subtotal',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('${item.bouquet.name} × ${item.quantity}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF2D3142))),
                    ),
                    Expanded(
                      child: Text(formatRupiah(item.price * item.quantity),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3142))),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          _buildDivider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text('Total',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142))),
              ),
              Expanded(
                child: Text(formatRupiah(widget.total),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B9D))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
