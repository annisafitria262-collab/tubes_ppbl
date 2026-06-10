import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      // Warna dasar aplikasi
      scaffoldBackgroundColor: const Color(0xFFFAFAFA), // Off-White biar bersih
      
      // Skema warna utama sesuai konsep FitPlate
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2E7D32),   // Fresh Green (Warna Utama)
        secondary: Color(0xFFEF9F27), // Energic Orange (Warna Sekunder)
        error: Color(0xFF880E4F),     // Deep Pink (Khusus Evaluasi/Jebol)
        surface: Color(0xFFFFFFFF),   // Putih bersih untuk Card
      ),

      // Bikin Appbar (Header atas) otomatis warna hijau semua
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white, // Teks di header jadi putih
        elevation: 0,
      ),

      // Bikin semua tombol (ElevatedButton) seragam
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Ujung tombol agak melengkung
          ),
        ),
      ),
    );
  }
}