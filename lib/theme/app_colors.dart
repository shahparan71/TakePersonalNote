import 'package:flutter/material.dart';

/// Design tokens inspired by the shared note-app mockups.
class AppColors {
  static const Color scaffoldBg = Color(0xFFF5F3EE);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);

  static const Color fabDark = Color(0xFF2D4F4A);
  static const Color toolbarDark = Color(0xFF1A1A1A);

  static const Color accentGreen = Color(0xFF7CB87C);
  static const Color accentTeal = Color(0xFF54BF8F);

  static const Color actionPin = Color(0xFFC06C3B);
  static const Color actionEdit = Color(0xFF2E4482);
  static const Color actionSearch = Color(0xFF4CAF50);
  static const Color actionDelete = Color(0xFFE53935);
  static const Color actionSave = Color(0xFF4CAF50);

  static const List<Color> notePastels = [
    Color(0xFFFFFFFF),
    Color(0xFFFFF9C4),
    Color(0xFFC8E6C9),
    Color(0xFFBBDEFB),
    Color(0xFFE1BEE7),
    Color(0xFFFFE0B2),
  ];

  static Color noteCardTint(int colorValue) {
    final c = Color(colorValue);
    if (c == Colors.white || colorValue == 0xFFFFFFFF) return cardWhite;
    return c.withOpacity(0.35);
  }
}
