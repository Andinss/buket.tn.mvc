import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'models/bouquet.dart';
import 'models/cart_item.dart';
import 'models/order.dart';
import 'services/firebase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/bouquet_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/favorite_provider.dart';
import 'pages/login_page.dart';
import 'pages/main_navigation.dart';

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
          Provider.of<FavoriteProvider>(context, listen: false).setUser(auth.user?.uid);
          return const MainNavigation();
        },
      ),
    );
  }
}