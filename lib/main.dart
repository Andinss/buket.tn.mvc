import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

// ==================== MODELS ====================
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

class CartItem {
  final Bouquet bouquet;
  int quantity;

  CartItem({
    required this.bouquet,
    this.quantity = 1,
  });

  int get price => bouquet.price;
}

class Order {
  final String id;
  final String buyerId;
  final List<Map<String, dynamic>> items;
  final double total;
  final String status;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.buyerId,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  factory Order.fromDoc(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      
      // Handle items parsing safely
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
        debugPrint('Error parsing items: $e');
        itemsList = [];
      }

      // Handle total parsing
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
        debugPrint('Error parsing total: $e');
        totalValue = 0;
      }

      // Handle createdAt parsing
      DateTime createdAtValue = DateTime.now();
      try {
        final createdAtData = d['createdAt'];
        if (createdAtData is Timestamp) {
          createdAtValue = createdAtData.toDate();
        } else if (createdAtData is String) {
          createdAtValue = DateTime.tryParse(createdAtData) ?? DateTime.now();
        }
      } catch (e) {
        debugPrint('Error parsing createdAt: $e');
        createdAtValue = DateTime.now();
      }

      return Order(
        id: doc.id,
        buyerId: d['buyerId']?.toString() ?? 'Unknown',
        items: itemsList,
        total: totalValue,
        status: d['status']?.toString() ?? 'placed',
        createdAt: createdAtValue,
      );
    } catch (e) {
      debugPrint('Error creating Order from document: $e');
      // Return a default order if parsing fails completely
      return Order(
        id: doc.id,
        buyerId: 'Unknown',
        items: [],
        total: 0,
        status: 'placed',
        createdAt: DateTime.now(),
      );
    }
  }
}

// ==================== HELPER FUNCTIONS ====================
String formatRupiah(int amount) {
  return 'Rp. ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
}

String getStatusLabel(String status) {
  switch (status) {
    case 'placed':
      return 'Diproses';
    case 'processing':
      return 'Sedang Dikemas';
    case 'shipped':
      return 'Dikirim';
    case 'completed':
      return 'Selesai';
    default:
      return 'Pending';
  }
}

Color getStatusColor(String status) {
  switch (status) {
    case 'placed':
      return const Color(0xFFFEF3C7);
    case 'processing':
      return const Color(0xFFBFDBFE);
    case 'shipped':
      return const Color(0xFFDDD6FE);
    case 'completed':
      return const Color(0xFFDCFCE7);
    default:
      return const Color(0xFFFFE8F0);
  }
}

Color getStatusTextColor(String status) {
  switch (status) {
    case 'placed':
      return const Color(0xFFC78500);
    case 'processing':
      return const Color(0xFF1E40AF);
    case 'shipped':
      return const Color(0xFF5B21B6);
    case 'completed':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFFFF6B9D);
  }
}

