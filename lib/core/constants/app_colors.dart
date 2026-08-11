import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1B2A4A);
  static const Color primaryDark = Color(0xFF0F1B33);
  static const Color primaryLight = Color(0xFF2D4270);
  
  static const Color accent = Color(0xFFD4AF37);
  static const Color accentDark = Color(0xFFB8960F);
  static const Color accentLight = Color(0xFFF4D03F);
  
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textHint = Color(0xFFADB5BD);
  
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFDC3545);
  static const Color info = Color(0xFF17A2B8);
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1B2A4A), Color(0xFF2D4270)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFF4D03F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
