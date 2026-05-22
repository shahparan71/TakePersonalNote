import 'package:flutter/material.dart';

/// Semantic palette that follows [ThemeMode] (light / dark / system).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color scaffoldBg;
  final Color cardSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color fabDark;
  final Color toolbarDark;

  const AppPalette({
    required this.scaffoldBg,
    required this.cardSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.fabDark,
    required this.toolbarDark,
  });

  static const AppPalette light = AppPalette(
    scaffoldBg: Color(0xFFF5F3EE),
    cardSurface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF8E8E93),
    border: Color(0xFFE0E0E0),
    fabDark: Color(0xFF2D4F4A),
    toolbarDark: Color(0xFF1A1A1A),
  );

  static const AppPalette dark = AppPalette(
    scaffoldBg: Color(0xFF121212),
    cardSurface: Color(0xFF2C2C2E),
    textPrimary: Color(0xFF545461),
    textSecondary: Color(0xFF373750),
    border: Color(0xFF3A3A3C),
    fabDark: Color(0xFF3D6B64),
    toolbarDark: Color(0xFF0D0D0D),
  );

  /// Brand / action colors (same in both themes).
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

  Color noteCardTint(int colorValue) {
    final c = Color(colorValue);
    if (c == Colors.white || colorValue == 0xFFFFFFFF) return cardSurface;
    return c.withOpacity(0.35);
  }

  @override
  AppPalette copyWith({
    Color? scaffoldBg,
    Color? cardSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? fabDark,
    Color? toolbarDark,
  }) {
    return AppPalette(
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      cardSurface: cardSurface ?? this.cardSurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      fabDark: fabDark ?? this.fabDark,
      toolbarDark: toolbarDark ?? this.toolbarDark,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      fabDark: Color.lerp(fabDark, other.fabDark, t)!,
      toolbarDark: Color.lerp(toolbarDark, other.toolbarDark, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppPalette get appColors => Theme.of(this).extension<AppPalette>()!;
}

/// Back-compat accessors — prefer [AppColorsContext.appColors] in widgets.
class AppColors {
  static AppPalette of(BuildContext context) => context.appColors;

  static Color scaffoldBg(BuildContext c) => c.appColors.scaffoldBg;
  static Color cardWhite(BuildContext c) => c.appColors.cardSurface;
  static Color textPrimary(BuildContext c) => c.appColors.textPrimary;
  static Color textSecondary(BuildContext c) => c.appColors.textSecondary;

  static const Color fabDark = Color(0xFF2D4F4A);
  static const Color accentTeal = AppPalette.accentTeal;
  static const Color accentGreen = AppPalette.accentGreen;
  static const Color actionPin = AppPalette.actionPin;
  static const Color actionEdit = AppPalette.actionEdit;
  static const Color actionDelete = AppPalette.actionDelete;
  static const Color actionSave = AppPalette.actionSave;
  static const Color toolbarDark = Color(0xFF1A1A1A);
  static const List<Color> notePastels = AppPalette.notePastels;
}
