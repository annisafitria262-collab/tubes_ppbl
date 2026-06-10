import 'package:flutter/material.dart';

class SmartDeviationCard extends StatefulWidget {
  final double targetKalori;
  final double kaloriAktual;
  final bool isStrictMode;
  final String status;

  const SmartDeviationCard({
    super.key,
    required this.targetKalori,
    required this.kaloriAktual,
    required this.isStrictMode,
    required this.status,
  });

  @override
  State<SmartDeviationCard> createState() => _SmartDeviationCardState();
}

class _SmartDeviationCardState extends State<SmartDeviationCard> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Animasi bernapas (breathing glow) ala UI cerdas / AI
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 2.0, end: 12.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan Warna Utama berdasarkan Status
    Color mainColor = widget.status == 'TERCAPAI' ? Colors.green :
                      widget.status == 'SURPLUS' ? Colors.orange : Colors.blue;
    IconData mainIcon = widget.status == 'TERCAPAI' ? Icons.check_circle :
                        widget.status == 'SURPLUS' ? Icons.trending_up : Icons.trending_down;

    // Kalkulasi Deviasi Aktual
    double deviasi = 0;
    if (widget.targetKalori > 0) {
      deviasi = (widget.kaloriAktual - widget.targetKalori) / widget.targetKalori;
    }
    double batasToleransi = widget.isStrictMode ? 0.05 : 0.10;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          decoration: BoxDecoration(
            color: mainColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: mainColor.withOpacity(0.5), width: 1.5),
            boxShadow: widget.isStrictMode 
              ? [BoxShadow(color: mainColor.withOpacity(0.2), blurRadius: _glowAnimation.value, spreadRadius: _glowAnimation.value / 2)] 
              : [], // Glowing HANYA menyala kalau Strict Mode aktif!
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER STATUS
              Row(
                children: [
                  Icon(mainIcon, color: mainColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Kesimpulan Sistem:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            if (widget.isStrictMode)
                              const Text("🔥 STRICT MODE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 1)),
                          ],
                        ),
                        Text(
                          widget.status,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: mainColor),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 25),
              
              // CUSTOM DRAWING: QC RULER (PENGGARIS DEVIASI)
              const Text("Batas Toleransi (QC Limit)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey)),
              const SizedBox(height: 10),
              SizedBox(
                height: 25,
                width: double.infinity,
                // TweenAnimationBuilder bikin jarumnya jalan 'smooth' saat angka diketik!
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: deviasi),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedDeviasi, _) {
                    return CustomPaint(
                      painter: QCRulerPainter(
                        deviasi: animatedDeviasi,
                        batasToleransi: batasToleransi,
                        mainColor: mainColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// CUSTOM PAINTER LEVEL DEWA: MENGGAMBAR PENGGARIS & ZONA TOLERANSI
// ============================================================================
class QCRulerPainter extends CustomPainter {
  final double deviasi;
  final double batasToleransi;
  final Color mainColor;

  QCRulerPainter({required this.deviasi, required this.batasToleransi, required this.mainColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Asumsi ujung layar kiri = -20% defisit, kanan = +20% surplus
    final double maxScale = 0.20; 
    final double pixelsPerPercent = (size.width / 2) / maxScale;

    // 1. Gambar Garis Poros Dasar (Base Line)
    final basePaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), basePaint);

    // 2. Gambar ZONA HIJAU (Toleransi Area)
    // Area ini akan menciut/melebar dinamis berdasarkan Strict Mode!
    final zoneWidth = batasToleransi * pixelsPerPercent;
    final zoneRect = RRect.fromLTRBR(
      center.dx - zoneWidth, 
      center.dy - 6, 
      center.dx + zoneWidth, 
      center.dy + 6, 
      const Radius.circular(4)
    );
    final zonePaint = Paint()..color = Colors.green.withOpacity(0.2);
    canvas.drawRRect(zoneRect, zonePaint);

    // 3. Gambar Titik Target (Titik 0 di Tengah)
    final targetPaint = Paint()
      ..color = Colors.green[700]!
      ..strokeWidth = 2;
    canvas.drawLine(Offset(center.dx, center.dy - 8), Offset(center.dx, center.dy + 8), targetPaint);

    // 4. Gambar JARUM INDIKATOR AKTUAL (Bergerak sesuai deviasi)
    // Jarum ditahan maks di ujung layar biar nggak tembus (clamp)
    final double clampedDeviasi = deviasi.clamp(-maxScale, maxScale);
    final double jarumX = center.dx + (clampedDeviasi * pixelsPerPercent);
    
    final jarumPaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;
    
    // Menggambar lingkaran jarum
    canvas.drawCircle(Offset(jarumX, center.dy), 7, jarumPaint);
    
    // Lingkaran putih kecil di tengah jarum biar estetik
    final innerJarumPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(jarumX, center.dy), 3, innerJarumPaint);
  }

  @override
  bool shouldRepaint(covariant QCRulerPainter oldDelegate) {
    return oldDelegate.deviasi != deviasi || 
           oldDelegate.batasToleransi != batasToleransi ||
           oldDelegate.mainColor != mainColor;
  }
}