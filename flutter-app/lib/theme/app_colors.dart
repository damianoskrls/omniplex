import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0F0F12);
  static const surface = Color(0xFF1A1A22);
  static const surfaceLight = Color(0xFF242430);
  static const border = Color(0xFF2E2E3A);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9CA3AF);
  static const lime = Color(0xFFB8F55E);
  static const purple = Color(0xFF7C5CFC);
  static const orange = Color(0xFFFF8A4C);
  static const teal = Color(0xFF4FD1C5);
  static const pink = Color(0xFFFF6B9D);

  static const cardGradients = [
    [Color(0xFF5B4FCF), Color(0xFF7C5CFC)],
    [Color(0xFFE86A3A), Color(0xFFFF8A4C)],
    [Color(0xFF2A9D8F), Color(0xFF4FD1C5)],
    [Color(0xFFD63384), Color(0xFFFF6B9D)],
  ];

  static List<Color> cardGradient(int index) {
    final pair = cardGradients[index % cardGradients.length];
    return pair;
  }
}
