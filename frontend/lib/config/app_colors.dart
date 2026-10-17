import 'package:flutter/material.dart';

/// Hungry Howie's POS Design System - Light Theme (Toast POS / Square POS Style)
class AppColors {
  AppColors._();

  // Brand Colors
  static const Color primaryRed = Color(0xFFED1C24);
  static const Color deepRed = Color(0xFFB5121B);
  static const Color brightRed = Color(0xFFF21D2B);
  static const Color brandYellow = Color(0xFFFFD400);
  static const Color gold = Color(0xFFD4AF37);

  // Light Theme Surfaces (White UI)
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFFAFAFA);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color elevatedSurface = Color(0xFFFFFFFF);

  // Typography (High Readability)
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFD32F2F);
  static const Color vegGreen = Color(0xFF4CAF50);
  static const Color spicyOrange = Color(0xFFEF6C00);

  // Table Status Colors (Floor Layout)
  static const Color tableAvailable = Color(0xFF2E7D32); // Green
  static const Color tableOccupied = Color(0xFFD32F2F);  // Red
  static const Color tableReserved = Color(0xFFFFB300);  // Yellow
  static const Color tableCleaning = Color(0xFF9E9E9E);  // Gray

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryRed, deepRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [primaryRed, brightRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
