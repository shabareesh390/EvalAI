import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const Color primary      = Color(0xFF2563EB); // Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark  = Color(0xFF1D4ED8);
  static const Color accent       = Color(0xFF60A5FA);
  
  // Background & Surface
  static const Color background   = Color(0xFFF8FAFC);
  static const Color surface      = Color(0xFFFFFFFF); // Pure White Cards
  static const Color surfaceAlt   = Color(0xFFF1F5F9); // Secondary Surface

  // Text
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled  = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF22C55E); // Success
  static const Color warning = Color(0xFFF59E0B); // Warning
  static const Color error   = Color(0xFFEF4444); // Danger
  static const Color info    = Color(0xFF0EA5E9);

  // Status Light
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color errorLight   = Color(0xFFFEE2E2);
  static const Color infoLight    = Color(0xFFE0F2FE);

  // Borders & Dividers
  static const Color border   = Color(0xFFE2E8F0);
  static const Color divider  = Color(0xFFF1F5F9);
  
  // Shadows
  static const Color shadow   = Color(0x0F000000);

  // Confidence (for AI evaluation)
  static const Color confidenceHigh   = success;
  static const Color confidenceMedium = warning;
  static const Color confidenceLow    = error;
}