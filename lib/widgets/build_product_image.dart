import 'package:flutter/material.dart';
import 'dart:convert';

import '../utils/constants.dart';

Widget buildProductImage(String imageData, {BoxFit fit = BoxFit.cover}) {
  if (imageData.isEmpty) {
    return Container(
      color: AppColors.accentPink,
      child: const Icon(Icons.image, color: AppColors.primary),
    );
  }

  if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
    return Image.network(
      imageData,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.accentPink,
          child: const Icon(Icons.error, color: AppColors.primary),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: AppColors.accentPink,
          child: const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: AppColors.primary,
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
            color: AppColors.accentPink,
            child: const Icon(Icons.error, color: AppColors.primary),
          );
        },
      );
    } catch (e) {
      debugPrint('Error decoding Base64: $e');
      return Container(
        color: AppColors.accentPink,
        child: const Icon(Icons.broken_image, color: AppColors.primary),
      );
    }
  }
}