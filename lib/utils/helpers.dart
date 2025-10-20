import 'package:flutter/material.dart';
import 'constants.dart';

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

String getInitials(String name) {
  if (name.isEmpty) return 'U';
  final names = name.split(' ');
  if (names.length == 1) return names[0][0].toUpperCase();
  return '${names[0][0]}${names[1][0]}'.toUpperCase();
}