import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String id;
  final String buyerId;
  final List<Map<String, dynamic>> items;
  final double total;
  final String status;
  final DateTime createdAt;

  // 🔹 Tambahan field baru
  final bool isPreOrder;
  final DateTime? deliveryDate;
  final String paymentStatus; 
  final String shippingAddress; 
  final String notes;

  // 🔹 Tambahan field paymentMethod
  final String? paymentMethod;

  Order({
    required this.id,
    required this.buyerId,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
    this.isPreOrder = false,
    this.deliveryDate,
    this.paymentStatus = 'unpaid',
    this.shippingAddress = '',
    this.notes = '',
    this.paymentMethod,
  });

  factory Order.fromDoc(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      
      List<Map<String, dynamic>> itemsList = [];
      try {
        final itemsData = d['items'];
        if (itemsData is List) {
          itemsList = itemsData.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              return <String, dynamic>{};
            }
          }).toList();
        }
      } catch (e) {
        itemsList = [];
      }

      double totalValue = 0;
      try {
        final totalData = d['total'];
        if (totalData is int) {
          totalValue = totalData.toDouble();
        } else if (totalData is double) {
          totalValue = totalData;
        } else if (totalData is String) {
          totalValue = double.tryParse(totalData) ?? 0;
        }
      } catch (e) {
        totalValue = 0;
      }

      DateTime createdAtValue = DateTime.now();
      try {
        final createdAtData = d['createdAt'];
        if (createdAtData is Timestamp) {
          createdAtValue = createdAtData.toDate();
        } else if (createdAtData is String) {
          createdAtValue = DateTime.tryParse(createdAtData) ?? DateTime.now();
        }
      } catch (e) {
        createdAtValue = DateTime.now();
      }

      // 🔹 Tambahan parsing untuk field baru
      bool isPreOrderValue = false;
      try {
        isPreOrderValue = d['isPreOrder'] ?? false;
      } catch (e) {
        isPreOrderValue = false;
      }

      DateTime? deliveryDateValue;
      try {
        final deliveryDateData = d['deliveryDate'];
        if (deliveryDateData is Timestamp) {
          deliveryDateValue = deliveryDateData.toDate();
        } else if (deliveryDateData is String) {
          deliveryDateValue = DateTime.tryParse(deliveryDateData);
        }
      } catch (e) {
        deliveryDateValue = null;
      }

      String? paymentMethodValue;
      try {
        paymentMethodValue = d['paymentMethod']?.toString();
      } catch (e) {
        paymentMethodValue = null;
      }

      return Order(
        id: doc.id,
        buyerId: d['buyerId']?.toString() ?? 'Unknown',
        items: itemsList,
        total: totalValue,
        status: d['status']?.toString() ?? 'placed',
        createdAt: createdAtValue,
        isPreOrder: isPreOrderValue,
        deliveryDate: deliveryDateValue,
        paymentStatus: d['paymentStatus']?.toString() ?? 'unpaid',
        shippingAddress: d['shippingAddress']?.toString() ?? '',
        notes: d['notes']?.toString() ?? '',
        paymentMethod: paymentMethodValue,
      );
    } catch (e) {
      return Order(
        id: doc.id,
        buyerId: 'Unknown',
        items: [],
        total: 0,
        status: 'placed',
        createdAt: DateTime.now(),
        isPreOrder: false,
        deliveryDate: null,
        paymentStatus: 'unpaid',
        shippingAddress: '',
        notes: '',
        paymentMethod: null,
      );
    }
  }

  // 🔹 Tambahkan toMap() agar bisa disimpan ke Firestore
  Map<String, dynamic> toMap() => {
        'buyerId': buyerId,
        'items': items,
        'total': total,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'isPreOrder': isPreOrder,
        'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
        'paymentStatus': paymentStatus,
        'shippingAddress': shippingAddress,
        'notes': notes,
        'paymentMethod': paymentMethod,
      };
}
