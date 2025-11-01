import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class AddressManagementPage extends StatefulWidget {
  const AddressManagementPage({super.key});

  @override
  State<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends State<AddressManagementPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Kelola Alamat', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressDialog(context, auth.user!.uid),
        backgroundColor: const Color(0xFFFF6B9D),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Alamat'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .doc(auth.user!.uid)
            .collection('addresses')
            .orderBy('isDefault', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B9D)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: const BoxDecoration(color: Color(0xFFFFE8F0), shape: BoxShape.circle),
                    child: const Icon(Icons.location_off, size: 80, color: Color(0xFFFF6B9D)),
                  ),
                  const SizedBox(height: 30),
                  const Text('Belum Ada Alamat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Tambahkan alamat pengiriman Anda', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final addresses = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index].data() as Map<String, dynamic>;
              final addressId = addresses[index].id;
              final isDefault = address['isDefault'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isDefault ? Border.all(color: const Color(0xFFFF6B9D), width: 2) : null,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                address['label'] ?? 'Alamat',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B9D),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Utama', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Color(0xFF2D3142)),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                            if (!isDefault)
                              const PopupMenuItem(value: 'default', child: Row(children: [Icon(Icons.check_circle, size: 20), SizedBox(width: 8), Text('Jadikan Utama')])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditAddressDialog(context, auth.user!.uid, addressId, address);
                            } else if (value == 'default') {
                              _setDefaultAddress(auth.user!.uid, addressId);
                            } else if (value == 'delete') {
                              _deleteAddress(auth.user!.uid, addressId);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(address['receiverName'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(address['phone'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Text(
                      address['fullAddress'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                    ),
                    if (address['city']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text('${address['city']}, ${address['postalCode'] ?? ''}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddAddressDialog(BuildContext context, String userId) {
    final labelController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final postalCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tambah Alamat Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: 'Label (Rumah, Kantor, dll)',
                  prefixIcon: const Icon(Icons.label, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Penerima',
                  prefixIcon: const Icon(Icons.person, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor Telepon',
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alamat Lengkap',
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: InputDecoration(
                  labelText: 'Kota',
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (labelController.text.isEmpty || addressController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Label dan alamat wajib diisi'), backgroundColor: Colors.red),
                );
                return;
              }

              // Check if this is the first address
              final existingAddresses = await _db.collection('users').doc(userId).collection('addresses').get();
              final isFirstAddress = existingAddresses.docs.isEmpty;

              await _db.collection('users').doc(userId).collection('addresses').add({
                'label': labelController.text,
                'receiverName': nameController.text,
                'phone': phoneController.text,
                'fullAddress': addressController.text,
                'city': cityController.text,
                'postalCode': postalCodeController.text,
                'isDefault': isFirstAddress,
                'createdAt': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alamat berhasil ditambahkan!'), backgroundColor: Color(0xFFFF6B9D)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B9D)),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(BuildContext context, String userId, String addressId, Map<String, dynamic> address) {
    final labelController = TextEditingController(text: address['label']);
    final nameController = TextEditingController(text: address['receiverName']);
    final phoneController = TextEditingController(text: address['phone']);
    final addressController = TextEditingController(text: address['fullAddress']);
    final cityController = TextEditingController(text: address['city']);
    final postalCodeController = TextEditingController(text: address['postalCode']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Alamat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: 'Label',
                  prefixIcon: const Icon(Icons.label, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Penerima',
                  prefixIcon: const Icon(Icons.person, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor Telepon',
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alamat Lengkap',
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFFFF6B9D)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: InputDecoration(
                  labelText: 'Kota',
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('users').doc(userId).collection('addresses').doc(addressId).update({
                'label': labelController.text,
                'receiverName': nameController.text,
                'phone': phoneController.text,
                'fullAddress': addressController.text,
                'city': cityController.text,
                'postalCode': postalCodeController.text,
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alamat berhasil diperbarui!'), backgroundColor: Color(0xFFFF6B9D)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B9D)),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _setDefaultAddress(String userId, String addressId) async {
    // Reset all addresses to non-default
    final addresses = await _db.collection('users').doc(userId).collection('addresses').get();
    for (var doc in addresses.docs) {
      await doc.reference.update({'isDefault': false});
    }

    // Set selected address as default
    await _db.collection('users').doc(userId).collection('addresses').doc(addressId).update({'isDefault': true});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alamat utama berhasil diubah!'), backgroundColor: Color(0xFFFF6B9D)),
    );
  }

  Future<void> _deleteAddress(String userId, String addressId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Alamat?'),
        content: const Text('Apakah Anda yakin ingin menghapus alamat ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await _db.collection('users').doc(userId).collection('addresses').doc(addressId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alamat berhasil dihapus!'), backgroundColor: Color(0xFFFF6B9D)),
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}