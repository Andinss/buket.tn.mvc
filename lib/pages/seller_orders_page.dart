import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../services/firebase_service.dart';
import '../models/order.dart';
import '../utils/helpers.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pesanan Masuk', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFFFF6B9D),
            labelColor: const Color(0xFFFF6B9D),
            unselectedLabelColor: Colors.grey,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.only(left: 20, right: 20),
            tabs: const [
              Tab(text: 'Semua'),
              Tab(text: 'Diproses'),
              Tab(text: 'Dikemas'),
              Tab(text: 'Dikirim'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.db.collection('orders').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B9D)));
          }

          if (snapshot.hasError) {
            debugPrint('Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Color(0xFFFF6B9D)),
                  const SizedBox(height: 16),
                  const Text('Terjadi Kesalahan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          try {
            final allOrders = snapshot.data!.docs.map((doc) {
              try {
                return Order.fromDoc(doc);
              } catch (e) {
                debugPrint('Error parsing order ${doc.id}: $e');
                return Order(
                  id: doc.id,
                  buyerId: 'Unknown',
                  items: [],
                  total: 0,
                  status: 'placed',
                  createdAt: DateTime.now(),
                );
              }
            }).toList();

            final placedOrders = allOrders.where((o) => o.status == 'placed').toList();
            final processingOrders = allOrders.where((o) => o.status == 'processing').toList();
            final shippedOrders = allOrders.where((o) => o.status == 'shipped').toList();
            final completedOrders = allOrders.where((o) => o.status == 'completed').toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildSellerOrdersList(allOrders, 'Belum Ada Pesanan'),
                _buildSellerOrdersList(placedOrders, 'Tidak ada pesanan yang diproses'),
                _buildSellerOrdersList(processingOrders, 'Tidak ada pesanan yang dikemas'),
                _buildSellerOrdersList(shippedOrders, 'Tidak ada pesanan yang dikirim'),
                _buildSellerOrdersList(completedOrders, 'Tidak ada pesanan yang selesai'),
              ],
            );
          } catch (e) {
            debugPrint('Error building orders list: $e');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Color(0xFFFF6B9D)),
                  const SizedBox(height: 16),
                  const Text('Error Memuat Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('$e', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSellerOrdersList(List<Order> orders, String emptyMessage) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: const BoxDecoration(color: Color(0xFFFFE8F0), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_outlined, size: 80, color: Color(0xFFFF6B9D)),
            ),
            const SizedBox(height: 30),
            Text(emptyMessage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            const SizedBox(height: 12),
            Text('Belum ada pesanan dengan status ini', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      color: const Color(0xFFFF6B9D),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildSellerOrderItem(order);
        },
      ),
    );
  }

  Widget _buildSellerOrderItem(Order order) {
    final statusColor = getStatusColor(order.status);
    final statusTextColor = getStatusTextColor(order.status);
    final statusLabel = getStatusLabel(order.status);

    return GestureDetector(
      onTap: () => _showSellerOrderDetailDialog(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #${order.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                      const SizedBox(height: 4),
                      Text(
                        '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showChangeStatusDialog(order),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusTextColor, width: 1.5),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusTextColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Item:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (order.items.isEmpty)
                    const Text('Tidak ada item', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ...order.items.map((item) {
                    final itemName = item['name']?.toString() ?? 'Unknown Item';
                    final quantity = (item['qty'] is int) ? item['qty'] as int : 1;
                    final price = (item['price'] is int) ? item['price'] as int : 0;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('$itemName × $quantity', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ),
                          Text(formatRupiah(price * quantity), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(formatRupiah(order.total.toInt()), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSellerOrderDetailDialog(Order order) {
    final statusColor = getStatusColor(order.status);
    final statusTextColor = getStatusTextColor(order.status);
    final statusLabel = getStatusLabel(order.status);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 700),
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
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFFFF6B9D), size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Detail Pesanan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusTextColor),
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(order.buyerId).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return _buildDetailSection(
                              title: 'Informasi Pembeli',
                              children: [
                                const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B9D))),
                              ],
                            );
                          }

                          if (userSnapshot.hasError || !userSnapshot.hasData) {
                            return _buildDetailSection(
                              title: 'Informasi Pembeli',
                              children: [
                                _buildDetailRow('Nama', 'Tidak tersedia'),
                                _buildDetailRow('Email', 'Tidak tersedia'),
                                _buildDetailRow('Telepon', 'Tidak tersedia'),
                                _buildDetailRow('Alamat', 'Tidak tersedia'),
                              ],
                            );
                          }

                          final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                          final displayName = userData['displayName']?.toString() ?? 'Tidak tersedia';
                          final email = userData['email']?.toString() ?? 'Tidak tersedia';
                          final phone = userData['phoneNumber']?.toString() ?? 'Tidak tersedia';
                          final address = userData['address']?.toString() ?? 'Tidak tersedia';
                          final city = userData['city']?.toString() ?? '';
                          final postalCode = userData['postalCode']?.toString() ?? '';

                          String fullAddress = address;
                          if (city.isNotEmpty) fullAddress += ', $city';
                          if (postalCode.isNotEmpty) fullAddress += ', $postalCode';

                          return _buildDetailSection(
                            title: 'Informasi Pembeli',
                            children: [
                              _buildDetailRow('Nama', displayName),
                              _buildDetailRow('Email', email),
                              _buildDetailRow('Telepon', phone.isEmpty ? 'Tidak tersedia' : phone),
                              _buildDetailRow('Alamat', fullAddress.isEmpty ? 'Tidak tersedia' : fullAddress),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildDetailSection(
                        title: 'Informasi Pesanan',
                        children: [
                          _buildDetailRow('ID Pesanan', order.id.substring(0, 8).toUpperCase()),
                          _buildDetailRow('Tanggal', '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}'),
                          _buildDetailRow('Waktu', '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}'),
                          _buildDetailRow('Status', statusLabel),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildDetailSection(
                        title: 'Item Pesanan',
                        children: [
                          ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name']?.toString() ?? 'Unknown Item',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '${item['qty']} × ${formatRupiah(item['price'])}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatRupiah((item['price'] ?? 0) * (item['qty'] ?? 1)),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Pembayaran',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            Text(
                              formatRupiah(order.total.toInt()),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B9D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
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
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFFF6B9D)),
                        ),
                        child: const Text('Tutup', style: TextStyle(color: Color(0xFFFF6B9D), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showChangeStatusDialog(order);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B9D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Ubah Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
          ),
        ],
      ),
    );
  }

  void _showChangeStatusDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ubah Status Pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih status baru:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            ...['placed', 'processing', 'shipped', 'completed'].map((status) {
              final isSelected = order.status == status;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: isSelected
                      ? null
                      : () {
                          final service = FirebaseService();
                          service.updateOrderStatus(order.id, status);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Status diubah menjadi ${getStatusLabel(status)}'),
                              backgroundColor: const Color(0xFFFF6B9D),
                            ),
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF6B9D) : getStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getStatusTextColor(status), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: isSelected ? Colors.white : getStatusTextColor(status), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          getStatusLabel(status),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : getStatusTextColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}