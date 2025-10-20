import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../providers/auth_provider.dart';
import '../providers/bouquet_provider.dart';
import '../services/firebase_service.dart';
import '../models/order.dart';
import '../utils/helpers.dart';

class SellerAnalyticsPage extends StatelessWidget {
  const SellerAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bouquets = Provider.of<BouquetProvider>(context).bouquets;
    final service = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Analytics', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.db.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B9D)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Color(0xFFFF6B9D)),
                  const SizedBox(height: 16),
                  const Text('Error loading analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          final allOrders = snapshot.data?.docs.map((doc) => Order.fromDoc(doc)).toList() ?? [];

          int totalRevenue = 0;
          int placedCount = 0;
          int processingCount = 0;
          int shippedCount = 0;
          int completedCount = 0;

          for (var order in allOrders) {
            totalRevenue += order.total.toInt();
            switch (order.status) {
              case 'placed':
                placedCount++;
                break;
              case 'processing':
                processingCount++;
                break;
              case 'shipped':
                shippedCount++;
                break;
              case 'completed':
                completedCount++;
                break;
            }
          }

          final sellerProducts = bouquets.where((b) => b.sellerId == auth.user?.uid || b.sellerId == 'admin').length;
          final totalOrders = allOrders.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildKPICard(
                        title: 'Total Revenue',
                        value: formatRupiah(totalRevenue),
                        icon: Icons.trending_up,
                        color: const Color(0xFFFF6B9D),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildKPICard(
                        title: 'Total Orders',
                        value: '$totalOrders',
                        icon: Icons.shopping_bag,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildKPICard(
                        title: 'Products',
                        value: '$sellerProducts',
                        icon: Icons.local_florist,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildKPICard(
                        title: 'Completed',
                        value: '$completedCount',
                        icon: Icons.check_circle,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                const Text('Order Status Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      _buildStatusRow('Diproses', placedCount, const Color(0xFFFEF3C7), const Color(0xFFC78500)),
                      const SizedBox(height: 12),
                      _buildStatusRow('Sedang Dikemas', processingCount, const Color(0xFFBFDBFE), const Color(0xFF1E40AF)),
                      const SizedBox(height: 12),
                      _buildStatusRow('Dikirim', shippedCount, const Color(0xFFDDD6FE), const Color(0xFF5B21B6)),
                      const SizedBox(height: 12),
                      _buildStatusRow('Selesai', completedCount, const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                const SizedBox(height: 15),
                if (allOrders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: const Center(
                      child: Text('Belum ada pesanan', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ),
                  )
                else
                  ...allOrders.take(5).map((order) {
                    final statusColor = getStatusColor(order.status);
                    final statusTextColor = getStatusTextColor(order.status);
                    final statusLabel = getStatusLabel(order.status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order #${order.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(16)),
                                child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusTextColor)),
                              ),
                              const SizedBox(height: 6),
                              Text(formatRupiah(order.total.toInt()), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              shape: BoxShape.rectangle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color bgColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
      ],
    );
  }
}