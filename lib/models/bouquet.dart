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

  // 🔹 Convert ke Map untuk Firebase
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'images': images,
        'category': category,
        'details': details,
        'sellerId': sellerId,
      };

  // 🔹 Ambil data dari Map/Firebase
  factory Bouquet.fromMap(Map<String, dynamic> map) {
    return Bouquet(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: map['price'] ?? 0,
      images: map['images'] != null
          ? List<String>.from(map['images'])
          : [],
      category: map['category'] ?? '',
      details: map['details'] ?? '',
      sellerId: map['sellerId'] ?? '',
    );
  }

  // 🔹 Ambil data langsung dari DocumentSnapshot Firestore
  factory Bouquet.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bouquet(
      id: doc.id, // pakai ID doc Firestore
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: data['price'] ?? 0,
      images: data['images'] != null
          ? List<String>.from(data['images'])
          : [],
      category: data['category'] ?? '',
      details: data['details'] ?? '',
      sellerId: data['sellerId'] ?? '',
    );
  }
}