// ==================== SERVICES ====================
class FirebaseService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Email sign in error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmail(String email, String password, String name) async {
    try {
      final userCred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      await userCred.user?.updateDisplayName(name);
      final uid = userCred.user!.uid;
      
      // Auto assign role berdasarkan email
      String role = 'buyer'; // default buyer
      if (email.toLowerCase() == 'andinn1404@gmail.com') {
        role = 'seller';
      }
      
      await db.collection('users').doc(uid).set({
        'displayName': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return userCred;
    } catch (e) {
      debugPrint('Email registration error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await auth.signInWithCredential(credential);
      final uid = userCred.user!.uid;
      final doc = db.collection('users').doc(uid);
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        // Auto assign role berdasarkan email
        String role = 'buyer'; // default buyer
        final email = userCred.user!.email ?? '';
        if (email.toLowerCase() == 'andinn1404@gmail.com') {
          role = 'seller';
        }
        
        await doc.set({
          'displayName': userCred.user!.displayName ?? '',
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return userCred;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await auth.signOut();
  }

  Future<void> setUserRole(String uid, String role) async {
    await db.collection('users').doc(uid).set({'role': role}, SetOptions(merge: true));
  }

  Future<String?> getUserRole(String uid) async {
    final snap = await db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return (snap.data()!['role'] ?? '') as String;
  }

  Future<void> seedBouquetsIfNeeded() async {
    final col = db.collection('bouquets');
    final snap = await col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final sample = [
      {
        'name': 'Tulip Garden',
        'description': 'Buket tulip warna-warni',
        'price': 0,
        'images': [
          'https://images.unsplash.com/photo-1520763185298-1b434c919102?w=500&h=500&fit=crop',
        ],
        'category': 'Elegant',
        'details': 'Tulip premium dengan berbagai warna elegan. Simbol cinta sempurna dan keindahan abadi.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Tulip Garden',
        'description': 'Buket tulip warna-warni',
        'price': 0,
        'images': [
          'https://images.unsplash.com/photo-1520763185298-1b434c919102?w=500&h=500&fit=crop',
        ],
        'category': 'Elegant',
        'details': 'Tulip premium dengan berbagai warna elegan. Simbol cinta sempurna dan keindahan abadi.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Tulip Garden',
        'description': 'Buket tulip warna-warni',
        'price': 0,
        'images': [
          'https://images.unsplash.com/photo-1520763185298-1b434c919102?w=500&h=500&fit=crop',
        ],
        'category': 'Elegant',
        'details': 'Tulip premium dengan berbagai warna elegan. Simbol cinta sempurna dan keindahan abadi.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Tulip Garden',
        'description': 'Buket tulip warna-warni',
        'price': 0,
        'images': [
          'https://images.unsplash.com/photo-1520763185298-1b434c919102?w=500&h=500&fit=crop',
        ],
        'category': 'Elegant',
        'details': 'Tulip premium dengan berbagai warna elegan. Simbol cinta sempurna dan keindahan abadi.',
        'sellerId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = db.batch();
    for (final p in sample) {
      final doc = col.doc();
      batch.set(doc, p);
    }
    await batch.commit();
  }

  Future<void> placeOrder(String uid, List<CartItem> items, double total) async {
    try {
      final doc = db.collection('orders').doc();
      await doc.set({
        'buyerId': uid,
        'items': items.map((c) => {
          'bouquetId': c.bouquet.id,
          'name': c.bouquet.name,
          'price': c.price,
          'qty': c.quantity,
        }).toList(),
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'placed',
      });
      debugPrint('Order placed successfully with ID: ${doc.id}');
    } catch (e) {
      debugPrint('Error placing order: $e');
      rethrow;
    }
  }

  Stream<List<Order>> getUserOrders(String uid) {
    return db.collection('orders')
        .where('buyerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Order.fromDoc(doc)).toList())
        .handleError((error) {
          debugPrint('Error in getUserOrders: $error');
          return <Order>[];
        });
  }

  Future<void> toggleFavorite(String uid, String bouquetId) async {
    final favRef = db.collection('users').doc(uid).collection('favorites').doc(bouquetId);
    final snap = await favRef.get();
    if (snap.exists) {
      await favRef.delete();
    } else {
      await favRef.set({'addedAt': FieldValue.serverTimestamp()});
    }
  }

  Stream<List<String>> getFavorites(String uid) {
    return db.collection('users').doc(uid).collection('favorites').snapshots().map(
      (snap) => snap.docs.map((doc) => doc.id).toList(),
    );
  }

  // Add / Update / Delete bouquet methods used by UI
  Future<void> addBouquet(Bouquet bouquet) async {
    final col = db.collection('bouquets');
    final data = bouquet.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    await col.add(data);
  }

  Future<void> updateBouquet(String id, Bouquet bouquet) async {
    final docRef = db.collection('bouquets').doc(id);
    final data = bouquet.toMap();
    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> deleteBouquet(String id) async {
    await db.collection('bouquets').doc(id).delete();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await db.collection('orders').doc(orderId).set({'status': status}, SetOptions(merge: true));
  }
}

// ==================== PROVIDERS ====================
class AuthProvider with ChangeNotifier {
  final FirebaseService service;
  User? user;
  String role = '';
  bool initializing = true;

  AuthProvider(this.service) {
    service.auth.authStateChanges().listen((u) async {
      user = u;
      if (user != null) {
        role = await service.getUserRole(user!.uid) ?? '';
      } else {
        role = '';
      }
      initializing = false;
      notifyListeners();
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    await service.signInWithEmail(email, password);
  }

  Future<void> registerWithEmail(String email, String password, String name) async {
    await service.registerWithEmail(email, password, name);
  }

  Future<void> signInWithGoogle() async {
    await service.signInWithGoogle();
  }

  Future<void> resetPassword(String email) async {
    await service.resetPassword(email);
  }

  Future<void> signOut() async {
    await service.signOut();
  }

  Future<void> setRole(String r) async {
    if (user == null) return;
    await service.setUserRole(user!.uid, r);
    role = r;
    notifyListeners();
  }
}

class BouquetProvider with ChangeNotifier {
  final FirebaseService service;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  List<Bouquet> bouquets = [];

  BouquetProvider(this.service) {
    init();
  }

  Future<void> init() async {
    await service.seedBouquetsIfNeeded();
    db.collection('bouquets').orderBy('createdAt').snapshots().listen((snap) {
      bouquets = snap.docs.map((d) => Bouquet.fromDoc(d)).toList();
      notifyListeners();
    });
  }
}

class CartProvider with ChangeNotifier {
  final List<CartItem> items = [];

  void addItem(Bouquet bouquet, int quantity) {
    final existingIndex = items.indexWhere((item) => item.bouquet.id == bouquet.id);
    if (existingIndex >= 0) {
      items[existingIndex].quantity += quantity;
    } else {
      items.add(CartItem(bouquet: bouquet, quantity: quantity));
    }
    notifyListeners();
  }

  void removeItem(String bouquetId) {
    items.removeWhere((item) => item.bouquet.id == bouquetId);
    notifyListeners();
  }

  void updateQuantity(String bouquetId, int newQuantity) {
    if (newQuantity < 1) {
      removeItem(bouquetId);
      return;
    }
    final index = items.indexWhere((item) => item.bouquet.id == bouquetId);
    if (index >= 0) {
      items[index].quantity = newQuantity;
      notifyListeners();
    }
  }

  int getTotalItems() => items.fold(0, (sum, item) => sum + item.quantity);
  int getTotalPrice() => items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  void clear() {
    items.clear();
    notifyListeners();
  }
}

class FavoriteProvider with ChangeNotifier {
  final FirebaseService service;
  List<String> favoriteIds = [];
  String? currentUid;

  FavoriteProvider(this.service);

  void setUser(String? uid) {
    currentUid = uid;
    if (uid != null) {
      service.getFavorites(uid).listen((ids) {
        favoriteIds = ids;
        notifyListeners();
      });
    } else {
      favoriteIds = [];
      notifyListeners();
    }
  }

  bool isFavorite(String bouquetId) => favoriteIds.contains(bouquetId);

  Future<void> toggleFavorite(String bouquetId) async {
    if (currentUid == null) return;
    await service.toggleFavorite(currentUid!, bouquetId);
  }
}

// ==================== MAIN ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final service = FirebaseService();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider(service)),
      ChangeNotifierProvider(create: (_) => BouquetProvider(service)),
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ChangeNotifierProvider(create: (_) => FavoriteProvider(service)),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toko Bunga Cantik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.pink, useMaterial3: true),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.initializing) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (auth.user == null) return const LoginPage();
          // Langsung ke MainNavigation tanpa role selection
          Provider.of<FavoriteProvider>(context, listen: false).setUser(auth.user?.uid);
          return const MainNavigation();
        },
      ),
    );
  }
}

// ==================== MAIN NAVIGATION ====================
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

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

// ==================== LOGIN PAGE ====================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (_isLogin) {
        await auth.signInWithEmail(_emailController.text.trim(), _passwordController.text.trim());
      } else {
        await auth.registerWithEmail(_emailController.text.trim(), _passwordController.text.trim(), _nameController.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLogin ? 'Login gagal: $e' : 'Registrasi gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login dengan Google gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Kata Sandi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan email Anda untuk menerima link reset kata sandi'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email, color: Color(0xFFDB2777)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email tidak boleh kosong'), backgroundColor: Colors.red),
                );
                return;
              }
              try {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await auth.resetPassword(emailController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link reset kata sandi telah dikirim ke email Anda'), backgroundColor: Color(0xFFDB2777)),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal mengirim email: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB2777)),
            child: const Text('Kirim', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFCE7F3), Color(0xFFF9A8D4), Color(0xFFF472B6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: const Text('🌹', style: TextStyle(fontSize: 60)),
                  ),
                  const SizedBox(height: 30),
                  const Text('Toko Bunga Cantik', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Bunga Segar Setiap Hari', style: TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isLogin ? 'Login' : 'Buat Akun',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF831843)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (!_isLogin) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Lengkap',
                                prefixIcon: const Icon(Icons.person, color: Color(0xFFDB2777)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDB2777), width: 2),
                                ),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Nama tidak boleh kosong' : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email, color: Color(0xFFDB2777)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFDB2777), width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Email tidak boleh kosong';
                              if (!value!.contains('@')) return 'Email tidak valid';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Kata Sandi',
                              prefixIcon: const Icon(Icons.lock, color: Color(0xFFDB2777)),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFFDB2777)),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFDB2777), width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Kata sandi tidak boleh kosong';
                              if (value!.length < 6) return 'Kata sandi minimal 6 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDB2777),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(_isLogin ? 'Masuk' : 'Daftar', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('atau', style: TextStyle(color: Colors.grey))),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _signInWithGoogle,
                            icon: Image.network(
                              'https://developers.google.com/identity/images/g-logo.png',
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24, color: Color(0xFF831843)),
                            ),
                            label: const Text('Masuk dengan Google', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF831843))),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFDB2777)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ', style: const TextStyle(color: Colors.grey)),
                              TextButton(
                                onPressed: () => setState(() => _isLogin = !_isLogin),
                                child: Text(_isLogin ? 'Daftar' : 'Masuk', style: const TextStyle(color: Color(0xFFDB2777), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          if (_isLogin) ...[
                            TextButton(
                              onPressed: _resetPassword,
                              child: const Text('Lupa kata sandi?', style: TextStyle(color: Color(0xFFDB2777), fontSize: 13)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== IMAGE DISPLAY HELPER ====================
Widget buildProductImage(String imageData, {BoxFit fit = BoxFit.cover}) {
  if (imageData.isEmpty) {
    return Container(
      color: const Color(0xFFFFE8F0),
      child: const Icon(Icons.image, color: Color(0xFFFF6B9D)),
    );
  }

  if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
    return Image.network(
      imageData,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFFFE8F0),
          child: const Icon(Icons.error, color: Color(0xFFFF6B9D)),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFFFFE8F0),
          child: const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B9D),
                strokeWidth: 2,
              ),
            ),
          ),
        );
      },
    );
  } else {
    try {
      return Image.memory(
        base64Decode(imageData),
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFFFE8F0),
            child: const Icon(Icons.error, color: Color(0xFFFF6B9D)),
          );
        },
      );
    } catch (e) {
      debugPrint('Error decoding Base64: $e');
      return Container(
        color: const Color(0xFFFFE8F0),
        child: const Icon(Icons.broken_image, color: Color(0xFFFF6B9D)),
      );
    }
  }
}

