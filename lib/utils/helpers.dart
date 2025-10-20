import 'dart:convert';

import 'package:flutter/material.dart';

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