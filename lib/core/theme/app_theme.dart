import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de la marca: verde (logo), blanco y negro.
  static const green = Color(0xFF16A34A);
  static const greenDark = Color(0xFF15803D);
  static const black = Color(0xFF111111);
  static const white = Color(0xFFFFFFFF);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light);
    final scheme = base.copyWith(
      primary: green,
      onPrimary: white,
      secondary: greenDark,
      onSecondary: white,
      surface: white,
      onSurface: black,
      primaryContainer: const Color(0xFFDCFCE7),
      onPrimaryContainer: const Color(0xFF052E16),
    );
    return _build(scheme);
  }

  static ThemeData dark() => light();

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, elevation: 0, centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: greenDark)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: black)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? green : null),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: const Color(0xFFDCFCE7),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ),
      tabBarTheme: const TabBarThemeData(labelColor: greenDark, indicatorColor: green, unselectedLabelColor: Colors.grey),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: green),
    );
  }
}
