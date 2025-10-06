import 'package:flutter/material.dart';

class AppTheme {
  static const _bg = Color(0xFF0E0E12);
  static const _card = Color(0xFF17171D);
  static const _accent = Color(0xFFB69CFF);
  static const _ok = Color(0xFF2ECC71);
  static const _err = Color(0xFFFF6B6B);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: _bg,
      colorScheme: base.colorScheme.copyWith(
        primary: _accent,
        secondary: _accent,
        surface: _card,
      ),
      cardTheme: const CardThemeData(
        color: _card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _card,
      ),
    );
  }

  static const edge = EdgeInsets.all(16);
  static const gap = SizedBox(height: 12);
  static const gapW = SizedBox(width: 12);

  static Color ok([double o = 1]) => _ok.withOpacity(o);
  static Color err([double o = 1]) => _err.withOpacity(o);
  static Color accent([double o = 1]) => _accent.withOpacity(o);
}
