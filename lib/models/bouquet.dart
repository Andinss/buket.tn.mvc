import 'package:cloud_firestore/cloud_firestore.dart';

class Bouquet {
  final String id;
  final String name;
  final String description;
  final int price;
  final List<String> images;
  final String category;
  final String details;
  final String sellerId;

  Bouquet({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    required this.category,
    required this.details,
    required this.sellerId,
  });

  factory Bouquet.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Bouquet(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      price: d['price'] ?? 0,
      images: List<String>.from(d['images'] ?? []),
      category: d['category'] ?? '',
      details: d['details'] ?? '',
      sellerId: d['sellerId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'price': price,
    'images': images,
    'category': category,
    'details': details,
    'sellerId': sellerId,
  };
}