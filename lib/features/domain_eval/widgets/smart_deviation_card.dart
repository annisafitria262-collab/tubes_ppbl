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

class _SmartDeviationCardState extends State<SmartDeviationCard> with TickerProviderStateMixin {
  // Animasi 1: Efek Napas (Glow)
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Animasi 2: Efek Pantulan (Precision Snap-Back)
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  double? _interactiveDeviasi; // Menyimpan titik geser jari user
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    
    // 1. Inisiasi efek napas ala UI cerdas (Breathing Glow)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 2.0, end: 12.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // 2. Inisiasi pengontrol efek pantulan akurat (Snap-back)
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Durasi pantulan terkontrol
    );

    _snapController.addListener(() {
      setState(() {
        _interactiveDeviasi = _snapAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan Warna Utama berdasarkan Status
    Color mainColor = widget.status == 'TERCAPAI' ? Colors.green :
                      widget.status == 'SURPLUS' ? Colors.orange : Colors.blue;
    IconData mainIcon = widget.status == 'TERCAPAI' ? Icons.check_circle :
                        widget.status == 'SURPLUS' ? Icons.trending_up : Icons.trending_down;

    // Kalkulasi Deviasi Asli (Batu Karang yang tidak boleh berubah)
    double deviasiAsli = 0;
    double selisihKalori = (widget.kaloriAktual - widget.targetKalori).abs();
    if (widget.targetKalori > 0) {
      deviasiAsli = (widget.kaloriAktual - widget.targetKalori) / widget.targetKalori;
    }
    double batasToleransi = widget.isStrictMode ? 0.05 : 0.10;
    String deviasiPersen = (deviasiAsli * 100).abs().toStringAsFixed(1);

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
            // Glowing menyala HANYA kalau Strict Mode aktif
            boxShadow: widget.isStrictMode 
              ? [BoxShadow(color: mainColor.withOpacity(0.2), blurRadius: _glowAnimation.value, spreadRadius: _glowAnimation.value / 2)] 
              : [], 
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // HEADER STATUS & METRIK PRESISE (UPGRADED)
              // ==========================================
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: mainColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(mainIcon, color: mainColor, size: 28),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.status, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: mainColor, letterSpacing: 0.5)),
                            if (widget.isStrictMode)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                child: const Text("🔥 STRICT MODE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (widget.status != 'TERCAPAI')
                          Text("Selisih $deviasiPersen% (${selisihKalori.toInt()} kkal)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))
                        else
                          Text("Akurat! Menyimpang hanya $deviasiPersen%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 35), // Spasi untuk angka penggaris
              
              // ==========================================
              // PENGGARIS INTERAKTIF (SHADOW DIAMOND)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Metrik Deviasi (Sentuh & Geser)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  Text("Toleransi: ${(batasToleransi * 100).toInt()}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 15),
              
              LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    // Saat jari mulai menyentuh dan menggeser (Simulasi)
                    onPanUpdate: (details) {
                      _snapController.stop(); // Hentikan animasi pantulan jika sedang berjalan
                      setState(() {
                        _isDragging = true;
                        
                        // Kalkulasi posisi X jari dan kunci (clamp) agar tidak tembus layar
                        double localX = details.localPosition.dx.clamp(0, constraints.maxWidth);
                        double centerX = constraints.maxWidth / 2;
                        double maxScale = 0.30; // Skala max 30%
                        double pixelsPerPercent = centerX / maxScale;
                        
                        // Ubah piksel jari menjadi nilai deviasi (-0.3 s/d +0.3)
                        _interactiveDeviasi = ((localX - centerX) / pixelsPerPercent).clamp(-maxScale, maxScale);
                      });
                    },
                    // Saat jari dilepas (Precision Snap-Back!)
                    onPanEnd: (details) {
                      setState(() => _isDragging = false);
                      
                      // Buat animasi tarik kembali: Mulai dari posisi jari, Selesai di posisi data asli
                      _snapAnimation = Tween<double>(
                        begin: _interactiveDeviasi ?? deviasiAsli, 
                        end: deviasiAsli // Kembali memeluk data asli
                      ).animate(CurvedAnimation(
                        parent: _snapController, 
                        // Curves.decelerate = melesat cepat lalu melambat akurat (tidak mantul lebay)
                        curve: Curves.decelerate 
                      ));
                      
                      _snapController.forward(from: 0.0).then((_) {
                        setState(() { _interactiveDeviasi = null; }); // Sembunyikan bayangan saat sudah menyatu
                      });
                    },
                    child: Container(
                      height: 60, // Tinggi ditambah untuk balon tooltip melayang
                      width: double.infinity,
                      color: Colors.transparent, // Area sentuh responsif
                      child: CustomPaint(
                        painter: QCRulerPainter(
                          actualDeviasi: deviasiAsli,
                          interactiveDeviasi: _interactiveDeviasi,
                          batasToleransi: batasToleransi,
                          mainColor: mainColor,
                          targetKalori: widget.targetKalori,
                        ),
                      ),
                    ),
                  );
                }
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// CUSTOM PAINTER: MENGGAMBAR PENGGARIS & BAYANGAN WAJIK
// ============================================================================
class QCRulerPainter extends CustomPainter {
  final double actualDeviasi;
  final double? interactiveDeviasi;
  final double batasToleransi;
  final Color mainColor;
  final double targetKalori;

  QCRulerPainter({
    required this.actualDeviasi, 
    this.interactiveDeviasi, 
    required this.batasToleransi, 
    required this.mainColor,
    required this.targetKalori,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Geser titik tengah Y ke bawah agar ada ruang buat Tooltip melayang di atas
    final center = Offset(size.width / 2, size.height / 2 + 15); 
    final double maxScale = 0.30; 
    final double pixelsPerPercent = (size.width / 2) / maxScale;

    // 1. Gambar Garis Poros Dasar
    final basePaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), basePaint);

    // 2. Gambar Zona Toleransi (Hijau Transparan)
    final zoneWidth = batasToleransi * pixelsPerPercent;
    final zoneRect = RRect.fromLTRBR(
      center.dx - zoneWidth, 
      center.dy - 6, 
      center.dx + zoneWidth, 
      center.dy + 6, 
      const Radius.circular(4)
    );
    final zonePaint = Paint()..color = Colors.green.withOpacity(0.15);
    canvas.drawRRect(zoneRect, zonePaint);

    // 3. TULIS TEKS SKALA (-30%, 0%, +30%)
    _drawScaleText(canvas, center, Offset(0, center.dy), "-30%");
    _drawScaleText(canvas, center, Offset(center.dx, center.dy), "0%");
    _drawScaleText(canvas, center, Offset(size.width, center.dy), "+30%");

    // Garis Target Tengah (0%)
    final targetPaint = Paint()..color = Colors.green[700]!..strokeWidth = 2;
    canvas.drawLine(Offset(center.dx, center.dy - 8), Offset(center.dx, center.dy + 8), targetPaint);

    // ==========================================
    // 4. GAMBAR SHADOW DIAMOND & TOOLTIP (SIMULASI)
    // ==========================================
    if (interactiveDeviasi != null) {
      // Hitung posisi X bayangan & kunci (clamp) biar ga tembus batas HP
      final double clampedInteractive = interactiveDeviasi!.clamp(-maxScale, maxScale);
      final double ghostX = center.dx + (clampedInteractive * pixelsPerPercent);
      
      // Menggambar Bayangan Wajik (Hologram Transparan)
      final shadowJarumPaint = Paint()
        ..color = Colors.blueGrey.withOpacity(0.4) // Warna bayangan hologram
        ..style = PaintingStyle.fill;
      _drawDiamondPath(canvas, ghostX, center.dy, shadowJarumPaint);

      // Kalkulasi Angka Simulasi (What-If)
      double simKalori = targetKalori + (targetKalori * clampedInteractive);
      String sign = clampedInteractive > 0 ? "+" : "";
      String simText = "$sign${(clampedInteractive * 100).toInt()}% (${simKalori.toInt()})";

      // Menggambar Balon Teks (Tooltip) Melayang
      final textPainter = TextPainter(
        text: TextSpan(text: simText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Posisi tooltip ditahan jangan sampai keluar batas layar kiri/kanan HP
      double tooltipX = ghostX.clamp(textPainter.width / 2 + 6, size.width - textPainter.width / 2 - 6);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(tooltipX, center.dy - 35), width: textPainter.width + 12, height: textPainter.height + 8),
        const Radius.circular(8),
      );
      // Kotak Tooltip
      canvas.drawRRect(rrect, Paint()..color = Colors.blueGrey[800]!); 
      // Segitiga Tooltip
      _drawTooltipArrow(canvas, Offset(ghostX, center.dy - 35 + textPainter.height / 2 + 4));
      // Teks Tooltip
      textPainter.paint(canvas, Offset(tooltipX - textPainter.width / 2, center.dy - 35 - textPainter.height / 2));
    }

    // ==========================================
    // 5. GAMBAR JARUM AKTUAL (DATA ASLI & SUCI)
    // ==========================================
    final double clampedActual = actualDeviasi.clamp(-maxScale, maxScale);
    final double jarumX = center.dx + (clampedActual * pixelsPerPercent);
    
    final jarumPaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;
    _drawDiamondPath(canvas, jarumX, center.dy, jarumPaint);
  }

  // Fungsi Pembantu Bikin Bentuk Wajik/Berlian
  void _drawDiamondPath(Canvas canvas, double x, double y, Paint paint) {
    final path = Path()
      ..moveTo(x, y - 10) // Puncak atas
      ..lineTo(x + 6, y)  // Sudut Kanan
      ..lineTo(x, y + 10) // Puncak bawah
      ..lineTo(x - 6, y)  // Sudut Kiri
      ..close();
    canvas.drawPath(path, paint);
  }

  // Fungsi Pembantu Bikin Segitiga Kecil di Bawah Tooltip
  void _drawTooltipArrow(Canvas canvas, Offset position) {
    final path = Path()
      ..moveTo(position.dx - 4, position.dy - 4)
      ..lineTo(position.dx + 4, position.dy - 4)
      ..lineTo(position.dx, position.dy) // Titik panah
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.blueGrey[800]!);
  }

  // Fungsi Pembantu Teks Skala di Bawah Poros
  void _drawScaleText(Canvas canvas, Offset center, Offset position, String text) {
    final tickPaint = Paint()..color = Colors.grey[400]!..strokeWidth = 1.5;
    canvas.drawLine(Offset(position.dx, center.dy - 4), Offset(position.dx, center.dy + 4), tickPaint);

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final textX = position.dx - (textPainter.width / 2);
    final textY = center.dy + 12;
    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(covariant QCRulerPainter oldDelegate) {
    return oldDelegate.actualDeviasi != actualDeviasi || 
           oldDelegate.interactiveDeviasi != interactiveDeviasi ||
           oldDelegate.batasToleransi != batasToleransi ||
           oldDelegate.mainColor != mainColor;
  }
}