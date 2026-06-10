import 'package:flutter/material.dart';
import 'dart:math';

class MacroArcDashboard extends StatelessWidget {
  final double kaloriAktual;
  final double kaloriTarget;
  final double persenKarbo;
  final double persenProtein;
  final double persenLemak;
  final double karboAktual;
  final double proteinAktual;
  final double lemakAktual;

  const MacroArcDashboard({
    super.key,
    required this.kaloriAktual,
    required this.kaloriTarget,
    required this.persenKarbo,
    required this.persenProtein,
    required this.persenLemak,
    this.karboAktual = 0,
    this.proteinAktual = 0,
    this.lemakAktual = 0,
  });

  double get _progressKeseluruhan =>
      kaloriTarget > 0 ? (kaloriAktual / kaloriTarget).clamp(0.0, 1.0) : 0.0;

  bool get _isOver => kaloriAktual > kaloriTarget;

  @override
  Widget build(BuildContext context) {
    final sisa = kaloriTarget - kaloriAktual;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 230,
          height: 230,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // CustomPaint – 3 arc makro + outer progress ring
              CustomPaint(
                size: const Size(230, 230),
                painter: MacroArcPainter(
                  persenKarbo: persenKarbo,
                  persenProtein: persenProtein,
                  persenLemak: persenLemak,
                  progressKeseluruhan: _progressKeseluruhan,
                  isOver: _isOver,
                ),
              ),
              // Teks di tengah
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${kaloriAktual.toInt()}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: _isOver ? Colors.red : const Color(0xFF2E7D32),
                    ),
                  ),
                  Text(
                    '/ ${kaloriTarget.toInt()} kkal',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isOver
                          ? Colors.red.withOpacity(0.1)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isOver
                          ? '⚠️ +${(-sisa).toInt()} kkal'
                          : '✅ -${sisa.toInt()} kkal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isOver
                            ? Colors.red.shade700
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Progress bar keseluruhan
        _buildProgressBar(),
        const SizedBox(height: 12),
        // Chip legend makro (data real dari SQLite)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MacroChip(
              color: const Color(0xFFEF9F27),
              label: 'Karbo',
              value: karboAktual,
              persen: persenKarbo,
            ),
            const SizedBox(width: 8),
            _MacroChip(
              color: const Color(0xFF0D47A1),
              label: 'Protein',
              value: proteinAktual,
              persen: persenProtein,
            ),
            const SizedBox(width: 8),
            _MacroChip(
              color: const Color(0xFFEF5350),
              label: 'Lemak',
              value: lemakAktual,
              persen: persenLemak,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress Harian',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                '${(_progressKeseluruhan * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _isOver ? Colors.red : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressKeseluruhan,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isOver ? Colors.red : const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final Color color;
  final String label;
  final double value;
  final double persen;

  const _MacroChip({
    required this.color,
    required this.label,
    required this.value,
    required this.persen,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOver = persen > 1.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOver ? Colors.red.shade300 : color.withOpacity(0.4),
          width: isOver ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(1)}g',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            '${(persen * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              color: isOver ? Colors.red.shade600 : Colors.grey.shade600,
              fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter: 3 arc makro konsentris + outer ring progress kalori
class MacroArcPainter extends CustomPainter {
  final double persenKarbo;
  final double persenProtein;
  final double persenLemak;
  final double progressKeseluruhan;
  final bool isOver;

  MacroArcPainter({
    required this.persenKarbo,
    required this.persenProtein,
    required this.persenLemak,
    required this.progressKeseluruhan,
    required this.isOver,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const startAngle = -pi / 2;

    // ── Background tracks ──────────────────────────────────────────
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    // Background outer ring (progress keseluruhan)
    canvas.drawCircle(center, 104, bgPaint..strokeWidth = 10);
    // Background 3 arc
    canvas.drawCircle(center, 84, bgPaint..strokeWidth = 12);
    canvas.drawCircle(center, 63, bgPaint..strokeWidth = 12);
    canvas.drawCircle(center, 42, bgPaint..strokeWidth = 12);

    // ── Outer Ring: Progress Kalori Keseluruhan ─────────────────────
    final progressColor = isOver ? Colors.red : const Color(0xFF2E7D32);
    final paintOverall = Paint()
      ..color = progressColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (progressKeseluruhan > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 104),
        startAngle,
        _sweepAngle(progressKeseluruhan),
        false,
        paintOverall,
      );
    }

    // ── Arc Luar: Karbohidrat ───────────────────────────────────────
    final paintKarbo = Paint()
      ..color = const Color(0xFFEF9F27)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (persenKarbo > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 84),
        startAngle,
        _sweepAngle(persenKarbo),
        false,
        paintKarbo,
      );
    }

    // ── Arc Tengah: Protein ─────────────────────────────────────────
    final paintProtein = Paint()
      ..color = const Color(0xFF0D47A1)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (persenProtein > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 63),
        startAngle,
        _sweepAngle(persenProtein),
        false,
        paintProtein,
      );
    }

    // ── Arc Dalam: Lemak ───────────────────────────────────────────
    final paintLemak = Paint()
      ..color = const Color(0xFFEF5350)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (persenLemak > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 42),
        startAngle,
        _sweepAngle(persenLemak),
        false,
        paintLemak,
      );
    }
  }

  double _sweepAngle(double percent) {
    return percent.clamp(0.0, 1.2) * 2 * pi; // max 120% agar visible jika over
  }

  @override
  bool shouldRepaint(covariant MacroArcPainter oldDelegate) {
    return oldDelegate.persenKarbo != persenKarbo ||
        oldDelegate.persenProtein != persenProtein ||
        oldDelegate.persenLemak != persenLemak ||
        oldDelegate.progressKeseluruhan != progressKeseluruhan ||
        oldDelegate.isOver != isOver;
  }
}