// ==================== HOME PAGE (UPDATED HEADER) ====================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedCategory = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final allBouquets = Provider.of<BouquetProvider>(context).bouquets;
    final favoriteProvider = Provider.of<FavoriteProvider>(context);

    // Filter berdasarkan search query
    final filteredBouquets = allBouquets.where((b) =>
      b.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
      b.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
      b.category.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Fixed (UPDATED: Hapus Jakarta, INA)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // UPDATED: Hanya Hello Username (Bold)
                  Text(
                    'Hello ${auth.user?.displayName?.split(' ').first ?? 'User'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritePage())),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Color(0xFFFFE8F0), shape: BoxShape.circle),
                      child: Stack(
                        children: [
                          const Icon(Icons.favorite, color: Color(0xFFFF6B9D), size: 24),
                          if (favoriteProvider.favoriteIds.isNotEmpty)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  '${favoriteProvider.favoriteIds.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Bar - Fixed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) => setState(() => searchQuery = value),
                        decoration: const InputDecoration(
                          hintText: 'Cari bunga...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          setState(() => searchQuery = '');
                        },
                        child: const Icon(Icons.close, color: Colors.grey, size: 20),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Scrollable Content (Banner + Categories + Products)
            Expanded(
              child: filteredBouquets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('Produk tidak ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                          const SizedBox(height: 8),
                          Text('Coba cari dengan kata kunci lain', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // Banner (hanya tampil kalau tidak search)
                        if (searchQuery.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFFF8FAB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Big Sale', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 4),
                                          const Text('Get Up To 50% Off on\nall flowers this week!', style: TextStyle(fontSize: 12, color: Colors.white)),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                            child: const Text('Shop Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D))),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        if (searchQuery.isEmpty)
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),

                        // Category Chips (hanya tampil kalau tidak search)
                        if (searchQuery.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildCategoryChip('All'),
                                    _buildCategoryChip('Popular'),
                                    _buildCategoryChip('Recent'),
                                    _buildCategoryChip('Recommended'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),

                        // Products Grid
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final bouquet = filteredBouquets[index];
                                final isFavorite = favoriteProvider.isFavorite(bouquet.id);
                                return _buildProductCard(context, bouquet, isFavorite, favoriteProvider);
                              },
                              childCount: filteredBouquets.length,
                            ),
                          ),
                        ),
                        
                        // Bottom Padding
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Bouquet bouquet, bool isFavorite, FavoriteProvider favoriteProvider) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(bouquet: bouquet))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  child: Container(
                    width: double.infinity,
                    height: 130,
                    color: const Color(0xFFFFE8F0),
                    child: bouquet.images.isNotEmpty ? buildProductImage(bouquet.images[0]) : const Icon(Icons.image, color: Color(0xFFFF6B9D)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => favoriteProvider.toggleFavorite(bouquet.id),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: const Color(0xFFFF6B9D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bouquet.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bouquet.category,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            formatRupiah(bouquet.price),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFFF6B9D), shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ],
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

  Widget _buildCategoryChip(String label) {
    final isSelected = selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B9D) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ==================== FAVORITE PAGE ====================
class FavoritePage extends StatelessWidget {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    final bouquetProvider = Provider.of<BouquetProvider>(context);
    final favoriteBouquets = bouquetProvider.bouquets
        .where((b) => favoriteProvider.isFavorite(b.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Favorit Saya',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
      ),
      body: favoriteBouquets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE8F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: Color(0xFFFF6B9D),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Belum Ada Favorit',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tambahkan bunga favorit Anda di sini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: favoriteBouquets.length,
                itemBuilder: (context, index) {
                  final bouquet = favoriteBouquets[index];
                  final isFavorite = favoriteProvider.isFavorite(bouquet.id);
                  // Use the same _buildProductCard method from HomePage
                  return _buildFavoriteProductCard(context, bouquet, isFavorite, favoriteProvider);
                },
              ),
            ),
    );
  }

  Widget _buildFavoriteProductCard(BuildContext context, Bouquet bouquet, bool isFavorite, FavoriteProvider favoriteProvider) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(bouquet: bouquet))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  child: Container(
                    width: double.infinity,
                    height: 130,
                    color: const Color(0xFFFFE8F0),
                    child: bouquet.images.isNotEmpty ? buildProductImage(bouquet.images[0]) : const Icon(Icons.image, color: Color(0xFFFF6B9D)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => favoriteProvider.toggleFavorite(bouquet.id),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: const Color(0xFFFF6B9D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bouquet.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bouquet.category,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            formatRupiah(bouquet.price),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFFF6B9D), shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ],
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

// ==================== DETAIL PAGE ====================
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
    final cart = Provider.of<CartProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    cart.addItem(widget.bouquet, quantity);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.check_circle, color: Color(0xFFFF6B9D), size: 32), SizedBox(width: 12), Text('Order Placed!')]),
        content: const Text('Your order is being processed.\nThank you for shopping! 🌹'),
        actions: [
          TextButton(
            onPressed: () async {
              if (auth.user != null) {
                final service = FirebaseService();
                await service.placeOrder(auth.user!.uid, [CartItem(bouquet: widget.bouquet, quantity: quantity)], (widget.bouquet.price * quantity).toDouble());
              }
              cart.clear();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
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
                                      SnackBar(content: const Text('Added to cart!'), backgroundColor: const Color(0xFFFF6B9D), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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

// ==================== CART PAGE ====================
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Map<String, bool> selectedItems = {};

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    // Initialize selected items
    if (selectedItems.isEmpty && cart.items.isNotEmpty) {
      for (var item in cart.items) {
        selectedItems[item.bouquet.id] = true;
      }
    }

    // Check if all items are selected  ← TAMBAH DARI SINI
    final allSelected = cart.items.isNotEmpty && 
        cart.items.every((item) => selectedItems[item.bouquet.id] == true);
    // ← SAMPAI SINI

    // Calculate total selected items
    final selectedCount = selectedItems.values.where((v) => v).length;
    final selectedTotal = cart.items.fold<int>(0, (sum, item) {
      if (selectedItems[item.bouquet.id] == true) {
        return sum + (item.price * item.quantity);
      }
      return sum;
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: cart.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: const BoxDecoration(color: Color(0xFFFFE8F0), shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_cart_outlined, size: 80, color: Color(0xFFFF6B9D)),
                    ),
                    const SizedBox(height: 30),
                    const Text('Your Cart is Empty', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
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
                        backgroundColor: const Color(0xFFFF6B9D),
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
                        Row(  // ← UBAH JADI ROW
                          children: [
                            const Text('Cart', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFFFE8F0), borderRadius: BorderRadius.circular(20)),
                              child: Text('${cart.getTotalItems()} items', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D))),
                            ),
                          ],
                        ),
                        // ← TAMBAH DARI SINI: Select All Checkbox
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
                                  color: allSelected ? const Color(0xFFFF6B9D) : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFF6B9D), width: 2),
                                ),
                                child: allSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                              ),
                              const SizedBox(width: 8),
                              const Text('Pilih Semua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
                            ],
                          ),
                        ),
                        // ← SAMPAI SINI
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
                            border: isSelected ? Border.all(color: const Color(0xFFFF6B9D), width: 2) : null,
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
                                    color: isSelected ? const Color(0xFFFF6B9D) : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFF6B9D), width: 2),
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
                                  gradient: const LinearGradient(colors: [Color(0xFFFFE8F0), Color(0xFFFFF0F5)]),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: item.bouquet.images.isNotEmpty 
                                      ? buildProductImage(item.bouquet.images[0]) 
                                      : const Icon(Icons.image, color: Color(0xFFFF6B9D)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.bouquet.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(item.bouquet.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    const SizedBox(height: 6),
                                    Text(formatRupiah(item.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D))),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => cart.removeItem(item.bouquet.id)),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: const Color(0xFFFFF0F5), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF6B9D)),
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
                                          child: const Icon(Icons.remove, size: 14, color: Color(0xFFFF6B9D)),
                                        ),
                                        Container(width: 20, alignment: Alignment.center, child: Text('${item.quantity}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                        GestureDetector(
                                          onTap: () => setState(() => cart.updateQuantity(item.bouquet.id, item.quantity + 1)),
                                          child: const Icon(Icons.add, size: 14, color: Color(0xFFFF6B9D)),
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
                            Text('Selected ($selectedCount)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                            Text(formatRupiah(selectedTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: selectedCount == 0 ? null : () {
                              // Filter hanya item yang selected
                              final selectedItems = cart.items.where((item) => this.selectedItems[item.bouquet.id] == true).toList();
                              final total = selectedItems.fold<int>(0, (sum, item) => sum + (item.price * item.quantity));

                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Row(children: [Icon(Icons.check_circle, color: Color(0xFFFF6B9D), size: 32), SizedBox(width: 12), Text('Order Placed!')]),
                                  content: Text('${selectedCount} produk akan di-order.\nTotal: ${formatRupiah(total)}\n\nTerima kasih telah berbelanja! 🌹'),
                                  actions: [
                                    TextButton(
                                      onPressed: () async {
                                        if (auth.user != null) {
                                          final service = FirebaseService();
                                          await service.placeOrder(auth.user!.uid, selectedItems, total.toDouble());
                                        }
                                        
                                        // Remove selected items dari cart
                                        for (var item in selectedItems) {
                                          cart.removeItem(item.bouquet.id);
                                        }
                                        
                                        Navigator.popUntil(context, (route) => route.isFirst);
                                      },
                                      child: const
                                      Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedCount == 0 ? Colors.grey : const Color(0xFFFF6B9D),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text(
                              selectedCount == 0 ? 'Pilih Produk Terlebih Dahulu' : 'Pay Now (${selectedCount})',
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

// ==================== ACTIVITY PAGE (BUYER) ====================
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> with SingleTickerProviderStateMixin {
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
    final auth = Provider.of<AuthProvider>(context);
    final service = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Aktivitas Pesanan', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        bottom: auth.user == null
            ? null
            : PreferredSize(
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
      body: auth.user == null
          ? const Center(child: Text('Please login to view orders'))
          : StreamBuilder<List<Order>>(
              stream: service.getUserOrders(auth.user!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFFF6B9D)),
                        SizedBox(height: 16),
                        Text('Memuat pesanan...'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 80, color: Color(0xFFFF6B9D)),
                        const SizedBox(height: 16),
                        const Text('Terjadi kesalahan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final allOrders = snapshot.data ?? [];
                
                // Kategorikan pesanan berdasarkan status
                final placedOrders = allOrders.where((o) => o.status == 'placed').toList();
                final processingOrders = allOrders.where((o) => o.status == 'processing').toList();
                final shippedOrders = allOrders.where((o) => o.status == 'shipped').toList();
                final completedOrders = allOrders.where((o) => o.status == 'completed').toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Semua
                    _buildOrdersList(allOrders, 'Belum Ada Pesanan'),
                    // Diproses
                    _buildOrdersList(placedOrders, 'Tidak ada pesanan yang diproses'),
                    // Dikemas
                    _buildOrdersList(processingOrders, 'Tidak ada pesanan yang dikemas'),
                    // Dikirim
                    _buildOrdersList(shippedOrders, 'Tidak ada pesanan yang dikirim'),
                    // Selesai
                    _buildOrdersList(completedOrders, 'Tidak ada pesanan yang selesai'),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildOrdersList(List<Order> orders, String emptyMessage) {
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
          final statusColor = getStatusColor(order.status);
          final statusTextColor = getStatusTextColor(order.status);
          final statusLabel = getStatusLabel(order.status);

          return Container(
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
                            '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Item Pesanan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['name']} × ${item['qty']}',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatRupiah(item['price'] * item['qty']),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                    Text(
                      formatRupiah(order.total.toInt()),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== SELLER PRODUCTS PAGE ====================
class SellerProductsPage extends StatefulWidget {
  const SellerProductsPage({super.key});

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bouquets = Provider.of<BouquetProvider>(context).bouquets;
    
    // Tampilkan produk seller + produk admin (hardcode)
    final sellerProducts = bouquets.where((b) => 
      b.sellerId == auth.user?.uid || b.sellerId == 'admin'
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Produk Saya', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(context, auth.user!.uid),
        backgroundColor: const Color(0xFFFF6B9D),
        child: const Icon(Icons.add),
      ),
      body: sellerProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: const BoxDecoration(color: Color(0xFFFFE8F0), shape: BoxShape.circle),
                    child: const Icon(Icons.store_rounded, size: 80, color: Color(0xFFFF6B9D)),
                  ),
                  const SizedBox(height: 30),
                  const Text('Belum Ada Produk', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                  const SizedBox(height: 12),
                  Text('Mulai tambah produk bunga Anda', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: sellerProducts.length,
              itemBuilder: (context, index) {
                final product = sellerProducts[index];
                final isAdminProduct = product.sellerId == 'admin';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                    border: isAdminProduct ? Border.all(color: Colors.orange, width: 1) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFFFE8F0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: product.images.isNotEmpty 
                              ? buildProductImage(product.images[0])
                              : const Icon(Icons.image, color: Color(0xFFFF6B9D)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                if (isAdminProduct)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Sample', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(formatRupiah(product.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D))),
                            const SizedBox(height: 4),
                            Text(product.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showEditProductDialog(context, product),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFFFE8F0), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.edit, size: 18, color: Color(0xFFFF6B9D)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showDeleteProductDialog(context, product.id),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.delete, size: 18, color: Colors.red.shade600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAddProductDialog(BuildContext context, String sellerId) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController();
    final detailsController = TextEditingController();
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tambah Produk Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    setState(() => selectedImage = image);
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF6B9D), width: 2, style: BorderStyle.solid),
                    ),
                    child: selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate, size: 40, color: Color(0xFFFF6B9D)),
                              SizedBox(height: 8),
                              Text('Pilih Gambar', style: TextStyle(fontSize: 12, color: Color(0xFFFF6B9D))),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(selectedImage!.path), fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Produk',
                    prefixIcon: const Icon(Icons.local_florist, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi Singkat',
                    prefixIcon: const Icon(Icons.description, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Harga (Rp)',
                    prefixIcon: const Icon(Icons.money, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: const Icon(Icons.category, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Detail Produk',
                    prefixIcon: const Icon(Icons.note, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama dan Harga tidak boleh kosong'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (selectedImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pilih gambar terlebih dahulu'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  final bytes = await selectedImage!.readAsBytes();
                  final imageBase64 = base64Encode(bytes);

                  final newBouquet = Bouquet(
                    id: '',
                    name: nameController.text,
                    description: descriptionController.text,
                    price: int.parse(priceController.text),
                    images: [imageBase64],
                    category: categoryController.text.isNotEmpty ? categoryController.text : 'Bunga',
                    details: detailsController.text,
                    sellerId: sellerId,
                  );

                  final service = FirebaseService();
                  await service.addBouquet(newBouquet);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Produk berhasil ditambahkan!'), backgroundColor: Color(0xFFFF6B9D)),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B9D)),
              child: const Text('Tambahkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Bouquet product) {
    final nameController = TextEditingController(text: product.name);
    final descriptionController = TextEditingController(text: product.description);
    final priceController = TextEditingController(text: product.price.toString());
    final categoryController = TextEditingController(text: product.category);
    final detailsController = TextEditingController(text: product.details);
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Produk'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    setState(() => selectedImage = image);
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF6B9D), width: 2),
                    ),
                    child: selectedImage == null
                        ? product.images.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: buildProductImage(product.images[0]),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_photo_alternate, size: 40, color: Color(0xFFFF6B9D)),
                                  SizedBox(height: 8),
                                  Text('Ubah Gambar', style: TextStyle(fontSize: 12, color: Color(0xFFFF6B9D))),
                                ],
                              )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(selectedImage!.path), fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Produk',
                    prefixIcon: const Icon(Icons.local_florist, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi Singkat',
                    prefixIcon: const Icon(Icons.description, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Harga (Rp)',
                    prefixIcon: const Icon(Icons.money, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: const Icon(Icons.category, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Detail Produk',
                    prefixIcon: const Icon(Icons.note, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama dan Harga tidak boleh kosong'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  List<String> images = product.images;

                  if (selectedImage != null) {
                    final bytes = await selectedImage!.readAsBytes();
                    final imageBase64 = base64Encode(bytes);
                    images = [imageBase64];
                  }

                  final updatedBouquet = Bouquet(
                    id: product.id,
                    name: nameController.text,
                    description: descriptionController.text,
                    price: int.parse(priceController.text),
                    images: images,
                    category: categoryController.text.isNotEmpty ? categoryController.text : 'Bunga',
                    details: detailsController.text,
                    sellerId: product.sellerId,
                  );

                  final service = FirebaseService();
                  await service.updateBouquet(product.id, updatedBouquet);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Produk berhasil diperbarui!'), backgroundColor: Color(0xFFFF6B9D)),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B9D)),
              child: const Text('Perbarui', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteProductDialog(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Produk?'),
        content: const Text('Yakin ingin menghapus produk ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final service = FirebaseService();
                await service.deleteBouquet(productId);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Produk berhasil dihapus!'), backgroundColor: Color(0xFFFF6B9D)),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ==================== SELLER ORDERS PAGE ====================
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

            // Kategorikan pesanan berdasarkan status
            final placedOrders = allOrders.where((o) => o.status == 'placed').toList();
            final processingOrders = allOrders.where((o) => o.status == 'processing').toList();
            final shippedOrders = allOrders.where((o) => o.status == 'shipped').toList();
            final completedOrders = allOrders.where((o) => o.status == 'completed').toList();

            return TabBarView(
              controller: _tabController,
              children: [
                // Semua
                _buildSellerOrdersList(allOrders, 'Belum Ada Pesanan'),
                // Diproses
                _buildSellerOrdersList(placedOrders, 'Tidak ada pesanan yang diproses'),
                // Dikemas
                _buildSellerOrdersList(processingOrders, 'Tidak ada pesanan yang dikemas'),
                // Dikirim
                _buildSellerOrdersList(shippedOrders, 'Tidak ada pesanan yang dikirim'),
                // Selesai
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
          final statusColor = getStatusColor(order.status);
          final statusTextColor = getStatusTextColor(order.status);
          final statusLabel = getStatusLabel(order.status);

          return Container(
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
                      onTap: () => _showChangeStatusDialog(context, order),
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
          );
        },
      ),
    );
  }

  void _showChangeStatusDialog(BuildContext context, Order order) {
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

// ==================== SELLER ANALYTICS PAGE ====================
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

          // Calculate analytics
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
                // KPI Cards
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

                // Order Status Breakdown
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

                // Recent Orders
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

// ==================== PROFILE PAGE ====================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: Color(0xFF831843), fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Header
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFDB2777), Color(0xFFF472B6)],
                    ),
                  ),
                  child: const Center(child: Text('👤', style: TextStyle(fontSize: 60))),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B9D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(auth.user?.displayName ?? 'User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
            const SizedBox(height: 4),
            Text(auth.user?.email ?? 'email@example.com', style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE7F3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                auth.role.isNotEmpty ? auth.role[0].toUpperCase() + auth.role.substring(1) : 'User',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDB2777)),
              ),
            ),
            const SizedBox(height: 32),

            // Edit Profile Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showEditProfileDialog(context, auth),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B9D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Menu Items
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.location_on,
                    title: 'Alamat',
                    subtitle: 'Kelola alamat pengiriman',
                    onTap: () => _showAddressDialog(context),
                  ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.payment,
                    title: 'Metode Pembayaran',
                    subtitle: 'Kelola metode pembayaran',
                    onTap: () => _showPaymentDialog(context),
                  ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.security,
                    title: 'Keamanan',
                    subtitle: 'Ubah password dan keamanan',
                    onTap: () => _showSecurityDialog(context),
                  ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.notifications,
                    title: 'Notifikasi',
                    subtitle: 'Atur pengaturan notifikasi',
                    onTap: () => _showNotificationSettings(context),
                  ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.help_outline,
                    title: 'Bantuan',
                    subtitle: 'Hubungi customer service',
                    onTap: () => _showHelpDialog(context),
                  ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.info_outline,
                    title: 'Tentang Kami',
                    subtitle: 'Informasi tentang aplikasi',
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(context, auth),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFDB2777), size: 24),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.user?.displayName ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: const Icon(Icons.person, color: Color(0xFFDB2777)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE7F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email, color: Color(0xFFDB2777), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Email', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(auth.user?.email ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Email tidak dapat diubah untuk keamanan', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama tidak boleh kosong'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await auth.user?.updateDisplayName(nameController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil berhasil diperbarui!'), backgroundColor: Color(0xFFDB2777)),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB2777)),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddressDialog(BuildContext context) {
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final postalCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tambah Alamat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alamat Lengkap',
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFFDB2777)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: InputDecoration(
                  labelText: 'Kota/Kabupaten',
                  prefixIcon: const Icon(Icons.location_city, color: Color(0xFFDB2777)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: postalCodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Kode Pos',
                  prefixIcon: const Icon(Icons.mail, color: Color(0xFFDB2777)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (addressController.text.isEmpty || cityController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua field harus diisi'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alamat berhasil disimpan!'), backgroundColor: Color(0xFFDB2777)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB2777)),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Metode Pembayaran'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPaymentOption('Credit Card', 'Visa, Mastercard, Amex'),
              const SizedBox(height: 12),
              _buildPaymentOption('Bank Transfer', 'Transfer ke rekening kami'),
              const SizedBox(height: 12),
              _buildPaymentOption('E-Wallet', 'GCash, OVO, DANA, dll'),
              const SizedBox(height: 12),
              _buildPaymentOption('COD', 'Bayar saat barang tiba'),
            ],
          ),
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

  Widget _buildPaymentOption(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE7F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDB2777), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFDB2777), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureNewPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ubah Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password Saat Ini',
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFDB2777)),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFDB2777)),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscureNewPassword = !obscureNewPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFDB2777)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.isEmpty || newPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Semua field harus diisi'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password baru tidak cocok'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password berhasil diubah!'), backgroundColor: Color(0xFFDB2777)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB2777)),
              child: const Text('Ubah', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    bool emailNotif = true;
    bool smsNotif = true;
    bool pushNotif = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Pengaturan Notifikasi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Email Notification'),
                  subtitle: const Text('Terima notifikasi via email'),
                  value: emailNotif,
                  onChanged: (value) => setState(() => emailNotif = value),
                  activeColor: const Color(0xFFDB2777),
                ),
                SwitchListTile(
                  title: const Text('SMS Notification'),
                  subtitle: const Text('Terima notifikasi via SMS'),
                  value: smsNotif,
                  onChanged: (value) => setState(() => smsNotif = value),
                  activeColor: const Color(0xFFDB2777),
                ),
                SwitchListTile(
                  title: const Text('Push Notification'),
                  subtitle: const Text('Terima notifikasi push app'),
                  value: pushNotif,
                  onChanged: (value) => setState(() => pushNotif = value),
                  activeColor: const Color(0xFFDB2777),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bantuan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hubungi Kami:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              const Text('📧 Email: support@tokobunga.com', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              const Text('📞 WhatsApp: +62 812-3456-7890', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              const Text('⏰ Jam Operasional: 09:00 - 17:00 WIB', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              const Text('FAQ Umum:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              const Text('• Berapa lama pengiriman?\nPengiriman 1-3 hari kerja', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              const Text('• Bagaimana jika barang rusak?\nHubungi CS kami untuk penggantian', style: TextStyle(fontSize: 12)),
            ],
          ),
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

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tentang Kami'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Toko Bunga Cantik', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFDB2777))),
              const SizedBox(height: 8),
              const Text('Versi: 1.0.0', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              const Text('Kami adalah aplikasi toko bunga online yang menyediakan rangkaian bunga segar berkualitas tinggi untuk berbagai acara spesial Anda.', style: TextStyle(fontSize: 13, height: 1.6)),
              const SizedBox(height: 16),
              const Text('Fitur:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('✓ Bunga segar pilihan\n✓ Pengiriman cepat\n✓ Cicilan 0%\n✓ Garansi kepuasan', style: TextStyle(fontSize: 12, height: 1.8)),
              const SizedBox(height: 16),
              const Text('© 2025 Toko Bunga Cantik. All rights reserved.', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
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

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar?'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              auth.signOut();
              Navigator.pop(context);
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}