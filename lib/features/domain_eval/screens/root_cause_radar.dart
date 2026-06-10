import 'dart:math';
import 'package:flutter/material.dart';

class RootCauseRadar extends StatelessWidget {
  final Map<String, int> data;

  const RootCauseRadar({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Kalau belum ada data kegagalan diet sama sekali
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
        child: const Center(
          child: Text("Belum ada data kegagalan diet.\nPertahankan prestasimu! 🎉", 
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          const Text("Analisis Akar Masalah (Root Cause)", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 30),
          SizedBox(
            width: 250,
            height: 250,
            // DI SINI KITA MENGGAMBAR KANVAS MANUAL!
            child: CustomPaint(
              painter: RadarPainter(data),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final Map<String, int> data;
  RadarPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 30; // Sisakan ruang buat teks

    // Semua kategori yang mungkin terjadi
    final categories = ['SURPLUS', 'DEFISIT', 'STRES', 'NGEMIL', 'ACARA', 'LUPA', 'BOSAN', 'LAINNYA'];
    final angle = (2 * pi) / categories.length;

    // 1. GAMBAR JARING LABA-LABA (WEB)
    final webPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final r = radius * (i / 4);
      final path = Path();
      for (int j = 0; j < categories.length; j++) {
        final x = center.dx + r * cos(angle * j - pi / 2);
        final y = center.dy + r * sin(angle * j - pi / 2);
        if (j == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, webPaint);
    }

    // 2. GAMBAR GARIS POROS & TEKS LABEL
    int maxVal = data.values.isEmpty ? 1 : data.values.reduce(max);
    if (maxVal < 4) maxVal = 4; // Biar grafiknya nggak kepenuhan kalau datanya masih kecil

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int j = 0; j < categories.length; j++) {
      final x = center.dx + radius * cos(angle * j - pi / 2);
      final y = center.dy + radius * sin(angle * j - pi / 2);
      canvas.drawLine(center, Offset(x, y), webPaint); // Garis poros

      // Tulisan Label
      textPainter.text = TextSpan(
        text: categories[j], 
        style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(
        x - textPainter.width / 2 + (cos(angle * j - pi / 2) * 15), 
        y - textPainter.height / 2 + (sin(angle * j - pi / 2) * 15)
      ));
    }

    // 3. GAMBAR DATA USER (AREA BERWARNA)
    final dataPath = Path();
    final dataPaint = Paint()
      ..color = Colors.orange.withOpacity(0.4) // Area transparan
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (int j = 0; j < categories.length; j++) {
      final cat = categories[j];
      final val = data.containsKey(cat) ? data[cat]! : 0;
      final r = radius * (val / maxVal); // Jarak titik dari tengah sesuai jumlah masalah

      final x = center.dx + r * cos(angle * j - pi / 2);
      final y = center.dy + r * sin(angle * j - pi / 2);

      if (j == 0) dataPath.moveTo(x, y);
      else dataPath.lineTo(x, y);
    }
    dataPath.close();

    canvas.drawPath(dataPath, dataPaint); // Isi warnanya
    canvas.drawPath(dataPath, strokePaint); // Garis pinggirnya
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}