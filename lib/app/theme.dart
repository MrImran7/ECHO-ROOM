import 'package:flutter/material.dart';

abstract final class EchoTheme {
  static const background = Color(0xff111a1b);
  static const surface = Color(0xff1b2829);
  static const gold = Color(0xffe1c48c);
  static const cream = Color(0xfff2ecde);
  static const muted = Color(0xffa9b7b3);
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: gold,
      onPrimary: background,
      surface: surface,
      onSurface: cream,
      secondary: Color(0xff92b5a1),
      error: Color(0xffefa59a),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w300,
        letterSpacing: 4,
        height: 1.05,
        color: cream,
      ),
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        letterSpacing: 1,
        color: cream,
      ),
      headlineMedium: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w500,
        color: cream,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: cream,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: cream),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: muted),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: cream,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: cream,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 12, letterSpacing: 3),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerColor: const Color(0xff334242),
  );
}
