import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme() {
  const navy = Color(0xFF1E3A5F);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: navy,
    brightness: Brightness.light,
    primary: navy,
  );
  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: GoogleFonts.sarabunTextTheme(base.textTheme),
  );
}
