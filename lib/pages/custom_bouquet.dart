import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../utils/helpers.dart';

class CustomBouquetPage extends StatefulWidget {
  const CustomBouquetPage({super.key});

  @override
  State<CustomBouquetPage> createState() => _CustomBouquetPageState();
}

class _CustomBouquetPageState extends State<CustomBouquetPage> {
  double budget = 100000;
  String selectedFlowerType = 'Roses';
  String selectedColor = 'Red';
  String selectedSize = 'Medium';
  int estimatedDays = 2;
  String additionalNotes = '';
  final TextEditingController _notesController = TextEditingController();

  final List<String> flowerTypes = ['Roses', 'Tulips', 'Sunflowers', 'Lilies', 'Orchids', 'Mixed'];
  final List<String> colors = ['Red', 'Pink', 'White', 'Yellow', 'Purple', 'Mixed'];
  final List<String> sizes = ['Small', 'Medium', 'Large', 'Extra Large'];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int _calculateEstimatedDays() {
    if (budget < 150000) return 1;
    if (budget < 300000) return 2;
    if (budget < 500000) return 3;
    return 4;
  }

  Future<void> _sendCustomOrder() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userName = auth.user?.displayName ?? 'Customer';
    
    final phone = '6281234567890'; // Ganti dengan nomor admin
    final message = Uri.encodeComponent(
      '🌹 *CUSTOM BOUQUET ORDER* 🌹\n\n'
      'Nama: $userName\n'
      'Budget: ${formatRupiah(budget.toInt())}\n\n'
      '📦 *Detail Pesanan:*\n'
      '• Jenis Bunga: $selectedFlowerType\n'
      '• Warna: $selectedColor\n'
      '• Ukuran: $selectedSize\n'
      '• Estimasi Pengerjaan: $estimatedDays hari\n\n'
      '📝 *Catatan Tambahan:*\n${additionalNotes.isEmpty ? "Tidak ada" : additionalNotes}\n\n'
      'Mohon konfirmasi ketersediaan dan harga final. Terima kasih! 🙏'
    );
    
    final url = 'https://wa.me/$phone?text=$message';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    estimatedDays = _calculateEstimatedDays();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Custom Bouquet', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8FAB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '🌹',
                    style: TextStyle(fontSize: 60),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Buat Buket Impian Anda',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sesuaikan dengan budget dan preferensi Anda',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Budget Slider
                  Container(
                    padding: const EdgeInsets.all(20),
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
                            const Text('Budget Anda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE8F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                formatRupiah(budget.toInt()),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFFF6B9D),
                            inactiveTrackColor: const Color(0xFFFFE8F0),
                            thumbColor: const Color(0xFFFF6B9D),
                            overlayColor: const Color(0xFFFF6B9D).withOpacity(0.2),
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                          ),
                          child: Slider(
                            value: budget,
                            min: 50000,
                            max: 1000000,
                            divisions: 19,
                            onChanged: (value) => setState(() => budget = value),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Rp 50K', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Text('Rp 1Jt', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Estimasi Pengerjaan
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF6B9D), width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B9D),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.access_time, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estimasi Pengerjaan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                '$estimatedDays hari kerja',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF6B9D)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Flower Type
                  _buildSectionTitle('Jenis Bunga'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: flowerTypes.map((type) => _buildChip(type, selectedFlowerType, (value) => setState(() => selectedFlowerType = value))).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Color
                  _buildSectionTitle('Warna'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colors.map((color) => _buildChip(color, selectedColor, (value) => setState(() => selectedColor = value))).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Size
                  _buildSectionTitle('Ukuran'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: sizes.map((size) => _buildChip(size, selectedSize, (value) => setState(() => selectedSize = value))).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Additional Notes
                  _buildSectionTitle('Catatan Tambahan (Opsional)'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: TextField(
                      controller: _notesController,
                      onChanged: (value) => additionalNotes = value,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Untuk ulang tahun, tolong tambahkan pita warna gold...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Order Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sendCustomOrder,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text('Kirim Pesanan via WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B9D),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pesanan custom akan dikonfirmasi melalui WhatsApp. Harga final bisa berbeda tergantung ketersediaan bahan.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
    );
  }

  Widget _buildChip(String label, String selectedValue, Function(String) onSelected) {
    final isSelected = label == selectedValue;
    return GestureDetector(
      onTap: () => onSelected(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B9D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFFF6B9D) : Colors.grey.shade300, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFF6B9D).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}