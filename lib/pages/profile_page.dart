import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'main_navigation.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _navigateToPage(BuildContext context, int index) {
    // Navigate to specific page using Navigator
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isSeller = auth.role == 'seller';
    
    String displayName = auth.user?.displayName ?? 'User';
    if (displayName == 'User' && auth.user?.email != null) {
      displayName = auth.user!.email!.split('@').first;
    }

    String fullAddress = '';
    if (auth.address.isNotEmpty) {
      fullAddress = auth.address;
      if (auth.city.isNotEmpty) {
        fullAddress += ', ${auth.city}';
      }
      if (auth.postalCode.isNotEmpty) {
        fullAddress += ', ${auth.postalCode}';
      }
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isSeller ? 'Profile Seller' : 'Profile',
          style: const TextStyle(color: Color(0xFF831843), fontWeight: FontWeight.bold, fontSize: 20)
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                  child: Center(
                    child: Text(
                      isSeller ? '🏪' : '👤',
                      style: const TextStyle(fontSize: 60)
                    ),
                  ),
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
                    child: Icon(
                      isSeller ? Icons.store : Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
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
                isSeller ? 'Seller' : 'Buyer',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDB2777),
                ),
              ),
            ),
            const SizedBox(height: 32),

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

            if (isSeller) ...[
              _buildSectionHeader('Menu Toko'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    _buildMenuTile(
                      icon: Icons.store_rounded,
                      title: 'Kelola Produk',
                      subtitle: 'Tambah, edit, dan hapus produk',
                      onTap: () => _navigateToPage(context, 0),
                      color: const Color(0xFFFF6B9D),
                    ),
                    const Divider(height: 1),
                    _buildMenuTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Pesanan Masuk',
                      subtitle: 'Lihat dan kelola pesanan',
                      onTap: () => _navigateToPage(context, 1),
                      color: const Color(0xFFFF6B9D),
                    ),
                    const Divider(height: 1),
                    _buildMenuTile(
                      icon: Icons.analytics_rounded,
                      title: 'Analytics & Laporan',
                      subtitle: 'Lihat statistik penjualan',
                      onTap: () => _navigateToPage(context, 2),
                      color: const Color(0xFFFF6B9D),
                    ),
                    const Divider(height: 1),
                    _buildMenuTile(
                      icon: Icons.business_center_rounded,
                      title: 'Informasi Toko',
                      subtitle: 'Kelola profil toko Anda',
                      onTap: () => _showStoreInfoDialog(context, auth),
                      color: const Color(0xFFFF6B9D),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            _buildSectionHeader(isSeller ? 'Pengaturan Akun' : 'Pengaturan'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.phone,
                    title: 'Nomor Telepon',
                    subtitle: auth.phoneNumber.isEmpty ? 'Tambahkan nomor telepon' : auth.phoneNumber,
                    onTap: () => _showPhoneDialog(context, auth),
                    color: const Color(0xFFDB2777),
                  ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.location_on,
                    title: 'Alamat',
                    subtitle: fullAddress.isEmpty ? 'Kelola alamat pengiriman' : fullAddress,
                    onTap: () => _showAddressDialog(context, auth),
                    color: const Color(0xFFDB2777),
                  ),
                  if (!isSeller) const Divider(height: 1),
                  if (!isSeller)
                    _buildMenuTile(
                      icon: Icons.payment,
                      title: 'Metode Pembayaran',
                      subtitle: auth.paymentMethod.isEmpty ? 'Kelola metode pembayaran' : auth.paymentMethod,
                      onTap: () => _showPaymentDialog(context, auth),
                      color: const Color(0xFFDB2777),
                    ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.security,
                    title: 'Keamanan',
                    subtitle: 'Ubah password dan keamanan',
                    onTap: () => _showSecurityDialog(context),
                    color: const Color(0xFFDB2777),
                  ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.notifications,
                    title: 'Notifikasi',
                    subtitle: 'Atur pengaturan notifikasi',
                    onTap: () => _showNotificationSettings(context),
                    color: const Color(0xFFDB2777),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.help_outline,
                    title: 'Bantuan & Dukungan',
                    subtitle: 'Hubungi customer service',
                    onTap: () => _showHelpDialog(context),
                    color: const Color(0xFFDB2777),
                  ),
                  const Divider(height: 1),
                  _buildMenuTile(
                    icon: Icons.info_outline,
                    title: 'Tentang Kami',
                    subtitle: 'Informasi tentang aplikasi',
                    onTap: () => _showAboutDialog(context),
                    color: const Color(0xFFDB2777),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3142),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
      subtitle: Text(subtitle, 
        style: const TextStyle(fontSize: 12, color: Colors.grey),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _showStoreInfoDialog(BuildContext context, AuthProvider auth) {
    final storeNameController = TextEditingController(text: auth.user?.displayName ?? '');
    final storeDescController = TextEditingController();
    final storeAddressController = TextEditingController(text: auth.address);
    final storePhoneController = TextEditingController(text: auth.phoneNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.store_rounded, color: Color(0xFFFF6B9D)),
            SizedBox(width: 8),
            Text('Informasi Toko', style: TextStyle(color: Color(0xFFDB2777))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF6B9D), width: 2),
                ),
                child: const Icon(Icons.store_rounded, size: 40, color: Color(0xFFFF6B9D)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: storeNameController,
                decoration: InputDecoration(
                  labelText: 'Nama Toko',
                  prefixIcon: const Icon(Icons.business_rounded, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storeDescController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Toko',
                  hintText: 'Deskripsikan toko Anda...',
                  prefixIcon: const Icon(Icons.description_rounded, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storeAddressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Alamat Toko',
                  prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storePhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telepon Toko',
                  prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Informasi toko akan ditampilkan kepada pembeli',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await auth.updateProfile(
                  storeNameController.text,
                  storePhoneController.text,
                  storeAddressController.text,
                  auth.city,
                  auth.postalCode,
                  auth.paymentMethod
                );
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informasi toko berhasil diperbarui!'),
                    backgroundColor: Color(0xFFFF6B9D),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B9D)),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPhoneDialog(BuildContext context, AuthProvider auth) {
    final phoneController = TextEditingController(text: auth.phoneNumber);
    final isSeller = auth.role == 'seller';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isSeller ? 'Telepon Toko' : 'Nomor Telepon',
          style: const TextStyle(color: Color(0xFFDB2777)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Nomor Telepon',
                hintText: 'Contoh: 081234567890',
                prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF6B9D)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Text(
              isSeller 
                  ? 'Nomor telepon toko akan ditampilkan kepada pembeli'
                  : 'Nomor telepon akan digunakan untuk konfirmasi pesanan',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nomor telepon tidak boleh kosong'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await auth.updateProfile(
                  auth.user?.displayName ?? 'User',
                  phoneController.text,
                  auth.address,
                  auth.city,
                  auth.postalCode,
                  auth.paymentMethod
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isSeller ? 'Telepon toko berhasil diperbarui!' : 'Nomor telepon berhasil diperbarui!'),
                    backgroundColor: const Color(0xFFFF6B9D),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D)
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

    void _showAddressDialog(BuildContext context, AuthProvider auth) {
      final addressController = TextEditingController(text: auth.address);
      final cityController = TextEditingController(text: auth.city);
      final postalCodeController = TextEditingController(text: auth.postalCode);
      final isSeller = auth.role == 'seller';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isSeller ? 'Alamat Toko' : 'Alamat Pengiriman',
            style: const TextStyle(color: Color(0xFFDB2777)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Alamat Lengkap',
                    hintText: 'Masukkan alamat lengkap',
                    prefixIcon: const Icon(Icons.location_on, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: InputDecoration(
                    labelText: 'Kota/Kabupaten',
                    prefixIcon: const Icon(Icons.location_city, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: postalCodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Kode Pos',
                    prefixIcon: const Icon(Icons.markunread_mailbox, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (addressController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alamat tidak boleh kosong'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  await auth.updateProfile(
                    auth.user?.displayName ?? 'User',
                    auth.phoneNumber,
                    addressController.text,
                    cityController.text,
                    postalCodeController.text,
                    auth.paymentMethod
                  );
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isSeller ? 'Alamat toko berhasil diperbarui!' : 'Alamat berhasil diperbarui!'),
                      backgroundColor: const Color(0xFFFF6B9D),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B9D)
              ),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    void _showPaymentDialog(BuildContext context, AuthProvider auth) {
      String selectedMethod = auth.paymentMethod.isNotEmpty ? 
          (auth.paymentMethod == 'Credit Card' ? 'Transfer Bank' : auth.paymentMethod) 
          : 'Transfer Bank';
      final List<String> paymentMethods = [
        'Transfer Bank',
        'E-Wallet',
        'Bayar di Tempat (COD)'
      ];

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Metode Pembayaran', style: TextStyle(color: Color(0xFFDB2777))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...paymentMethods.map((method) => RadioListTile<String>(
                    title: Text(method),
                    value: method,
                    groupValue: selectedMethod,
                    onChanged: (value) => setState(() => selectedMethod = value!),
                    activeColor: const Color(0xFFFF6B9D),
                  )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await auth.updateProfile(
                        auth.user?.displayName ?? 'User',
                        auth.phoneNumber,
                        auth.address,
                        auth.city,
                        auth.postalCode,
                        selectedMethod
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Metode pembayaran berhasil diperbarui!'), backgroundColor: Color(0xFFFF6B9D)),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B9D)),
                  child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      );
    }

    void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
      final nameController = TextEditingController(text: auth.user?.displayName ?? '');
      final isSeller = auth.role == 'seller';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isSeller ? 'Edit Profil Toko' : 'Edit Profile',
            style: const TextStyle(color: Color(0xFFDB2777)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama',
                    prefixIcon: const Icon(Icons.person, color: Color(0xFFFF6B9D)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  controller: TextEditingController(text: auth.user?.email ?? ''),
                ),
                if (isSeller) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Untuk mengubah informasi toko lainnya, gunakan menu "Informasi Toko"',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
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
                  await auth.updateProfile(
                    nameController.text,
                    auth.phoneNumber,
                    auth.address,
                    auth.city,
                    auth.postalCode,
                    auth.paymentMethod
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isSeller ? 'Profil toko berhasil diperbarui!' : 'Profile berhasil diperbarui!'),
                      backgroundColor: const Color(0xFFFF6B9D),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B9D)
              ),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
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